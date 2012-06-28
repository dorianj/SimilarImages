/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Foundation/Foundation.h>

@interface DJImageHash : NSObject <NSCoding>

@property (readwrite, retain) NSURL* URL;
@property (readonly) NSInteger version;

- (id)initWithURL:(NSURL*)url;

// The current version number of the class.
+ (NSInteger)latestVersion;


// Force the receiver to open image and calculate the hash; optionally, also calculate the hashes.
- (BOOL)calculateHashWithTransforms:(BOOL)calculateTransformedHashes;

// Returns a number between 0-100 representing how close the match is.
- (NSNumber*)similarityTo:(DJImageHash*)hash considerTransforms:(BOOL)transform;
@end




/*
 
 typedef uint64_t image_hash_t;
 
 // Misc
 NSInteger DJImageHashVersion();
 
 #pragma mark Calculating hashes
 
 image_hash_t DJImageHashFromURL(NSURL* image);
 image_hash_t DJImageHashFromURLWithTransforms(NSURL* image);
 
 
 #pragma mark Transforming hashes
 
 // Rotate a hash. `degrees' must equal one of: 0, 90, 180, 270
 image_hash_t DJImageHashRotate(image_hash_t hash, NSInteger degrees);
 
 // Flip a hash.
 image_hash_t DJImageHashVerticalFlip(image_hash_t hash);
 image_hash_t DJImageHashHorizontalFlip(NSUInteger hash);
 
 
 #pragma mark Comparing Hashes
 
 // Bit distance between two hashes
 NSInteger DJImageHashCompare(image_hash_t hash1, image_hash_t hash2);
 
 // Bit distance between two hashes; first image will be transformed using all available transforms; closest distance will be returned.
 NSInteger DJImageHashCompareWithTransforms(image_hash_t hash1, image_hash_t hash2);
 */