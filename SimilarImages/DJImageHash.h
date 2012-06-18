/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Foundation/Foundation.h>

@interface DJImageHash : NSObject {
@protected
	uint64_t _hash;
}

@property NSURL* imageURL;

- (id)initWithImageURL:(NSURL*)image;
- (uint64_t)imageHash;

+ (NSInteger)hashVersion;


@end
