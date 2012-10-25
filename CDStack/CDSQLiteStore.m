//
//  CDCacheStore.m
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDSQLiteStore.h"

@interface CDSQLiteStore ()
+ (NSURL *)applicationDocumentsDirectory;
@end

@implementation CDSQLiteStore

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
