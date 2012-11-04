//
//  CDStackTests.m
//  CDStackTests
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Specta/Specta.h>
#define EXP_SHORTHAND
#import <Expecta/Expecta.h>

#import "CDStack.h"
#import "CDStack+SpecsHelpers.h"
#import "CDSQLiteStore.h"
#import "CDAsyncStore.h"

SpecBegin(CDStackSpecs)

describe(@"CDStack", ^{
    
    __block CDStack *stack;
    
    beforeEach(^{
        stack = [[CDStack alloc] initWithStoreClass:[CDSQLiteStore class]];
    });
    
    afterEach(^{
        [stack wipeStores];
        stack = nil;
    });
    
    context(@"CoreData stack accessors", ^{
        
        it(@"Should stash its persistentStoreCoordinator into the mainThread's dictionary when accessed", ^{
            id psc = stack.persistentStoreCoordinator;
            expect([[[NSThread mainThread] threadDictionary] allValues]).to.contain(psc);
        });

        context(@"managedObjectContext", ^{
            __block NSManagedObjectContext *mainContext;
            
            beforeEach(^{
                mainContext = stack.managedObjectContext;
            });

            specify(@"should not be nil", ^{
                expect(mainContext).notTo.beNil();
            });
            
            it(@"Should be registered with the store coordinator", ^{
                expect(mainContext.persistentStoreCoordinator).to.equal(stack.persistentStoreCoordinator);;
            });
            
            context(@"Instances are per thread", ^{
                
                it(@"Should work on Main Thread", ^{
                    expect(stack.managedObjectContext).notTo.beNil();
                    expect(stack.managedObjectContext).to.equal(stack.managedObjectContext);
                });
                
                it(@"Should work in GCD global queues", ^{
                    __block BOOL pass = NO;
                    dispatch_queue_t confined_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                    dispatch_async(confined_queue, ^{
                        BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                        BOOL isConfined = mainContext != stack.managedObjectContext;
                        pass = isUnique && isConfined;
                    });
                    
                    expect(pass).will.beTruthy();
                });
                
                it(@"Should work in GCD private queues", ^{
                    __block BOOL pass = NO;
                    dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.CDStackSpecs", 0);
                    dispatch_async(serial_queue, ^{
                        BOOL isUnique = stack.managedObjectContext == stack.managedObjectContext;
                        BOOL isConfined = mainContext != stack.managedObjectContext;
                        pass = isUnique && isConfined;
                    });
                    expect(pass).will.beTruthy();
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
                [stack save];
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                expect(o).notTo.beNil();
                expect([results.lastObject objectID].URIRepresentation).to.equal([o.objectID URIRepresentation]);;
            });

            it(@"Should propagate object creation in a background context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t serial_queue = dispatch_queue_create("com.julienfantin.bubblin", 0);
                dispatch_sync(serial_queue, ^{
                    o = [stack insertObject];
                    [stack save];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                expect(o).notTo.beNil();
                expect([results.lastObject objectID].URIRepresentation).to.equal(o.objectID.URIRepresentation);
            });
            
            it(@"Should propagate object creation in between background contexts", ^{
                __block NSManagedObject *o = nil;
                __block NSManagedObject *p = nil;
                
                dispatch_queue_t serial_queue1 = dispatch_queue_create("com.julienfantin.bubblin2", 0);
                dispatch_sync(serial_queue1, ^{
                    o = [stack insertObject];
                    [stack save];
                });
                
                dispatch_queue_t serial_queue2 = dispatch_queue_create("com.julienfantin.bubblin3", 0);
                dispatch_sync(serial_queue2, ^{
                    p = [stack insertObject];
                    [stack save];
                });
                
                __block BOOL pass = NO;
                dispatch_sync(serial_queue1, ^{
                    NSError *error = nil;
                    NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                    pass = [[[(NSManagedObject *)results.lastObject objectID] URIRepresentation] isEqual:[p.objectID URIRepresentation]];
                });
                
                expect(pass).will.beTruthy();
            });            

            it(@"Should propagate object creation in a global context to the main thread's context", ^{
                __block NSManagedObject *o = nil;
                
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = [stack insertObject];
                    [stack save];
                });
                
                NSError *error = nil;
                NSArray *results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                expect([results.lastObject objectID].URIRepresentation).to.equal(o.objectID.URIRepresentation);
            });
        });
        
        context(@"Different stores", ^{

            __block CDStack *child;
            
            beforeEach(^{
                child = [[CDStack alloc] initWithStoreClass:[CDSQLiteStore class]];
                child.parentStack = stack;
            });
            
            afterEach(^{
                [child wipeStores];
                child = nil;
            });
            
            it(@"Should allow to compose stack by defining a parentStack", ^{
                expect(child.parentStack == stack).to.beTruthy();
            });
            
            it(@"Should propagate changes in a child stack to its parentStack", ^{
            
                CDStack *childStack = [[CDStack alloc] initWithStoreClass:[CDSQLiteStore class]];
                childStack.parentStack = stack;
                            
                __block NSManagedObject *o = nil;
                dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_sync(global_queue, ^{
                    o = [childStack insertObject];
                    [childStack save];
                });
                
                NSError *error = nil;
                NSArray *childResults = [childStack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                
                // Wait for the notification to be processed before fetching on the parentStack
                __block NSArray *results = nil;
                dispatch_after(1, dispatch_get_main_queue(), ^{
                    results = [stack.managedObjectContext executeFetchRequest:fetchRequest error:nil];
                });
                
                expect(o).notTo.beNil();
                expect([childResults.lastObject objectID].URIRepresentation).to.equal(o.objectID.URIRepresentation);
                expect([results.lastObject objectID].URIRepresentation).will.equal(o.objectID.URIRepresentation);
            });
        });
    });
});

SpecEnd