//
//  CDAsyncStore.m
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDAsyncStore.h"

@implementation CDAsyncStore

#pragma mark - NSIncrementalStore mandatory overrides

+ (void)initialize
{
    Class storeClass = [self class];
    NSString *type = [[self class] type];
    [NSPersistentStoreCoordinator registerStoreClass:storeClass forStoreType:type];
}

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error
{
    NSString *UUID = [[NSProcessInfo processInfo] globallyUniqueString];
    self.metadata = @{NSStoreTypeKey: [[self class] type], NSStoreUUIDKey: UUID};
    return YES;
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
    // TODO
    return nil;
}

#pragma mark - <CDPersistentStore>

+ (NSString *)type
{
    return NSStringFromClass([self class]);
}

@end
