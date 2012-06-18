/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIImageView.h"

@implementation SIImageView
@synthesize imageURL;
- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	NSArray* objs = [pboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:nil];
	[self setImageURL:[objs lastObject]];
	[super concludeDragOperation:sender];
}

@end
