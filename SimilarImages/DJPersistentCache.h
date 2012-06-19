/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Foundation/Foundation.h>

@interface DJPersistentCache : NSObject

@property (readwrite, assign) NSInteger maxEntryCount;
@property (readwrite, retain) NSURL* URL;

- (id)initWithURL:(NSURL*)cacheURL;


- (void)writeToPersistentStore;
- (BOOL)writeToURL:(NSURL*)cacheURL error:(NSError**)error;


- (id)objectForKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key;

@end
