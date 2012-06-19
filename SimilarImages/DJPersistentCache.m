/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "DJPersistentCache.h"

@interface DJPersistentCacheItem : NSObject <NSCoding>
	@property (readwrite, retain) id value;
	@property (readwrite, assign) NSTimeInterval lastAccessed;
@end


#pragma mark -

@interface DJPersistentCache ()
@property (readwrite, retain) NSMutableDictionary* cachedObjects;
@end

#pragma mark -

@implementation DJPersistentCache

@synthesize cachedObjects, maxEntryCount, URL;

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
		
	return self;
}

- (void)writeToPersistentStore
{
	[self writeToURL:[self URL] error:NULL];
}

- (BOOL)writeToURL:(NSURL*)cacheURL error:(NSError**)error
{
	@try {
		[NSKeyedArchiver archiveRootObject:[self cachedObjects] toFile:[cacheURL path]];
	}
	@catch (NSException *exception)
	{
		NSLog(@"%s: error %@", __func__, [exception reason]);
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSURLErrorFailingURLErrorKey, cacheURL, nil]];
		return NO;
	}
	
	return YES;
}


- (id)objectForKey:(id)key
{
	DJPersistentCacheItem* item = [[self cachedObjects] objectForKey:key];
	
	if (!item)
		return nil;
		
	[item setLastAccessed:[[NSDate date] timeIntervalSince1970]];
	return [item value];
}

- (void)setObject:(id)obj forKey:(id)key
{
	[self cleanCacheIfNeeded];
	
	DJPersistentCacheItem* newItem = [[DJPersistentCacheItem alloc] init];
	[newItem setValue:obj];
	[newItem setLastAccessed:[[NSDate date] timeIntervalSince1970]];
	[[self cachedObjects] setObject:newItem forKey:key];
}



- (void)cleanCacheIfNeeded
{
	if ( ([self maxEntryCount] == 0) || ([[self cachedObjects] count] < [self maxEntryCount]) )
		return;
		
	NSLog(@"%s: cleaning cache", __func__);
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