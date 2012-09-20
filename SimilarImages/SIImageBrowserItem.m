/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SIImageBrowserItem.h"
#import <Quartz/Quartz.h>

@implementation SIImageBrowserItem
@synthesize imageURL;

- (NSString*)imageUID
{
	return [[self imageURL] absoluteString];
}

- (NSString*)imageRepresentationType
{
	return IKImageBrowserNSURLRepresentationType;
}

- (id)imageRepresentation
{
	return [self imageURL];
}

- (NSString*)imageTitle
{
	return [[self imageURL] lastPathComponent];
}

- (NSString*)imageSubtitle
{
	return [[self imageURL] path];
}

- (BOOL)isEqual:(id)object
{
	if ([object respondsToSelector:@selector(imageUID)])
		return [[self imageUID] isEqual:[object imageUID]];
	
	return NO;
}

@end
