/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class SIImageView;

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

// Runs the search dir chooser and re-scans
- (IBAction)runRootDirChooserSheet:(id)sender;

// Actions on search results
- (IBAction)revealSearchResultInFinder:(id)sender;
- (IBAction)openSearchResultWithDefaultApp:(id)sender;
@end
