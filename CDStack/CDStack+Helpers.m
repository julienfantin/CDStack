//
//  CDStack+Helpers.m
//  CDStack
//
//  Created by Julien Fantin on 24/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack+Helpers.h"

@implementation CDStack (Helpers)

- (NSArray *)objectIDsForObjects:(NSArray *)objects
{
    NSParameterAssert([objects isKindOfClass:[NSArray class]]);
    
    NSMutableArray *objectIDs = [NSMutableArray arrayWithCapacity:[objects count]];
    
    [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[NSManagedObject class]]) {
            NSManagedObjectID *objectID = [(NSManagedObject *)obj objectID];
            [objectIDs addObject:objectID];
        }
    }];
    
    return objectIDs;
}

- (NSArray *)objectsForObjectIDs:(NSArray *)objectIDs
{
    NSParameterAssert([objectIDs isKindOfClass:[NSArray class]]);
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[objectIDs count]];
    
    [objectIDs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSManagedObjectID *objectID = (NSManagedObjectID *)obj;
        NSManagedObject *object = [self.managedObjectContext objectWithID:objectID];
        [objects addObject:object];
    }];
    
    return objects;
}

@end
