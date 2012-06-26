/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIAppDelegate.h"

// To clear the hash cache: 
#import "DJImageTrawler.h"
#import "DJPersistentCache.h"

@implementation SIAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	
	// NSUserDefaults defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SIDefaults" ofType:@"plist"]]];
}



- (IBAction)clearHashCache:(id)sender
{
	[[DJImageTrawler hashCache] removeAllObjects];
	[[DJImageTrawler hashCache] writeToPersistentStore];
	
	NSRunAlertPanel(@"The image cache is now empty.", @"This usually shouldn't be necessary: image changes are automatically detected, and the cache uses a very small amount of disk space.", @"OK", @"", @"");
}

@end
