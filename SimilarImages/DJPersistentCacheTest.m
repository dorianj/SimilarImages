/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "DJPersistentCacheTest.h"

#import "DJPersistentCache.h"

@implementation DJPersistentCacheTest


- (void)testCleaner
{
	NSInteger maxCacheSize = 1000;
	DJPersistentCache* cache = [[DJPersistentCache alloc] init];
	[cache setMaxEntryCount:maxCacheSize];
	
	for (NSInteger i = 0; i < 10000; i++)
	{
		@autoreleasepool {
			NSNumber* n = [NSNumber numberWithInteger:i];
			[cache setObject:n forKey:n];
		}
	}
	
	STAssertTrue([cache count] <= maxCacheSize, @"%s: cache count should be less than max value %d, but is %d", __func__, maxCacheSize, [cache count]);
}

@end
