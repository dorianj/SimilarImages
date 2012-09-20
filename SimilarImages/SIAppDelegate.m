/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
