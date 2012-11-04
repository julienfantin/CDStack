//
//  CDStack+SpecsHelpers.m
//  CDStack
//
//  Created by Julien Fantin on 24/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack+SpecsHelpers.h"

@implementation CDStack (SpecsHelpers)

- (id)insertObject
{
    NSEntityDescription *e = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    NSManagedObject *o = [[NSManagedObject alloc] initWithEntity:e insertIntoManagedObjectContext:self.managedObjectContext];
    [o setValue:[NSDate date] forKey:@"timeStamp"];
    return o;
}

- (void)wipeStores
{
    for (NSPersistentStore *store in self.persistentStoreCoordinator.persistentStores) {
        NSError *error = nil;
        if (![self.persistentStoreCoordinator removePersistentStore:store error:&error]) {
            NSLog(@"Couldn't remove store\n%@", error);
            abort();
        }
        
        if (![[NSFileManager defaultManager] removeItemAtPath:store.URL.path error:&error]) {
            NSLog(@"Couldn't delete store file\n%@",error);
        }
    }
}

@end
