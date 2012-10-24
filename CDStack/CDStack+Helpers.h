//
//  CDStack+Helpers.h
//  CDStack
//
//  Created by Julien Fantin on 24/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack.h"

@interface NSArray (CDStackHelpers)
- (NSArray *)objectIDsFromObjects;
- (NSArray *)objectsFromObjectIDsWithContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayByMergingArrays:(NSArray *)arrays;
@end
