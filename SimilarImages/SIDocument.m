/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIDocument.h"
#import "SIImageBrowserItem.h"

#import "DJImageTrawler.h"
#import "DJImageHash.h"

#define HAMMING_DISTANCE(A,B)	({ unsigned long long __BD = (A) ^ (B); __builtin_popcountll(__BD); })


@interface SIDocument ()


// An array of all found images.
@property (readwrite, retain) NSArray* images;

@end


@implementation SIDocument

// Public properties.
@synthesize needleImagePicker, matchingImages, resultsImageBrowserView, rootURL, haystackPathControl;

// Private properties.
@synthesize images;



- (id)init
{
    if ((self = [super init]) == nil)
		return nil;
	
	// Observe matching images in order to update the browser when the results change
	[self addObserver:self forKeyPath:@"matchingImages" options:NSKeyValueObservingOptionNew context:NULL];
	
	// Observe changes to rootURL so we can re-scan.
	[self addObserver:self forKeyPath:@"rootURL" options:NSKeyValueObservingOptionNew context:NULL];


//	[self performSelectorInBackground:@selector(trawlTestLibrary) withObject:nil];
    return self;
}

- (void)awakeFromNib
{
	// Configure the results image browser
	[[self resultsImageBrowserView] setCanControlQuickLookPanel:YES];
	[[self resultsImageBrowserView] setCellsStyleMask:(IKCellsStyleNone | IKCellsStyleShadowed | IKCellsStyleTitled | IKCellsStyleSubtitled)];
	
	
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		NSOpenPanel* open_panel = [NSOpenPanel openPanel];
		[open_panel setCanChooseDirectories:YES];
		[open_panel setCanChooseFiles:NO];
		
		[open_panel beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSInteger result) {
			if (result != NSOKButton)
				[self close];
			
			[self setRootURL:[open_panel URL]];
		}];
	}];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"matchingImages"])
		[[self resultsImageBrowserView] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
	else if ([keyPath isEqualToString:@"rootURL"])
		[self performSelectorOnMainThread:@selector(trawlRootURL) withObject:nil waitUntilDone:NO];
}


#pragma mark -
#pragma mark Managing the trawl progress sheet

@synthesize trawlProgressWindow, trawlProgressIndicator, trawlProgressImageCount;

- (void)showTrawlProgressSheet
{
	[[NSApplication sharedApplication] beginSheet:[self trawlProgressWindow] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)hideTrawlProgressSheet
{
	[[NSApplication sharedApplication] endSheet:[self trawlProgressWindow]];
}

- (void)updateTrawlProgressSheet:(NSDictionary*)trawl_info
{
	if ([[trawl_info objectForKey:@"searchComplete"] boolValue])
	{
		[[self trawlProgressIndicator] setIndeterminate:NO];
		[[self trawlProgressIndicator] setMinValue:0];
		[[self trawlProgressIndicator] setMaxValue:[[trawl_info objectForKey:@"fileCount"] floatValue]];
		[[self trawlProgressIndicator] setDoubleValue:[[trawl_info objectForKey:@"completeCount"] floatValue]];
	}
	else {
		[[self trawlProgressIndicator] setIndeterminate:YES];
	}
	
	[[self trawlProgressImageCount] setStringValue:[NSString stringWithFormat:@"%ld / %ld", [[trawl_info objectForKey:@"completeCount"] integerValue], [[trawl_info objectForKey:@"fileCount"] integerValue]]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet close];
}



#pragma mark -
#pragma mark Testing routines (static library)

- (void)trawlTestLibrary
{
	NSString* path = @"~/ShortTerm/test_image_library";
	//path = @"/Volumes/AR";
	[self setRootURL:[NSURL fileURLWithPath:[path stringByExpandingTildeInPath]]];
}

- (void)searchTestLibrary
{
	[self setMatchingImages:[self findImagesVisuallySimilarToImage:[NSURL fileURLWithPath:[@"~/ShortTerm/test_image_library/LIVEJPEG/carnivaldolls.bmp" stringByExpandingTildeInPath]]]];
}


#pragma mark -
#pragma mark NSDocument

- (NSString *)windowNibName
{
	return @"SIDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	[super windowControllerDidLoadNib:aController];
	// Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
	@throw exception;
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
	@throw exception;
	return YES;
}


#pragma mark -
#pragma mark Searching directories for images

- (void)trawlRootURL
{
	[self showTrawlProgressSheet];
	
	[[NSOperationQueue new] addOperationWithBlock:^{
		[self setImages:[self trawlImagesInURL:[self rootURL]]];
		[self performSelectorOnMainThread:@selector(hideTrawlProgressSheet) withObject:nil waitUntilDone:NO];
	}];
}

- (NSArray*)trawlImagesInURL:(NSURL*)root_url
{
	DJImageTrawler* trawler = [[DJImageTrawler alloc] initWithURL:root_url];
	[trawler trawlImagesWithProgressBlock:^(NSDictionary* progress_info) {
		[self performSelectorOnMainThread:@selector(updateTrawlProgressSheet:) withObject:progress_info waitUntilDone:NO];
	}];
	return [trawler images];
}


#pragma mark -
#pragma mark Finding visually similar images (after trawling)

- (NSArray*)findImagesVisuallySimilarToImage:(NSURL*)imageURL
{
	NSMutableArray* matches = [NSMutableArray array];
	DJImageHash* hash = [[DJImageHash alloc] initWithImageURL:imageURL];
	NSUInteger needle = [hash imageHash];
	
	[[self images] enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSDictionary* item = obj;
		
		// Don't match the needle image.
		if ([[item objectForKey:@"url"] isEqual:imageURL])
			return;
		
		// Do a hamming distance between the needle and this image.
		unsigned int dist = HAMMING_DISTANCE([[item objectForKey:@"hash"] unsignedIntegerValue], needle);
		
		if (dist > 5)
			return;
		
		// This image is a match: create a browser item for it and add to the matches builder array.
		SIImageBrowserItem* browser_item = [[SIImageBrowserItem alloc] init];
		[browser_item setImageURL:[item objectForKey:@"url"]];
		
		@synchronized (matches)
		{
			[matches addObject:[NSDictionary dictionaryWithObjectsAndKeys:browser_item, @"bitem", nil]];
		}
	}];
	
	return matches;
}

- (IBAction)userDidDropImage:(id)sender
{
	[self setMatchingImages:[self findImagesVisuallySimilarToImage:[[self needleImagePicker] imageURL]]];	
}

#pragma mark - 
#pragma mark Working with the image browser (IKImageBrowserViewDataSource)

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView*)browser;
{
	return [[self matchingImages] count];
}

- (id)imageBrowser:(IKImageBrowserView *)browser itemAtIndex:(NSUInteger)index;
{
	return [[[self matchingImages] objectAtIndex:index] objectForKey:@"bitem"];
}


@end
