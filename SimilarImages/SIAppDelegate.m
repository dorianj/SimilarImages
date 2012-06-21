/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIAppDelegate.h"

@implementation SIAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	
	// NSUserDefaults defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SIDefaults" ofType:@"plist"]]];
}

@end
