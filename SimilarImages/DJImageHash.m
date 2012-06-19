/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
	Implements the "averaging" technique found here: http://www.hackerfactor.com/blog/index.php?/archives/432-Looks-Like-It.html
 */

#import "DjImageHash.h"


CGColorSpaceRef _gray_color_space;

@implementation DJImageHash

@synthesize imageURL;

+ (void)initialize
{
	_gray_color_space = CGColorSpaceCreateDeviceGray();
}

+ (NSInteger)hashVersion
{
	return 1;
}

- (id)initWithImageURL:(NSURL*)image
{
	if (!(self = [super init]))
		return nil;
	
	[self setImageURL:image];
	return self;
}

- (BOOL)_calculateHash
{
	const size_t DOWNSAMPLE_SIZE = 8;

	// Load the image.
	NSDictionary* image_source_options = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithUnsignedInteger:DOWNSAMPLE_SIZE*2], kCGImageSourceThumbnailMaxPixelSize, /* double pixel resolution becuase thumbnail creator respects aspect ratio */
										nil];
	
	CGImageSourceRef image_source = CGImageSourceCreateWithURL((__bridge CFURLRef)[self imageURL], (__bridge CFDictionaryRef)image_source_options);
	
	if (image_source == NULL)
	{
		NSLog(@"%s: couldn't load image source %@; file probably doesn't exist.", __func__, [self imageURL]);
		return NO;
	}
	
	CGImageRef thumbnail_image = CGImageSourceCreateThumbnailAtIndex(image_source, 0, (__bridge CFDictionaryRef)image_source_options);
	
	if (thumbnail_image == NULL)
		thumbnail_image = CGImageSourceCreateImageAtIndex(image_source, 0, (__bridge CFDictionaryRef)image_source_options);
	
	CFRelease(image_source);
	
	if (thumbnail_image == NULL)
	{
		NSLog(@"%s: couldn't generate thumbnail. Image data is probably corrupt.", __func__);
		return NO;
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
	for (int i = 0; i < DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE; i++)
		mean_pixel += *(p++);
	
	mean_pixel /= DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE;
	
	// Calculate image hash	
	p = data;
	uint64_t hash_value = 0;
	for (int i = 0; i < DOWNSAMPLE_SIZE*DOWNSAMPLE_SIZE; i++)
		if ((NSInteger)(*(p++)) > mean_pixel)
			hash_value |= (1UL << i);

	_hash = hash_value;
	
	
	/*// Write the image to a test file.
	CGImageRef image_ref = CGBitmapContextCreateImage(gray_bitmap_context);
	NSImage* output_image = [[NSImage alloc] initWithCGImage:image_ref size:NSZeroSize];
	CGImageRelease(image_ref);
	[[output_image TIFFRepresentation] writeToFile:[@"~/ShortTerm/out.tif" stringByExpandingTildeInPath] atomically:NO];*/
	
	CGContextRelease(gray_bitmap_context);
	return YES;
}

- (uint64_t)imageHash
{
	if (_hash == 0)
		[self _calculateHash];
		
	return _hash;	
}


@end
