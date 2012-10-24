//
//  CDStackTests.m
//  CDStackTests
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "CDStack.h"
#import "CDStack+SpecsHelpers.h"
#import "CDCacheStore.h"
#import "CDAsyncStore.h"

SPEC_BEGIN(CDStackSpecs)

describe(@"CDStack", ^{
    
    __block CDStack *stack;
    
    beforeEach(^{
        stack = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
    });
    
    afterEach(^{
        [stack wipeStores];
        stack = nil;
    });
    
    context(@"CoreData stack accessors", ^{
        
        it(@"Should stash its persistentStoreCoordinator into the mainThread's dictionary when accessed", ^{
            id psc = stack.persistentStoreCoordinator;
            [[[[[NSThread mainThread] threadDictionary] allValues] should] contain:psc];
        });

        context(@"managedObjectContext", ^{
            __block NSManagedObjectContext *mainContext;
            
            beforeEach(^{
                mainContext = stack.managedObjectContext;
            });

            specify(^{
                [mainContext shouldNotBeNil];
            });
            
            it(@"Should be registered with the store coordinator", ^{
                [[[mainContext persistentStoreCoordinator] should] equal:stack.persistentStoreCoordinator];
            });
            
            context(@"Instances are per thread", ^{
                
                it(@"Should work on Main Thread", ^{
                    [stack.managedObjectContext shouldNotBeNil];
                    [[stack.managedObjectContext should] beIdenticalTo:stack.managedObjectContext];
                });
                
                it(@"Should work in GCD global queues", ^{
                    __block BOOL pass = NO;
                    dispatch_queue_t confined_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                    dispatch_async(confined_queue, ^{
                        BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                        BOOL isConfined = mainContext != stack.managedObjectContext;
                        pass = isUnique && isConfined;
                    });
                    
                    [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
                });
                
                it(@"Should work in GCD private queues", ^{
                    __block BOOL pass = NO;
                    dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.CDStackSpecs", 0);
                    dispatch_async(serial_queue, ^{
                        BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                        BOOL isConfined = mainContext != stack.managedObjectContext;
                        pass = isUnique && isConfined;
                    });
                    [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
                });
            });
        });
    });
    
    context(@"Object creation", ^{
        
        __block NSFetchRequest *fetchRequest;
        
        beforeAll(^{
            fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Event"];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES]];
        });
        
        context(@"Single store", ^{
            
            it(@"Should fetch entities after they've been inserted in the current context", ^{
                NSManagedObject *o = [stack insertObject];
                [stack saveContext];
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                [o shouldNotBeNil];
                [[[[results.lastObject objectID] URIRepresentation] should] equal:[o.objectID URIRepresentation]];
            });

            it(@"Should propagate object creation in a background context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.bubblin", 0);
                dispatch_sync(serial_queue, ^{
                    o = [stack insertObject];
                    [stack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                [o shouldNotBeNil];
                [[[[[results lastObject] objectID] URIRepresentation] should] equal:[o.objectID URIRepresentation]];
            });
            
            it(@"Should propagate object creation in between background contexts", ^{
                __block NSManagedObject *o = nil;
                __block NSManagedObject *p = nil;
                
                dispatch_queue_t serial_queue1 = dispatch_queue_create("com.julienfantin.bubblin2", 0);
                dispatch_sync(serial_queue1, ^{
                    o = [stack insertObject];
                    [stack saveContext];
                });
                
                dispatch_queue_t serial_queue2 = dispatch_queue_create("com.julienfantin.bubblin3", 0);
                dispatch_sync(serial_queue2, ^{
                    p = [stack insertObject];
                    [stack saveContext];
                });
                
                __block BOOL pass = NO;
                dispatch_sync(serial_queue1, ^{
                    NSError *error = nil;
                    NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                    pass = [[[(NSManagedObject *)results.lastObject objectID] URIRepresentation] isEqual:[p.objectID URIRepresentation]];
                });
                
                [[expectFutureValue(theValue(pass)) shouldEventually] beYes];
            });            

            it(@"Should propagate object creation in a global context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = [stack insertObject];
                    [stack saveContext];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                [[[[[results lastObject] objectID] URIRepresentation] should] equal:[o.objectID URIRepresentation]];
            });
        });
        
        context(@"Different stores", ^{

            __block CDStack *child;
            
            beforeAll(^{
                child = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
                child.parentStack = stack;
            });
            
            afterAll(^{
                [child wipeStores];
                child = nil;
            });
            
            it(@"Should allow to compose stack", ^{
                [[child.parentStack should] beIdenticalTo:stack];
            });
            
            it(@"Should allow nesting", ^{
            
                CDStack *childStack = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
                childStack.parentStack = stack;
                
                [[[stack should] receive] mergeChangesFromChildStack:[KWAny any]];
            
                __block NSManagedObject *o = nil;
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = [childStack insertObject];
                    [childStack saveContext];
                });
                
                NSError *error = nil;
                NSArray *childResults = [childStack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                __block NSArray *results = nil;
                dispatch_after(1, dispatch_get_main_queue(), ^{
                    results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:nil];
                });
                
                [o shouldNotBeNil];
                [[[[childResults.lastObject objectID] URIRepresentation] should] equal:[o.objectID URIRepresentation]];
                [[[[results.lastObject objectID] URIRepresentation] shouldEventually] equal:[o.objectID URIRepresentation]];

            });

        });
    });
});

SPEC_END