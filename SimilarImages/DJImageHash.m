/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
	Implements the "averaging" technique found here: http://www.hackerfactor.com/blog/index.php?/archives/432-Looks-Like-It.html
 */

#import "DjImageHash.h"

#define HAMMING_DISTANCE(A,B)	({ unsigned long long __BD = (A) ^ (B); __builtin_popcountll(__BD); })

typedef enum _DJImageHashTypes {
	DJImageHashTypeDCT = 0,
	DJImageHashTypeDCTRotated90Degrees,
	DJImageHashTypeDCTRotated180Degrees,  
	DJImageHashTypeDCTRotated270Degrees, 
	DJImageHashTypeDCTFlippedHorizontally,
	DJImageHashTypeDCTFlippedVertically
} DJImageHashTypes;


#include </usr/local/include/fftw3.h>

#include <libkern/OSAtomic.h>

@interface DJImageHash ()
@property (readwrite) NSInteger version;
@property (readwrite) NSDictionary* hashes;
@end

static const int DCT_DOWNSAMPLE_SIZE = 32;

OSSpinLock imagehash_fftw_lock = OS_SPINLOCK_INIT; 


@implementation DJImageHash

@synthesize URL, version, hashes;

- (id)init
{
	if (!(self = [super init]))
		return nil;
	
	return self;
}

- (id)initWithURL:(NSURL*)url
{
	if (!(self = [self init]))
		return nil;
	
	[self setURL:url];

	return self;
}

+ (NSInteger)latestVersion
{
	return 14;
}


#pragma mark -
#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if (!(self = [self init]))
		return nil;
	
	if ([decoder containsValueForKey:@"v"])
		[self setVersion:[decoder decodeIntegerForKey:@"v"]];
	
	if ([decoder containsValueForKey:@"h"])
		[self setHashes:[decoder decodeObjectForKey:@"h"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:[self version] forKey:@"v"];
	
	if ([self hashes])
		[coder encodeObject:[self hashes] forKey:@"h"];
}


#pragma mark -
#pragma mark Comparing hashes

- (NSNumber*)similarityTo:(DJImageHash*)hash considerTransforms:(BOOL)transform
{
	if ( ![self haveCalculatedHashWithTransforms:transform] && ![self calculateHashWithTransforms:transform])
		return nil;
		
	if ( ![hash haveCalculatedHash] && ![hash calculateHashWithTransforms:NO])
		return nil;

	NSInteger smallestDistance = 64;
	NSUInteger comparisonHashValue = [[[hash hashes] objectForKey:[NSNumber numberWithInteger:DJImageHashTypeDCT]] unsignedIntegerValue];	
	
	if (transform)
	{
		for (NSNumber* hashValue in [[self hashes] allValues])
		{
			NSInteger distance = HAMMING_DISTANCE([hashValue unsignedIntegerValue], comparisonHashValue);
			
			if (distance < smallestDistance)
				smallestDistance = distance;
		}		
	}
	else
	{
		smallestDistance = HAMMING_DISTANCE([[[self hashes] objectForKey:[NSNumber numberWithInteger:DJImageHashTypeDCT]] unsignedIntegerValue], comparisonHashValue);
	}
	
	
	// Convert hamming distance into 0 - 100 score. Distance of 0-18 is a certain match. 19-22 is a potential match. 23-26 is an unlikely match. Anything more is extremely unlikely. This unscientific mapping produces a rough probability distribution of a match.
	double x = 100 - pow(smallestDistance, 2.5) / 35.0;
	
	if (x < 0.0)
		return [NSNumber numberWithBool:NO];
	
	return [NSNumber numberWithDouble:x];
}


#pragma mark -
#pragma mark Transforms

- (BOOL)canTransform
{
	return [self URL] != nil;
}

- (BOOL)haveCalculatedHashWithTransforms:(BOOL)transforms
{
	return (transforms) ? [self haveCalculatedTransforms] : [self haveCalculatedHash];
}
- (BOOL)haveCalculatedHash
{
	return [[self hashes] count] >= 1;
}

- (BOOL)haveCalculatedTransforms
{
	return [[self hashes] count] > 1;
}

#pragma mark -
#pragma mark Serializing FFTW accesses

+ (void)lockFFTW
{
	OSSpinLockLock(&imagehash_fftw_lock);

}

+ (void)unlockFFTW
{
	OSSpinLockUnlock(&imagehash_fftw_lock);

}


#pragma mark -
#pragma mark Calculating hashes

- (BOOL)calculateHashWithTransforms:(BOOL)calculateTransformedHashes
{
	return [self _calculateDCTHashesWithTransforms:calculateTransformedHashes];
}

- (BOOL)_calculateDCTHashesWithTransforms:(BOOL)transforms
{
	static CGColorSpaceRef _gray_color_space;
	static CFDictionaryRef _image_source_options;
	static BOOL _initialized = NO;
	
	if (!_initialized)
	{
		_gray_color_space = CGColorSpaceCreateDeviceGray();
		_image_source_options = (__bridge_retained CFDictionaryRef)[[NSDictionary alloc]  initWithObjectsAndKeys:
																	[NSNumber numberWithUnsignedInteger:DCT_DOWNSAMPLE_SIZE*2], kCGImageSourceThumbnailMaxPixelSize, /* double pixel resolution becuase thumbnail creator respects aspect ratio */
																	[NSNumber numberWithBool:NO], kCGImageSourceShouldCache,
																	nil];
		_initialized = YES;
	}
	
	
	CGImageSourceRef image_source = CGImageSourceCreateWithURL((__bridge CFURLRef)[self URL], _image_source_options);
	
	if (image_source == NULL)
	{
		NSLog(@"%s: couldn't load image source %@; file probably doesn't exist.", __func__, [self URL]);
		return NO;
	}
	
	CGImageRef thumbnail_image = CGImageSourceCreateThumbnailAtIndex(image_source, 0, _image_source_options);
	
	if (thumbnail_image == NULL)
		thumbnail_image = CGImageSourceCreateImageAtIndex(image_source, 0, _image_source_options);
	
	CFRelease(image_source);
	
	if (thumbnail_image == NULL)
	{
		NSLog(@"%s: couldn't generate thumbnail. Image data is probably corrupt.", __func__);
		return NO;
	}
	
	[self setHashes:[self _calculateDCTHashesForCGImage:thumbnail_image transforms:transforms]];
	CGImageRelease(thumbnail_image);

	return [[self hashes] count] > 0;	
}

- (NSDictionary*)_calculateDCTHashesForCGImage:(CGImageRef)image transforms:(BOOL)calculateTransforms
{
	static CGColorSpaceRef _gray_color_space = NULL;
	
	if (_gray_color_space == NULL)
		_gray_color_space = CGColorSpaceCreateDeviceGray();
	
	NSMutableDictionary* calculatedHashes = [NSMutableDictionary dictionary];
	uint8 data[DCT_DOWNSAMPLE_SIZE * DCT_DOWNSAMPLE_SIZE];
	
	// Create the gray representation, will be left in `data'
	CGContextRef bcontext = CGBitmapContextCreate(data, DCT_DOWNSAMPLE_SIZE, DCT_DOWNSAMPLE_SIZE, 8, DCT_DOWNSAMPLE_SIZE, _gray_color_space, kCGImageAlphaNone);
	CGRect drawImageRect = CGRectMake(0, 0, DCT_DOWNSAMPLE_SIZE, DCT_DOWNSAMPLE_SIZE);
	CGContextSetInterpolationQuality(bcontext, kCGInterpolationHigh);
	CGContextDrawImage(bcontext, drawImageRect, image);
	
	// Hash the original image.
	[calculatedHashes setObject:[self _dctHashForImageData:data] forKey:[NSNumber numberWithInteger:DJImageHashTypeDCT]];
	
	// If requested, create transformed hashes as well.
	if (calculateTransforms)
	{
		[self writeBitmapContext:bcontext toDebugFile:@"orig"];
		
		// The three rotations: 90, 180, 270. One extra element to get the CTM back to a normal state.
		for (id transformIndex in [NSArray arrayWithObjects:[NSNumber numberWithInteger:DJImageHashTypeDCTRotated90Degrees], [NSNumber numberWithInteger:DJImageHashTypeDCTRotated180Degrees], [NSNumber numberWithInteger:DJImageHashTypeDCTRotated270Degrees], [NSNull null], nil])
		{
			CGContextTranslateCTM(bcontext, DCT_DOWNSAMPLE_SIZE/2, DCT_DOWNSAMPLE_SIZE/2);
			CGContextRotateCTM(bcontext, M_PI / 2.0);
			CGContextTranslateCTM(bcontext, -DCT_DOWNSAMPLE_SIZE/2, -DCT_DOWNSAMPLE_SIZE/2);
			
			if ([transformIndex isKindOfClass:[NSNull class]])
				break;
			
			CGContextDrawImage(bcontext, drawImageRect, image);
			[self writeBitmapContext:bcontext toDebugFile:[NSString stringWithFormat:@"rot-%@", transformIndex]];
			[calculatedHashes setObject:[self _dctHashForImageData:data] forKey:transformIndex];
		}

		// Flip horizontally.
		CGContextScaleCTM(bcontext, -1.0, 1.0);
		CGContextTranslateCTM(bcontext, -DCT_DOWNSAMPLE_SIZE, 0);
		CGContextDrawImage(bcontext, drawImageRect, image);
		[self writeBitmapContext:bcontext toDebugFile:@"horiz"];
		[calculatedHashes setObject:[self _dctHashForImageData:data] forKey:[NSNumber numberWithInteger:DJImageHashTypeDCTFlippedHorizontally]];
		
		
		// Flip vertically.
		CGContextScaleCTM(bcontext, -1.0, -1.0);
		CGContextTranslateCTM(bcontext, -DCT_DOWNSAMPLE_SIZE, -DCT_DOWNSAMPLE_SIZE);
		CGContextDrawImage(bcontext, drawImageRect, image);
		[self writeBitmapContext:bcontext toDebugFile:@"vert"];
		[calculatedHashes setObject:[self _dctHashForImageData:data] forKey:[NSNumber numberWithInteger:DJImageHashTypeDCTFlippedVertically]];
	}
	
	CGContextRelease(bcontext);
	return calculatedHashes;
}


- (NSNumber*)_dctHashForImageData:(unsigned char*)data
{
	float dct_data[DCT_DOWNSAMPLE_SIZE*DCT_DOWNSAMPLE_SIZE];
	
	for (int i = 0; i < (int)(DCT_DOWNSAMPLE_SIZE*DCT_DOWNSAMPLE_SIZE); i++)
		dct_data[i] = (double)data[i] - 127;
	
	fftwf_plan plan;
	
	// Do the DCT.
	[[self class] lockFFTW];
	plan = fftwf_plan_r2r_2d(DCT_DOWNSAMPLE_SIZE, DCT_DOWNSAMPLE_SIZE, dct_data, dct_data, FFTW_REDFT10, FFTW_REDFT10, FFTW_ESTIMATE);
	[[self class] unlockFFTW];

	fftwf_execute(plan);
	
	[[self class] lockFFTW];
	fftwf_destroy_plan(plan);
	[[self class] unlockFFTW];
	
	
	/* Debugging: write out an inverse-fft copy.
	for (int i = 3; i < 32; i++)
	 for (int j = 3; j < 32; j++)
	 dct_data[i*32 + j] = 0;
	 
	 // idct
	 plan = fftwf_plan_r2r_2d(DOWNSAMPLE_SIZE, DOWNSAMPLE_SIZE, dct_data, dct_data, FFTW_REDFT01, FFTW_REDFT01, FFTW_ESTIMATE);
	 fftwf_execute(plan);
	 fftwf_destroy_plan(plan);
	 */
	/*for (int i = 0; i < (int)(DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE); i++)
	 data[i] = dct_data[i] / (4.0*DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE) + 127;*/
	
	
	// Calculate mean frequency value of top 8x8 bins
	float* p = dct_data;
	float mean_pixel = 0;
	mean_pixel -= dct_data[0]; // ignore the DC component
	for (int i = 0; i < 8; i++)
	{
		for (int j = 0; j < 8; j++)
			mean_pixel += *(p++);
		
		p += 24;
	}
	
	mean_pixel /= 63;
	
	
	// Calculate image hash, by setting bits high if that frequency bin is higher than the mean.
	NSUInteger hash_value = 0;
	p = dct_data;
	for (int i = 0; i < 8; i++)
	{
		for (int j = 0; j < 8; j++)
		{	
			if (*(p++) > mean_pixel)
				hash_value |= (1UL << (i*8+j));
		}
		
		p += 24;
	}
	
	return [NSNumber numberWithUnsignedInteger:hash_value];
}

- (void)writeBitmapContext:(CGContextRef)context toDebugFile:(NSString*)name
{
#if 0
	CGImageRef image_ref = CGBitmapContextCreateImage(context);
	NSImage* output_image = [[NSImage alloc] initWithCGImage:image_ref size:NSZeroSize];
	CGImageRelease(image_ref);
	[[output_image TIFFRepresentation] writeToFile:[[NSString stringWithFormat:@"~/ShortTerm/sd-dbg %@.tif", name] stringByExpandingTildeInPath] atomically:NO];
#endif
}





@end

















#pragma mark -
#pragma mark Transforming hashes
/*
// From Hacker's Delight, 7-3, http://www.hackersdelight.org/HDcode/transpose8.c.txt
static uint64_t transpose8b64(uint64_t x)
{
	return	(x & 0x8040201008040201LL)         |
			(x & 0x0080402010080402LL) <<  7   |
			(x & 0x0000804020100804LL) << 14   |
			(x & 0x0000008040201008LL) << 21   |
			(x & 0x0000000080402010LL) << 28   |
			(x & 0x0000000000804020LL) << 35   |
			(x & 0x0000000000008040LL) << 42   |
			(x & 0x0000000000000080LL) << 49   |
			((x >>  7) & 0x0080402010080402LL) |
			((x >> 14) & 0x0000804020100804LL) |
			((x >> 21) & 0x0000008040201008LL) |
			((x >> 28) & 0x0000000080402010LL) |
			((x >> 35) & 0x0000000000804020LL) |
			((x >> 42) & 0x0000000000008040LL) |
			((x >> 49) & 0x0000000000000080LL) ;
}


// Rotate a hash. `degrees' must equal one of: 0, 90, 180, 270
image_hash_t DJImageHashRotate(image_hash_t hash, NSInteger degrees)
{
	image_hash_t new_hash = 0;
	
	switch (degrees)
	{
		case 0:
			return hash;
			
		case 90:
			return DJImageHashHorizontalFlip(transpose8b64(hash));
			
		case 180:
			return DJImageHashVerticalFlip(DJImageHashHorizontalFlip(hash));
		
		case 270:
			return DJImageHashVerticalFlip(transpose8b64(hash));
			break;
	}
	
	return 0;
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
NSInteger DJImageHashCompare(image_hash_t hash1, image_hash_t hash2)
{
	return (NSInteger)HAMMING_DISTANCE(hash1, hash2);
}

// Bit distance between two hashes; first image will be transformed using all available transforms; closest distance will be returned.
NSInteger DJImageHashCompareWithTransforms(image_hash_t hash1, image_hash_t hash2)
{
	image_hash_t alternateHashes[6];
	
	alternateHashes[0] = hash1;
	alternateHashes[1] = DJImageHashVerticalFlip(hash1);
	alternateHashes[2] = DJImageHashHorizontalFlip(hash1);
	alternateHashes[3] = DJImageHashRotate(hash1, 90);
	alternateHashes[4] = DJImageHashRotate(hash1, 180);
	alternateHashes[5] = DJImageHashRotate(hash1, 270);
	
	int smallestDistance = 64, dist;
	for (int i = 0; i < (int)(sizeof(alternateHashes) / sizeof(image_hash_t)); i++)
	{
		dist = DJImageHashCompare(alternateHashes[i], hash2);
		
		if (dist < smallestDistance)
			smallestDistance = dist;
	}
	
	return smallestDistance;
}


*/










#if 0
image_hash_t DJAverageImageHashFromURL(NSURL* imageURL)
{
	static const size_t DOWNSAMPLE_SIZE = 8;
	static CGColorSpaceRef _gray_color_space;
	static CFDictionaryRef _image_source_options;
	static BOOL _initialized = NO;
	
	if (!_initialized)
	{
		_gray_color_space = CGColorSpaceCreateDeviceGray();	
		_image_source_options = (__bridge_retained CFDictionaryRef)[[NSDictionary alloc]  initWithObjectsAndKeys:
																	[NSNumber numberWithUnsignedInteger:DOWNSAMPLE_SIZE*2], kCGImageSourceThumbnailMaxPixelSize, /* double pixel resolution becuase thumbnail creator respects aspect ratio */
																	[NSNumber numberWithBool:NO], kCGImageSourceShouldCache,
																	nil];
		_initialized = YES;
		
	}
	
	CGImageSourceRef image_source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, _image_source_options);
	
	if (image_source == NULL)
	{
		NSLog(@"%s: couldn't load image source %@; file probably doesn't exist.", __func__, imageURL);
		return 0;
	}
	
	CGImageRef thumbnail_image = CGImageSourceCreateThumbnailAtIndex(image_source, 0, _image_source_options);
	
	if (thumbnail_image == NULL)
		thumbnail_image = CGImageSourceCreateImageAtIndex(image_source, 0, _image_source_options);
	
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
	CGContextDrawImage(gray_bitmap_context, NSMakeRect(0, 0, DOWNSAMPLE_SIZE, DOWNSAMPLE_SIZE), thumbnail_image);
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
#endif