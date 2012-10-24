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

@interface CDStack : NSObject

+ (NSURL *)managedObjectModelURL;
+ (NSManagedObjectModel *)managedObjectModel;
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
+ (NSManagedObjectContext *)managedObjectContext;

+ (void)registerStoreClass:(Class)klass;
+ (void)saveContext;

+ (void)fetch:(NSFetchRequest *)request withResults:(CDResults)block;
//+ (void)fetches:(NSArray *)requests withCombinedResults:(CDCombinedResults)block;
@end
