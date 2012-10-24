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

describe(@"CDStack", ^{
        
    specify(^{
        [[CDStack persistentStoreCoordinator] shouldNotBeNil];
        [[CDStack managedObjectModel] shouldNotBeNil];
    });
    
    context(@"managedObjectContext", ^{

        __block NSManagedObjectContext *mainMOC;
        
        beforeEach(^{
            mainMOC = [CDStack managedObjectContext];
        });
        
        afterEach(^{
            mainMOC = nil;
        });
        
        specify(^{
            [mainMOC shouldNotBeNil];
        });
        
        it(@"Should be registered with the store coordinator", ^{
            [[mainMOC persistentStoreCoordinator] shouldNotBeNil];
            [[[mainMOC persistentStoreCoordinator] should] equal:[CDStack persistentStoreCoordinator]];
        });
        
        context(@"The managedObjectContext accessor should return an instance unique to each thread", ^{
            
            it(@"Should work Main Thread", ^{
                [[CDStack managedObjectContext] shouldNotBeNil];
                [[[CDStack managedObjectContext] should] beIdenticalTo:[CDStack managedObjectContext]];
            });
            
            it(@"Should work on GCD global queue", ^{
                __block id main = [CDStack managedObjectContext];
                __block BOOL pass = NO;
                dispatch_queue_t confined_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(confined_queue, ^{
                    BOOL isUnique = [CDStack managedObjectContext] == [CDStack managedObjectContext];
                    BOOL isConfined = main != [CDStack managedObjectContext];
                    pass = isUnique && isConfined;
                });
                
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });
            
            it(@"Should work on GCD private queue", ^{
                __block id main = [CDStack managedObjectContext];
                __block BOOL pass = NO;
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.CDStackSpecs", 0);
                dispatch_async(serial_queue, ^{
                    BOOL isUnique = [CDStack managedObjectContext] == [CDStack managedObjectContext];
                    BOOL isConfined = main != [CDStack managedObjectContext];
                    pass = isUnique && isConfined;
                });
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });
        });
    });
    
    context(@"Object creation", ^{
        
        __block NSFetchRequest *fetchRequest;
        __block id (^insertObjectBlock)(void);
        
        beforeAll(^{
            fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Event"];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES]];
            
            insertObjectBlock = (id) ^{
                NSEntityDescription *e = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:[CDStack managedObjectContext]];
                NSManagedObject *o = [[NSManagedObject alloc] initWithEntity:e insertIntoManagedObjectContext:[CDStack managedObjectContext]];
                [o setValue:[NSDate date] forKey:@"timeStamp"];
                return o;
            };
        });
        
        context(@"Main context", ^{
            
            it(@"Should insert entities in the current context", ^{
                NSManagedObject *o = insertObjectBlock();
                [o shouldNotBeNil];
            });
            
            it(@"Should fetch entities after they've been inserted in the current context", ^{
                NSManagedObject *o = insertObjectBlock();
                
                [CDStack saveContext];
                
                NSError *error = nil;
                NSArray *results = [[CDStack managedObjectContext] executeFetchRequest:fetchRequest error:&error];
                
                [[results shouldNot] beEmpty];
                [[[results lastObject] should] beIdenticalTo:o];
            });
        });
        
        context(@"Private queues", ^{
            
            it(@"Should propagate object creation in a background context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.bubblin", 0);
                dispatch_sync(serial_queue, ^{
                    o = insertObjectBlock();
                    [CDStack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [[CDStack managedObjectContext] executeFetchRequest:fetchRequest error:&error];
                [[[[results lastObject] objectID] should] beIdenticalTo:o.objectID];
            });
            
            it(@"Should propagate object creation in between background contexts", ^{
                __block NSManagedObject *o = nil;
                __block NSManagedObject *p = nil;
                
                dispatch_queue_t serial_queue1 = dispatch_queue_create("com.julienfantin.bubblin2", 0);
                dispatch_sync(serial_queue1, ^{
                    o = insertObjectBlock();
                    [CDStack saveContext];
                });
                
                dispatch_queue_t serial_queue2 = dispatch_queue_create("com.julienfantin.bubblin3", 0);
                dispatch_sync(serial_queue2, ^{
                    p = insertObjectBlock();
                    [CDStack saveContext];
                });
                
                __block BOOL pass = NO;
                dispatch_sync(serial_queue1, ^{
                    NSError *error = nil;
                    NSArray *results = [[CDStack managedObjectContext] executeFetchRequest:fetchRequest error:&error];
                    pass = [[(NSManagedObject *)results.lastObject objectID] isEqual:p.objectID];
                });
                
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });            
        });
        
        context(@"GCD Global queues", ^{
            it(@"Should propagate object creation in a global context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = insertObjectBlock();
                    [CDStack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [[CDStack managedObjectContext] executeFetchRequest:fetchRequest error:&error];
                [[[[results lastObject] objectID] should] beIdenticalTo:o.objectID];
            });
        });
    });
});

SPEC_END