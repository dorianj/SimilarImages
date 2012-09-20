/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <Foundation/Foundation.h>

@interface DJPersistentCache : NSObject

@property (readwrite, assign) NSInteger maxEntryCount;
@property (readwrite, retain) NSURL* URL;


- (id)initWithURL:(NSURL*)cacheURL;


- (NSInteger)count;
- (void)writeToPersistentStore;
- (BOOL)writeToURL:(NSURL*)cacheURL error:(NSError**)error;


- (id)objectForKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key;
- (void)removeAllObjects;

@end
