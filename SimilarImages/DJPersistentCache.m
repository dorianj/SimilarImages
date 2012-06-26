/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "DJPersistentCache.h"

@interface DJPersistentCacheItem : NSObject <NSCoding>
	@property (readwrite, retain) id value;
	@property (readwrite, assign) NSTimeInterval lastAccessed;
@end


#pragma mark -

#define DJPersistentCacheLoadFactor 0.8

@interface DJPersistentCache ()
@property (readwrite, retain) NSMutableDictionary* cachedObjects;
@property (readwrite, retain) NSLock* cacheLock;
@end

#pragma mark -

@implementation DJPersistentCache

@synthesize cachedObjects, maxEntryCount, URL, cacheLock;

- (id)init
{
	return [self initWithURL:nil];
}

// Designated initializer.
- (id)initWithURL:(NSURL *)cacheURL
{
	if (!(self = [super init]))
		return nil;
	
	if (cacheURL != nil)
	{
		@try {
			[self setCachedObjects:[NSKeyedUnarchiver unarchiveObjectWithFile:[cacheURL path]]];	
			[self setURL:cacheURL];
		}
		@catch (NSException *exception) {
			NSLog(@"%s: unable to read cache file %@", __func__, cacheURL);
		}		
	}
	
	if ([self cachedObjects] == nil)
		[self setCachedObjects:[NSMutableDictionary dictionary]];
		
	[self setCacheLock:[[NSLock alloc] init]];
	return self;
}

- (void)writeToPersistentStore
{
	[self writeToURL:[self URL] error:NULL];
}

- (BOOL)writeToURL:(NSURL*)cacheURL error:(NSError**)error
{
	@try {
		[[self cacheLock] lock];
		[NSKeyedArchiver archiveRootObject:[self cachedObjects] toFile:[cacheURL path]];
	}
	@catch (NSException *exception)
	{
		NSLog(@"%s: error %@", __func__, [exception reason]);
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSURLErrorFailingURLErrorKey, cacheURL, nil]];
		return NO;
	}
	@finally {
		[[self cacheLock] unlock];
	}
		
	
	return YES;
}

- (NSInteger)count
{
	return (NSInteger)[[self cachedObjects] count];
}

- (id)objectForKey:(id)key
{
	[[self cacheLock] lock];
	DJPersistentCacheItem* item = [[self cachedObjects] objectForKey:key];
	
	if (!item)
	{
		[[self cacheLock] unlock];
		return nil;
	}
		
	[item setLastAccessed:[[NSDate date] timeIntervalSince1970]];
	[[self cacheLock] unlock];
	
	return [item value];
}

- (void)setObject:(id)obj forKey:(id)key
{
	[[self cacheLock] lock];
	
	if ([self cacheCleanNeeded])
		[self cleanCache];
	
	DJPersistentCacheItem* newItem = [[DJPersistentCacheItem alloc] init];
	[newItem setValue:obj];
	[newItem setLastAccessed:[[NSDate date] timeIntervalSince1970]];
	[[self cachedObjects] setObject:newItem forKey:key];
	
	[[self cacheLock] unlock];
}

- (void)removeAllObjects
{
	[[self cacheLock] lock];
	[[self cachedObjects] removeAllObjects];
	[[self cacheLock] unlock];
}

- (BOOL)cacheCleanNeeded
{
	return ([self maxEntryCount] > 0) && ((NSInteger)[[self cachedObjects] count] >= [self maxEntryCount]);
}

- (void)cleanCache
{	
	// Create a sorted representation of all objects.
	NSMutableArray* items = [NSMutableArray arrayWithCapacity:[[self cachedObjects] count]];
	
	for (id key in [[self cachedObjects] keyEnumerator])
		[items addObject:[NSArray arrayWithObjects:key, [NSNumber numberWithDouble:[[[self cachedObjects] objectForKey:key] lastAccessed]], nil]];
	
	[items sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [[obj1 objectAtIndex:1] compare:[obj2 objectAtIndex:1]];
	}];
	
	// Remove the top 15 items.
	for (NSInteger i = 0, l = MIN((NSInteger)[items count], (NSInteger)([self maxEntryCount] * (1.0 - DJPersistentCacheLoadFactor))); i < l; i++)
		[[self cachedObjects] removeObjectForKey:[[items objectAtIndex:(NSUInteger)i] objectAtIndex:0]];	
}


@end

#pragma mark -

@implementation DJPersistentCacheItem

@synthesize value, lastAccessed;

- (id)initWithCoder:(NSCoder *)decoder
{
	if (!(self = [self init]))
		return nil;
	
	[self setValue:[decoder decodeObjectForKey:@"v"]];
	[self setLastAccessed:[decoder decodeDoubleForKey:@"d"]];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[self value] forKey:@"v"];
	[encoder encodeDouble:[self lastAccessed] forKey:@"d"];
}

@end