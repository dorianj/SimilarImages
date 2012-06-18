/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "SIImageView.h"

@interface SIDocument : NSDocument

// The root URL for this search
@property (readwrite, retain) NSURL* rootURL;

// Chooser for the search path
@property (readwrite, assign) IBOutlet NSPathControl* haystackPathControl;

// An image view that is used to pick the needle image.
@property (readwrite, assign) IBOutlet SIImageView* needleImagePicker;

// Thumbnail view used for image matches
@property (readwrite, assign) IBOutlet IKImageBrowserView* resultsImageBrowserView;

// Images returned from search.
@property (readwrite, retain) NSArray* matchingImages;


// For the trawling progress sheet
@property (readwrite, assign) IBOutlet NSWindow* trawlProgressWindow;
@property (readwrite, assign) IBOutlet NSTextField* trawlProgressImageCount;
@property (readwrite, assign) IBOutlet NSProgressIndicator* trawlProgressIndicator;


// Sent when a user drops an image onto the needle image picker.
- (IBAction)userDidDropImage:(id)sender;

@end
