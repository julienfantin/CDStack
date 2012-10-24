//
//  CDCacheStore.m
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDCacheStore.h"

@interface CDCacheStore ()
+ (NSURL *)applicationDocumentsDirectory;
@end

@implementation CDCacheStore

+ (NSString *)type
{
    return NSSQLiteStoreType;
}

+ (NSURL *)url
{
    return [[[self class] applicationDocumentsDirectory] URLByAppendingPathComponent:@"CDStack.sqlite"];
}

#pragma mark - Path helper

+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
