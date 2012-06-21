/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
	Implements the "averaging" technique found here: http://www.hackerfactor.com/blog/index.php?/archives/432-Looks-Like-It.html
 */

#import "DjImageHash.h"

#define HAMMING_DISTANCE(A,B)	({ unsigned long long __BD = (A) ^ (B); __builtin_popcountll(__BD); })


static const size_t DOWNSAMPLE_SIZE = 8;
static BOOL _initialized;
static CGColorSpaceRef _gray_color_space;
static NSDictionary* _image_source_options;


static void _DJImageHashInitialize(void)
{
	_gray_color_space = CGColorSpaceCreateDeviceGray();	
	_image_source_options = [[NSDictionary alloc]  initWithObjectsAndKeys:
		 [NSNumber numberWithUnsignedInteger:DOWNSAMPLE_SIZE*2], kCGImageSourceThumbnailMaxPixelSize, /* double pixel resolution becuase thumbnail creator respects aspect ratio */
		 [NSNumber numberWithBool:NO], kCGImageSourceShouldCache,
		 nil];
	_initialized = YES;
}

NSInteger DJImageHashVersion()
{
	return 3;
}

#pragma mark -
#pragma mark Calculating hashes

image_hash_t DJImageHashFromURL(NSURL* imageURL)
{
	if (!_initialized)
		_DJImageHashInitialize();
		
	CGImageSourceRef image_source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, (__bridge CFDictionaryRef)_image_source_options);
	
	if (image_source == NULL)
	{
		NSLog(@"%s: couldn't load image source %@; file probably doesn't exist.", __func__, imageURL);
		return 0;
	}
	
	CGImageRef thumbnail_image = CGImageSourceCreateThumbnailAtIndex(image_source, 0, (__bridge CFDictionaryRef)_image_source_options);
	
	if (thumbnail_image == NULL)
		thumbnail_image = CGImageSourceCreateImageAtIndex(image_source, 0, (__bridge CFDictionaryRef)_image_source_options);
	
	CFRelease(image_source);
	
	if (thumbnail_image == NULL)
	{
		NSLog(@"%s: couldn't generate thumbnail. Image data is probably corrupt.", __func__);
		return 0;
	}
	
	// Create a gray 8x8 representation.
	uint8 data[DOWNSAMPLE_SIZE * DOWNSAMPLE_SIZE];
	CGContextRef gray_bitmap_context = CGBitmapContextCreate(data, DOWNSAMPLE_SIZE, DOWNSAMPLE_SIZE, 8, DOWNSAMPLE_SIZE, _gray_color_space, kCGImageAlphaNone);
	CGContextSetInterpolationQuality(gray_bitmap_context, kCGInterpolationHigh);
	CGContextDrawImage(gray_bitmap_context, NSMakeRect(0, 0, 8, 8), thumbnail_image);
	CGImageRelease(thumbnail_image);
	
	// Calculate mean pixel value
	uint8* p = data;
	NSInteger mean_pixel = 0;
	for (NSInteger i = 0; i < (NSInteger)(DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE); i++)
		mean_pixel += *(p++);
	
	mean_pixel /= DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE;
	
	// Calculate image hash	
	p = data;
	uint64_t hash_value = 0;
	for (NSInteger i = 0; i < (NSInteger)(DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE); i++)
		if ((NSInteger)(*(p++)) > mean_pixel)
			hash_value |= (1UL << i);

	/*// Write the image to a test file.
	 CGImageRef image_ref = CGBitmapContextCreateImage(gray_bitmap_context);
	 NSImage* output_image = [[NSImage alloc] initWithCGImage:image_ref size:NSZeroSize];
	 CGImageRelease(image_ref);
	 [[output_image TIFFRepresentation] writeToFile:[@"~/ShortTerm/out.tif" stringByExpandingTildeInPath] atomically:NO];*/
	
	CGContextRelease(gray_bitmap_context);
	return (hash_value == 0) ? 1 : hash_value;
}


#pragma mark -
#pragma mark Transforming hashes

// Rotate a hash. `degrees' must equal one of: 0, 90, 180, 270
image_hash_t DJImageHashRotate(image_hash_t hash, NSInteger degrees)
{
	image_hash_t new_hash = 0;
	
	switch (degrees)
	{
		case 0:
			return hash;
			break;
			
		case 90:

			
			break;
			
			
		case 180:
			break;
		
		case 270:
			break;
	}
	
	
	return new_hash;
}

// Flip a hash.
image_hash_t DJImageHashVerticalFlip(image_hash_t hash)
{
	// Swap each byte in the hash
	return  ((hash << 56) | 
			((hash << 40) & 0xff000000000000ULL) | 
			((hash << 24) & 0xff0000000000ULL) | 
			((hash << 8)  & 0xff00000000ULL) | 
			((hash >> 8)  & 0xff000000ULL) | 
			((hash >> 24) & 0xff0000ULL) | 
			((hash >> 40) & 0xff00ULL) | 
			((hash >> 56)));
}

image_hash_t DJImageHashHorizontalFlip(NSUInteger hash)
{
	image_hash_t newHash = 0;
	
	// For each byte in hash, flip bits
	for (int i = 0; i < 64; i += 8)
	{
		uint8_t b = (hash >> i) & 0xff;
		b = (b * 0x0202020202ULL & 0x010884422010ULL) % 1023;
		newHash |= (unsigned long long)b << i;
	}

	return newHash;
}


#pragma mark Comparing Hashes

// Bit distance between two hashes
NSInteger DJCompareHashes(image_hash_t hash1, image_hash_t hash2)
{
	return (NSInteger)HAMMING_DISTANCE(hash1, hash2);
}

// Bit distance between two hashes; first image will be transformed using all available transforms; closest distance will be returned.
NSInteger DJCompareHashesWithTransforms(image_hash_t hash1, image_hash_t hash2)
{
	image_hash_t alternateHashes[3];
	
	alternateHashes[0] = hash1;
	alternateHashes[1] = DJImageHashVerticalFlip(hash1);
	alternateHashes[2] = DJImageHashHorizontalFlip(hash1);	
	
	int smallestDistance = 64, dist;
	for (int i = 0; i < (int)(sizeof(alternateHashes) / sizeof(image_hash_t)); i++)
	{
		dist = DJCompareHashes(alternateHashes[i], hash2);
		
		if (dist < smallestDistance)
			smallestDistance = dist;
	}
	
	return smallestDistance;
}

