/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
*/

#import "DJImageTrawler.h"
#import "DJImageHash.h"

@interface DJImageTrawler ()

@property (readwrite) NSOperationQueue* processingQueue, * searchingQueue;
@property (readwrite) NSMutableArray* images;
@end

#pragma mark -
@interface DJDirectorySearchOperation : NSOperation
	@property DJImageTrawler* owner;
	@property NSURL* startURL;
@end

#pragma mark -
@interface DJImageProcessingOperation : NSOperation
	@property DJImageTrawler* owner; 
	@property NSURL* imageURL;
@end


#pragma mark -

@implementation DJImageTrawler

@synthesize searchingQueue, processingQueue, images;

- (id)initWithURL:(NSURL*)root_directory
{
	if (!(self = [super init]))
		return nil;
	
	// Create the operation queues for this instance.
	[self setProcessingQueue:[[NSOperationQueue alloc] init]];
	[self setSearchingQueue:[[NSOperationQueue alloc] init]];
	[[self processingQueue] setSuspended:YES];
	[self setImages:[NSMutableArray array]];
	_root = root_directory;
	return self;
}

- (void)trawlImagesWithProgressBlock:(void(^)(NSDictionary*))progress_block
{
	// Add the first operation, a search on the root directory.
	DJDirectorySearchOperation* root_search = [[DJDirectorySearchOperation alloc] init];
	[root_search setOwner:self];
	[root_search setStartURL:_root];
	[[self searchingQueue] addOperation:root_search];

	
	// Wait for all operations to finish.
	for (;;)
	{
		usleep(50000);
		BOOL finished_searching = [[[self searchingQueue] operations] count] == 0;
		
		if (finished_searching)
			[[self processingQueue] setSuspended:NO];
			
		progress_block([NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:_unprocessedImageCount], @"fileCount",
						[NSNumber numberWithInteger:[[self images] count]], @"completeCount",
						[NSNumber numberWithBool:finished_searching], @"searchComplete", nil]);
		
		if (finished_searching && [[[self processingQueue] operations] count] == 0)
			break;
	}
	
	[[self searchingQueue] waitUntilAllOperationsAreFinished];
	[[self processingQueue] waitUntilAllOperationsAreFinished];
}

- (void)addUnprocessedImage
{
	OSAtomicIncrement64Barrier(&_unprocessedImageCount);
}

@end

#pragma mark -

@implementation DJImageProcessingOperation

@synthesize imageURL, owner;

- (void)main
{
	NSAssert([self imageURL] != nil, @"%@ needs an image to work with.", [self class]);
	DJImageHash* imageHash = [[DJImageHash alloc] initWithImageURL:[self imageURL]];
	
	@synchronized ([[self owner] images])
	{
		[[[self owner] images] addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLongLong:[imageHash imageHash]], @"hash", [self imageURL], @"url", nil]];
	}
}

@end

#pragma mark -

@implementation DJDirectorySearchOperation

@synthesize startURL, owner;

- (void)main
{
	NSAssert([self startURL] != nil, @"%@ needs a starting URL.", [self class]);
	
	NSError* enumeration_error = NULL;
	NSArray* children = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self startURL] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles error:&enumeration_error];
	
	if (!children)
	{
		NSLog(@"%s: error: %@", __func__, enumeration_error);
		return;
	};
	
	for (NSURL *child in children)
	{
        NSNumber* is_directory = nil;
        [child getResourceValue:&is_directory forKey:NSURLIsDirectoryKey error:NULL];
		
		if ([is_directory boolValue])
		{
			// Queue a directory search for this subdirectory.
			DJDirectorySearchOperation* subdir_search = [[DJDirectorySearchOperation alloc] init];
			[subdir_search setOwner:[self owner]];
			[subdir_search setStartURL:child];
			[subdir_search setQueuePriority:NSOperationQueuePriorityHigh];
			[[[self owner] searchingQueue] addOperation:subdir_search];
		}
		else
		{
			// If this file is not an image, skip it.
			if (![[NSArray arrayWithObjects:@"jpg", @"jpeg", @"bmp", @"git", @"png", @"tif", @"tiff", @"jp2", nil] containsObject:[[child pathExtension] lowercaseString]])
			{
				//NSLog(@"Skipping non-image %@", child);
				continue;
			}

			// Queue a processing operation for this image.
			DJImageProcessingOperation* image_processor = [[DJImageProcessingOperation alloc] init];
			[image_processor setOwner:[self owner]];
			[image_processor setImageURL:child];
			[[[self owner] processingQueue] addOperation:image_processor];
			[[self owner] addUnprocessedImage];
		}
	}
}


@end