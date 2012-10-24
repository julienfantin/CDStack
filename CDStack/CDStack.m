//
//  CDStack.m
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack.h"
#import "CDStack+Helpers.h"
#import "CDCacheStore.h"

NSString * const kCDStackManagedObjectContextKey = @"kCDStackManagedObjectContextKey";
NSString * const kCDStackPersistentStoreCoordinatorKey = @"kCDStackPersistentStoreCoordinatorKey";

@interface CDStack ()
- (void)registerStoreClass:(Class)klass;
- (NSManagedObjectContext *)managedObjectContextForThread:(NSThread *)thread;
- (void)saveContext:(NSManagedObjectContext *)context;
@property (readonly, strong, nonatomic) NSString *stackID;
@end

@implementation CDStack

@synthesize parentStack = _parentStack;
@synthesize stackID = _stackID;

#pragma mark - CoreData accessors

+ (NSURL *)managedObjectModelURL
{
    NSString *storeName = @"CDStack";
    return [[NSBundle mainBundle] URLForResource:storeName withExtension:@"momd"];
}

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *url = [self managedObjectModelURL];
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    if (managedObjectModel == nil) {
        // Unit-test target hack...
        managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    }

    NSParameterAssert(managedObjectModel);
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSMutableDictionary *dict = [[NSThread mainThread] threadDictionary];
    
    id key = [self.stackID stringByAppendingString:kCDStackPersistentStoreCoordinatorKey];
    NSPersistentStoreCoordinator *psc = [dict objectForKey:key];
    
    if (psc == nil) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        [dict setObject:psc forKey:key];
    }
    
    return psc;
}

- (NSManagedObjectContext *)managedObjectContextForThread:(NSThread *)thread
{
    NSMutableDictionary *dict = thread.threadDictionary;

    id key = [self.stackID stringByAppendingString:kCDStackManagedObjectContextKey];
    NSManagedObjectContext *managedObjectContext = [dict objectForKey:key];
    
    if (managedObjectContext == nil) {
        
        NSManagedObjectContextConcurrencyType concurrency = [thread isMainThread] ? NSMainQueueConcurrencyType : NSPrivateQueueConcurrencyType;
        managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrency];
        
        if (self.parentStack != nil) {
            managedObjectContext.parentContext = self.parentStack.managedObjectContext;
        }
        else {
            if ([thread isMainThread] == NO) {
                NSManagedObjectContext *mainContext = [self managedObjectContextForThread:[NSThread mainThread]];
                managedObjectContext.parentContext = mainContext;
                managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
            }            
        }

        if (managedObjectContext.persistentStoreCoordinator == nil) {
            managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
        }

        [dict setObject:managedObjectContext forKey:key];
    }
    
    NSParameterAssert([[thread threadDictionary] objectForKey:key]);
    return managedObjectContext;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return [self managedObjectContextForThread:[NSThread currentThread]];
}

- (void)saveContext:(NSManagedObjectContext *)managedObjectContext
{
    if (managedObjectContext != nil) {
        
        [managedObjectContext processPendingChanges];
        
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)saveContext
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    
    [self saveContext:managedObjectContext];
    
    if (managedObjectContext.parentContext != nil) {
        [managedObjectContext.parentContext performBlock:^{
            [self saveContext:managedObjectContext.parentContext];
        }];
    }
}


#pragma mark - initialization & configuration

- (id)initWithStoreClass:(Class)klass
{
    self = [super init];
    if (self) {
        [self registerStoreClass:klass];
    }
    return self;
}

- (void)registerStoreClass:(Class)klass
{
    NSParameterAssert([klass conformsToProtocol:@protocol(CDPersistentStore)]);
    
    NSString *type = [klass type];
    NSURL *url = [klass respondsToSelector:@selector(url)] ? [klass url] : nil;
    NSString *configuration = [klass respondsToSelector:@selector(configuration)] ? [klass configuration] : nil;
    NSDictionary *options = [klass respondsToSelector:@selector(options)] ? [klass options] : nil;
    NSError *error = nil;
    NSPersistentStore *store = [self.persistentStoreCoordinator addPersistentStoreWithType:type configuration:configuration URL:url options:options error:&error];
    
    if (store == nil) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    NSArray *keys =@[
    [self.stackID stringByAppendingString:kCDStackPersistentStoreCoordinatorKey],
    [self.stackID stringByAppendingString:kCDStackManagedObjectContextKey]];
    
    NSMutableDictionary *mainDict = [[NSThread mainThread] threadDictionary];
    [mainDict removeObjectsForKeys:keys];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self.parentStack
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:self.managedObjectContext];
}

// Used to build the keys necessary to storing and retrieving moc and psc in an NSThread's dictionary
- (NSString *)stackID
{
    if (_stackID != nil) {
        return _stackID;
    }
    
    _stackID = [[NSProcessInfo processInfo] globallyUniqueString];
    return _stackID;
}

// A child stack will notify its parent stack of changes occuring in the child's context
// The parent stack will automatically merge the changes on the mainThread
- (void)setParentStack:(CDStack *)parentStack
{
    if (_parentStack != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:_parentStack
                                                        name:NSManagedObjectContextObjectsDidChangeNotification
                                                      object:self.managedObjectContext];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:parentStack
                                             selector:@selector(mergeChangesFromChildStack:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.managedObjectContext];
    _parentStack = parentStack;
}

- (void)mergeChangesFromChildStack:(NSNotification *)notification
{
    [self.managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromChildStack:)
                                                withObject:notification
                                             waitUntilDone:NO];
}

#pragma mark - Fetch methods

- (void)fetch:(NSFetchRequest *)request withResults:(CDResults)block
{
    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(global_queue, ^{
        NSError *error = nil;
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
        NSArray *objectIDs = [results objectIDsFromObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *objects = [objectIDs objectsFromObjectIDsWithContext:self.managedObjectContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                block(objects);
            });
        });
    });
}

- (void)fetches:(NSArray *)requests withCombinedResults:(CDCombinedResults)block
{
    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();

    __block NSMutableDictionary *combinedObjectIDs = [NSMutableDictionary dictionary];
    
    for (NSFetchRequest *request in requests) {
        dispatch_group_async(group, global_queue, ^{
            NSError *error = nil;
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:request error:&error];
            [combinedObjectIDs setObject:[fetchResults objectIDsFromObjects] forKey:request];
        });
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableDictionary *combinedResults = [NSMutableDictionary dictionary];
        
        [combinedObjectIDs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSArray *objects = [obj objectsFromObjectIDsWithContext:self.managedObjectContext];
            [combinedResults setObject:objects forKey:key];
        }];
        
        block(combinedResults);
    });
}

@end
