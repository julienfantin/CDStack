//
//  CDStack+Helpers.h
//  CDStack
//
//  Created by Julien Fantin on 24/10/12.
//  Copyright (c) 2012 Julien Fantin. All rights reserved.
//

#import "CDStack.h"

@interface CDStack (Helpers)
+ (NSArray *)objectIDsForObjects:(NSArray *)objects;
+ (NSArray *)objectsForObjectIDs:(NSArray *)objectIDs;
@end
