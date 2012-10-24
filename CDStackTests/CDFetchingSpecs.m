//
//  CDFetchingSpecs.m
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "CDStack.h"
#import "CDCacheStore.h"

SPEC_BEGIN(CDFetchingSpecs)

describe(@"Blocks API", ^{
    __block NSFetchRequest *fetchRequest;
    __block NSFetchRequest *fetchRequest2;
    
    beforeAll(^{
        fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Event"];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES]];
        fetchRequest2 = [NSFetchRequest fetchRequestWithEntityName:@"Event"];
        fetchRequest2.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:NO]];
    });
    
    __block CDStack *stack;
    
    beforeEach(^{
        stack = [[CDStack alloc] initWithStoreClass:[CDCacheStore class]];
    });
    
    it(@"fetches a request and passes results to a block", ^{
        __block NSArray *results = nil;
        
        [stack fetch:fetchRequest withResults:^(NSArray *_results){
            results = _results;
        }];
        
        [[expectFutureValue(results) shouldEventually] beNonNil];
    });
        
    //    it(@"fetches multiple requests and calls the result block with the results combined in a dictionary keyed by request", ^{
    //        __block NSDictionary *results = nil;
    //        NSArray *requests = @[fetchRequest, fetchRequest2];
    //        [CDStack fetches:requests withCombinedResults:^(NSDictionary *_results) {
    //            results = _results;
    //        }];
    //
    //        [[expectFutureValue(results) shouldEventually] beNonNil];
    //        [[expectFutureValue([results allKeys]) should] haveCountOf:2];
    //        [[expectFutureValue([results allValues]) should] containObjectsInArray:requests];
    //        [[expectFutureValue([[results allValues] lastObject]) shouldNot] beEmpty];
    //    });
});

SPEC_END