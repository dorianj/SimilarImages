/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
	Implements the "averaging" technique found here: http://www.hackerfactor.com/blog/index.php?/archives/432-Looks-Like-It.html
 */

#import "DjImageHash.h"

static const size_t DOWNSAMPLE_SIZE = 8;
static BOOL _initialized;
static CGColorSpaceRef _gray_color_space;
static NSDictionary* _image_source_options;


static void _DJImageHashInitialize(void)
{
	_gray_color_space = CGColorSpaceCreateDeviceGray();	
	_image_source_options = [[NSDictionary alloc]  initWithObjectsAndKeys:
		 [NSNumber numberWithUnsignedInteger:DOWNSAMPLE_SIZE], kCGImageSourceThumbnailMaxPixelSize, /* double pixel resolution becuase thumbnail creator respects aspect ratio */
		 [NSNumber numberWithBool:NO], kCGImageSourceShouldCache,
		 nil];
	_initialized = YES;
}

NSInteger DJImageHashVersion()
{
	return 2;
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
	CGContextSetInterpolationQuality(gray_bitmap_context, kCGInterpolationLow);
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


