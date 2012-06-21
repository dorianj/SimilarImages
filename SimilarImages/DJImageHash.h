/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Foundation/Foundation.h>

typedef uint64_t image_hash_t;

// Misc
NSInteger DJImageHashVersion();

#pragma mark Calculating hashes

image_hash_t DJImageHashFromURL(NSURL* image);


#pragma mark Transforming hashes

// Rotate a hash. `degrees' must equal one of: 0, 90, 180, 270
image_hash_t DJImageHashRotate(image_hash_t hash, NSInteger degrees);

// Flip a hash.
image_hash_t DJImageHashVerticalFlip(image_hash_t hash);
image_hash_t DJImageHashHorizontalFlip(NSUInteger hash);
