//
//  CDStack.h
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDPersistentStoreProtocol.h"

// Key used to access the managedObjectContext in NSThread's dictionary
extern NSString * const kCDStackManagedObjectContextKey;

// Results blocks
typedef void (^CDResults) (NSArray *results);
typedef void (^CDCombinedResults) (NSDictionary *results);

@interface CDStack : NSObject

+ (NSURL *)managedObjectModelURL;
+ (NSManagedObjectModel *)managedObjectModel;

@property (readwrite, unsafe_unretained, nonatomic) CDStack *parentStack;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (id)initWithStoreClass:(Class)klass;
- (void)saveContext;
- (void)mergeChangesFromChildStack:(NSNotification *)notification;
- (void)cleanup;

- (void)fetch:(NSFetchRequest *)request withResults:(CDResults)block;
- (void)fetches:(NSArray *)requests withCombinedResults:(CDCombinedResults)block;

@end
