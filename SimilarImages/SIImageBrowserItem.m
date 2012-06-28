/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

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
		return [[self imageURL] isEqual:[object imageUID]];
	
	return NO;
}

@end
