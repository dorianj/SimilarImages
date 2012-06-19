/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
*/

#import "DJImageTrawler.h"
#import "DJImageHash.h"
#import "DJPersistentCache.h"

#import "SIAdditions.h"

@interface DJImageTrawler ()

@property (readwrite) NSOperationQueue* processingQueue, * searchingQueue;
@property (readwrite) NSMutableArray* images;

@property (readwrite) DJPersistentCache* hashCache;

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
	@property NSDictionary* imageFileProperties;
@end


#pragma mark -

@implementation DJImageTrawler

@synthesize searchingQueue, processingQueue, hashCache, images;

- (id)initWithURL:(NSURL*)root_directory
{
	if (!(self = [super init]))
		return nil;
	
	// Create a persistent cache for storing image hashes
	NSURL* cacheURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];

	if (cacheURL != nil)
	{
		NSURL* hashCacheURL = [cacheURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-hashCache.dat", [self class]]];
		NSLog(@"%@", hashCacheURL);
		[self setHashCache:[[DJPersistentCache alloc] initWithURL:hashCacheURL]];
	}
		
	// Create the operation queues for this instance.
	[self setProcessingQueue:[[NSOperationQueue alloc] init]];
	[self setSearchingQueue:[[NSOperationQueue alloc] init]];
	[[self processingQueue] setSuspended:YES];
	[[self searchingQueue] setMaxConcurrentOperationCount:4];
	[self setImages:[NSMutableArray array]];
	_root = root_directory;
	return self;
}

- (void)trawlImagesWithProgressBlock:(void(^)(NSDictionary*))progress_block
{
	// Add the first operation, a search on the root directory.
	NSDate* start = [NSDate date];
	DJDirectorySearchOperation* root_search = [[DJDirectorySearchOperation alloc] init];
	[root_search setOwner:self];
	[root_search setStartURL:_root];
	[[self searchingQueue] addOperation:root_search];

	
	// Wait for all operations to finish.
	for (;;)
	{
		usleep(150000);
		BOOL finished_searching = [[[self searchingQueue] operations] count] == 0;
		
		if (finished_searching)
			[[self processingQueue] setSuspended:NO];
			
		progress_block([NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:_unprocessedImageCount], @"fileCount",
						[NSNumber numberWithInteger:_processedImageCount], @"completeCount",
						[NSNumber numberWithBool:finished_searching], @"searchComplete", nil]);
		
		if (finished_searching && [[[self processingQueue] operations] count] == 0)
			break;
	}
	
	[[self searchingQueue] waitUntilAllOperationsAreFinished];
	[[self processingQueue] waitUntilAllOperationsAreFinished];
	
	NSLog(@"Trawl took %f seconds.", [[NSDate date] timeIntervalSinceDate:start]);
	
	[[self hashCache] performSelectorInBackground:@selector(writeToPersistentStore) withObject:nil];
}

- (void)addUnprocessedImage
{
	OSAtomicIncrement64Barrier(&_unprocessedImageCount);
}

- (void)addProcessedImage
{
	OSAtomicIncrement64Barrier(&_processedImageCount);
}

@end

#pragma mark -

@implementation DJImageProcessingOperation

@synthesize imageURL, imageFileProperties, owner;

- (void)main
{
	NSAssert([self imageURL] != nil, @"%@ needs an image to work with.", [self class]);
	
	NSMutableDictionary* newImageItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:[self imageURL], @"url", nil];
	
	
	NSString* cacheKey = [[NSString stringWithFormat:@"%@%@%@-%d-1", [[self imageURL] path], [[self imageFileProperties] objectForKey:NSURLContentModificationDateKey], [[self imageFileProperties] objectForKey:NSURLFileSizeKey], [DJImageHash hashVersion]] sha1Digest];
	
	NSNumber* hash = [[[self owner] hashCache] objectForKey:cacheKey];
	
	if (!hash)
	{
		NSLog(@"dont have cached item for %@", cacheKey);
		DJImageHash* imageHasher = [[DJImageHash alloc] initWithImageURL:[self imageURL]];
		hash = [NSNumber numberWithUnsignedLongLong:[imageHasher imageHash]];
		
		if ([hash unsignedLongLongValue] == 0)
		{
			NSLog(@"unable to hash %@", [self imageURL]);
			return;
		}
		
		[[[self owner] hashCache] setObject:hash forKey:cacheKey];
	}
	
	[newImageItem setObject:hash forKey:@"hash"];
	
	[[self owner] addProcessedImage];
	
	@synchronized ([[self owner] images])
	{
		[[[self owner] images] addObject:newImageItem];
	}
}

@end

#pragma mark -

@implementation DJDirectorySearchOperation

@synthesize startURL, owner;

+ (NSArray*)imageFileExtensions
{
	static NSArray* _extensions = nil;
	
	if (_extensions == nil)
		_extensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"bmp", @"git", @"png", @"tif", @"tiff", @"jp2", nil];
	
	return _extensions;
}

- (void)main
{
	NSAssert([self startURL] != nil, @"%@ needs a starting URL.", [self class]);
	
	NSError* enumeration_error = NULL;
	NSArray* children = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self startURL] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLFileSizeKey, nil] options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants) error:&enumeration_error];
	
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
			if (![[DJDirectorySearchOperation imageFileExtensions] containsObject:[[child pathExtension] lowercaseString]])
			{
				//NSLog(@"Skipping non-image %@", child);
				continue;
			}
			
			// Queue a processing operation for this image.
			DJImageProcessingOperation* image_processor = [[DJImageProcessingOperation alloc] init];
			[image_processor setOwner:[self owner]];
			[image_processor setImageURL:child];
			[image_processor setImageFileProperties:[child resourceValuesForKeys:[NSArray arrayWithObjects:NSURLContentModificationDateKey, NSURLFileSizeKey, nil] error:NULL]];
			[[[self owner] processingQueue] addOperation:image_processor];
			[[self owner] addUnprocessedImage];
		}
	}
}


@end