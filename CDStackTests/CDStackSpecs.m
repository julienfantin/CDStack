//
//  CDStackTests.m
//  CDStackTests
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "CDStack.h"
#import "CDCacheStore.h"
#import "CDAsyncStore.h"

SPEC_BEGIN(CDStackSpecs)

describe(@"CDStack initialization", ^{
    
    __block CDStack *stack;
    
    beforeEach(^{
        stack = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
    });
        
    it(@"Should stash its persistentStoreCoordinator into the mainThread's dictionary when accessed", ^{
        id psc = stack.persistentStoreCoordinator;
        
        NSDictionary *dict = [[NSThread mainThread] threadDictionary];
        __block NSMutableArray *values = [NSMutableArray array];
        [[dict allValues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSArray class]]) {
                values = [[values arrayByAddingObjectsFromArray:(NSArray *)obj] mutableCopy];
            }
            else {
                [values addObject:obj];
            }
        }];
        
        [[values should] contain:psc];
    });

    context(@"managedObjectContext", ^{

        __block NSManagedObjectContext *mainMOC;
        
        beforeEach(^{
            mainMOC = stack.managedObjectContext;
        });
        
        afterEach(^{
            mainMOC = nil;
        });
        
        specify(^{
            [mainMOC shouldNotBeNil];
        });
        
        it(@"Should be registered with the store coordinator", ^{
            [[mainMOC persistentStoreCoordinator] shouldNotBeNil];
            [[[mainMOC persistentStoreCoordinator] should] equal:stack.persistentStoreCoordinator];
        });
        
        context(@"The managedObjectContext accessor should return an instance unique to each thread", ^{
            
            it(@"Should work Main Thread", ^{
                [stack.managedObjectContext shouldNotBeNil];
                [[stack.managedObjectContext should] beIdenticalTo:stack.managedObjectContext];
            });
            
            it(@"Should work on GCD global queue", ^{
                __block id main = stack.managedObjectContext;
                __block BOOL pass = NO;
                dispatch_queue_t confined_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(confined_queue, ^{
                    BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                    BOOL isConfined = main != stack.managedObjectContext;
                    pass = isUnique && isConfined;
                });
                
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });
            
            it(@"Should work on GCD private queue", ^{
                __block id main = stack.managedObjectContext;
                __block BOOL pass = NO;
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.CDStackSpecs", 0);
                dispatch_async(serial_queue, ^{
                    BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                    BOOL isConfined = main != stack.managedObjectContext;
                    pass = isUnique && isConfined;
                });
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });
        });
    });
    
    context(@"Object creation", ^{
        
        __block NSFetchRequest *fetchRequest;
        __block id (^insertObjectBlock)(NSManagedObjectContext *context);
        
        beforeAll(^{
            fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Event"];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES]];
            insertObjectBlock = (id) ^ (NSManagedObjectContext *context){
                NSEntityDescription *e = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:context];
                NSManagedObject *o = [[NSManagedObject alloc] initWithEntity:e insertIntoManagedObjectContext:context];
                [o setValue:[NSDate date] forKey:@"timeStamp"];
                return o;
            };
        });
        
        context(@"Same store", ^{
            
            it(@"Should insert entities in the current context", ^{
                NSManagedObject *o = insertObjectBlock(stack.managedObjectContext);
                [o shouldNotBeNil];
            });
            
            it(@"Should fetch entities after they've been inserted in the current context", ^{
                NSManagedObject *o = insertObjectBlock(stack.managedObjectContext);
                
                [stack saveContext];
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                [[results shouldNot] beEmpty];
                [[[results lastObject] should] beIdenticalTo:o];
            });

            it(@"Should propagate object creation in a background context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.bubblin", 0);
                dispatch_sync(serial_queue, ^{
                    o = insertObjectBlock(stack.managedObjectContext);
                    [stack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                [[[[results lastObject] objectID] should] beIdenticalTo:o.objectID];
            });
            
            it(@"Should propagate object creation in between background contexts", ^{
                __block NSManagedObject *o = nil;
                __block NSManagedObject *p = nil;
                
                dispatch_queue_t serial_queue1 = dispatch_queue_create("com.julienfantin.bubblin2", 0);
                dispatch_sync(serial_queue1, ^{
                    o = insertObjectBlock(stack.managedObjectContext);
                    [stack saveContext];
                });
                
                dispatch_queue_t serial_queue2 = dispatch_queue_create("com.julienfantin.bubblin3", 0);
                dispatch_sync(serial_queue2, ^{
                    p = insertObjectBlock(stack.managedObjectContext);
                    [stack saveContext];
                });
                
                __block BOOL pass = NO;
                dispatch_sync(serial_queue1, ^{
                    NSError *error = nil;
                    NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                    pass = [[(NSManagedObject *)results.lastObject objectID] isEqual:p.objectID];
                });
                
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });            

            it(@"Should propagate object creation in a global context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = insertObjectBlock(stack.managedObjectContext);
                    [stack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                [[[[results lastObject] objectID] should] beIdenticalTo:o.objectID];
            });
        });
        
        context(@"Different stores", ^{

            it(@"Should allow nesting", ^{
                __block NSManagedObject *o = nil;

                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
//                    CDStack *child = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
//                    child.managedObjectContext.parentContext = stack.managedObjectContext;
//                    o = insertObjectBlock(child.managedObjectContext);
//                    [child saveContext];
                });

                
            });

        });
    });
});

SPEC_END