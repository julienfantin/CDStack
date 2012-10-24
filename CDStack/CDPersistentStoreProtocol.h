//
//  CDPersistentStoreProtocol.h
//  CDStack
//
//  Created by Julien Fantin on 23/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CDPersistentStore <NSObject>
@required
+ (NSString *)type;
@optional
+ (NSURL *)url;
+ (NSString *)configuration;
+ (NSDictionary *)options;
@end
