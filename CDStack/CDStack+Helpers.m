//
//  CDStack+Helpers.m
//  CDStack
//
//  Created by Julien Fantin on 24/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack+Helpers.h"

@implementation NSArray (CDStackHelpers)

- (NSArray *)objectIDsFromObjects
{
    NSMutableArray *objectIDs = [NSMutableArray arrayWithCapacity:[self count]];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[NSManagedObject class]]) {
            NSManagedObjectID *objectID = [(NSManagedObject *)obj objectID];
            [objectIDs addObject:objectID];
        }
    }];
    
    return [NSArray arrayWithArray:objectIDs];
}

- (NSArray *)objectsFromObjectIDsWithContext:(NSManagedObjectContext *)context
{
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[self count]];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[NSManagedObjectID class]]) {
            NSManagedObjectID *objectID = (NSManagedObjectID *)obj;
            NSManagedObject *object = [context objectWithID:objectID];
            [objects addObject:object];
        }
    }];
    
    return [NSArray arrayWithArray:objects];
}

+ (NSArray *)arrayByMergingArrays:(NSArray *)arrays
{
    NSMutableArray *merge = [NSMutableArray array];
    for (NSArray *array in arrays) {
        merge = [[merge arrayByAddingObjectsFromArray:array] mutableCopy];
    }
    return merge;
}

@end
