//
//  CDStack.h
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDPersistentStoreProtocol.h"

typedef void (^CDResults) (NSArray *results);
typedef void(^CDCombinedResults) (NSDictionary *results);

extern NSString * const kCDStackManagedObjectContextKey;

@interface CDStack : NSObject

+ (NSURL *)managedObjectModelURL;
+ (NSManagedObjectModel *)managedObjectModel;

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectContext *)managedObjectContext;
- (void)saveContext;
- (void)cleanup;

- (void)fetch:(NSFetchRequest *)request withResults:(CDResults)block;
//+ (void)fetches:(NSArray *)requests withCombinedResults:(CDCombinedResults)block;

- (id)initWithStoreClass:(Class)klass;
@end
