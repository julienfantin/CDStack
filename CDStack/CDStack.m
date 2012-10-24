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
@property (readonly, strong, nonatomic) NSString *stackID;
- (void)registerStoreClass:(Class)klass;
- (NSManagedObjectContext *)managedObjectContextInThread:(NSThread *)thread;
- (void)saveContext:(NSManagedObjectContext *)context;
@end

@implementation CDStack

@synthesize stackID = _stackID;

#pragma mark - Path helpers

+ (NSURL *)managedObjectModelURL
{
    NSString *storeName = @"CDStack";
    return [[NSBundle mainBundle] URLForResource:storeName withExtension:@"momd"];
}

#pragma - CoreData accessors

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *url = [self managedObjectModelURL];
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    // Unit-test target hack...
    if (managedObjectModel == nil) {
        managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    }

    NSParameterAssert(managedObjectModel);
    
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSThread *mainThread = [NSThread mainThread];
    NSMutableDictionary *dict = mainThread.threadDictionary;
    
    id key = [self.stackID stringByAppendingString:kCDStackPersistentStoreCoordinatorKey];
    
    NSPersistentStoreCoordinator *psc = [dict objectForKey:key];
    if (psc == nil) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        [dict setObject:psc forKey:key];
    }
    
    return psc;
}

- (NSManagedObjectContext *)managedObjectContextInThread:(NSThread *)thread
{
    id key = [self.stackID stringByAppendingString:kCDStackManagedObjectContextKey];
    NSMutableDictionary *dict = thread.threadDictionary;
    NSManagedObjectContext *managedObjectContext = [dict objectForKey:key];
    
    if (managedObjectContext == nil) {
        
        BOOL isMainThread = [thread isMainThread];
        
        NSManagedObjectContextConcurrencyType concurrency = isMainThread ? NSMainQueueConcurrencyType : NSPrivateQueueConcurrencyType;
        managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrency];

//        if (isMainThread == NO) {
//            NSManagedObjectContext *mainContext = [self managedObjectContextInThread:[NSThread mainThread]];
//            managedObjectContext.parentContext = mainContext;
//        }

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
    return [self managedObjectContextInThread:[NSThread currentThread]];
}


#pragma mark - initialization & configuration

- (NSString *)stackID
{
    if (_stackID != nil) {
        return _stackID;
    }
    
    _stackID = [[NSProcessInfo processInfo] globallyUniqueString];
    return _stackID;
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

- (void)saveContext:(NSManagedObjectContext *)managedObjectContext
{
    if (managedObjectContext != nil) {
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

#pragma mark - Fetches

- (void)fetch:(NSFetchRequest *)request withResults:(CDResults)block
{
    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(global_queue, ^{
        NSError *error = nil;
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
        NSArray *objectIDs = [self objectIDsForObjects:results];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *objects = [self objectsForObjectIDs:objectIDs];
            dispatch_async(dispatch_get_main_queue(), ^{
                block(objects);
            });
        });
    });
}

//+ (void)fetches:(NSArray *)requests withCombinedResults:(CDCombinedResults)block
//{
//    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    dispatch_group_t group = dispatch_group_create();
//
//    __block NSMutableDictionary *combinedResultsIDs = [NSMutableDictionary dictionary];
//    
//    for (NSFetchRequest *request in requests) {
//        dispatch_group_async(group, global_queue, ^{
//            NSError *error = nil;
//            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:request error:&error];
//            NSArray *objectIDs = [self objectIDsForObjects:fetchResults];
//            [combinedResultsIDs setObject:objectIDs forKey:request];
//        });
//    }
//
//    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
//        NSMutableDictionary *combinedResults = [NSMutableDictionary dictionaryWithCapacity:[combinedResultsIDs count]];
//        [combinedResultsIDs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//            NSArray *objects = [self objectsForObjectIDs:obj];
//            [combinedResults setObject:objects forKey:key];
//        }];
//        
//        block(combinedResults);
//    });
//}

- (id)initWithStoreClass:(Class)klass
{
    self = [super init];
    if (self) {
        [self registerStoreClass:klass];
    }
    return self;
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
}

@end
