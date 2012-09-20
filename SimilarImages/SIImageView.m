/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SIImageView.h"

@implementation SIImageView
@synthesize imageURL;

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	
	//if ([pboard 
	
	
	
	NSArray* objs = [pboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:nil];
	NSURL* draggedURL = [objs lastObject];
	/*
	if (draggedURL == nil)
	{
		for (id obj in [pboard propertyListForType:NSURLPboardType])
		{
			if (![obj isKindOfClass:[NSString class]] || ([obj length] == 0))
				continue;
			
			NSURL* url = [NSURL URLWithString:obj];
			
			if (url != nil)
			{
				draggedURL = url;
				break;
			}
		}
	}*/
	
	[self setImageURL:draggedURL];
	[super concludeDragOperation:sender];
}

@end
