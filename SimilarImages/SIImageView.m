/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIImageView.h"

@implementation SIImageView
@synthesize imageURL;
- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	NSArray* objs = [pboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:nil];
	// xxx: when dragged from chrome here, objs contains "NSURLPboardType" but doesn't readObjectsForClasses pick it up. might have to use NSData?
	[self setImageURL:[objs lastObject]];
	[super concludeDragOperation:sender];
}

@end
