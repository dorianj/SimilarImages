/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SIDocument.h"
#import "SIImageBrowserItem.h"

#import "DJImageTrawler.h"
#import "DJImageHash.h"

#define HAMMING_DISTANCE(A,B)	({ unsigned long long __BD = (A) ^ (B); __builtin_popcountll(__BD); })

#define TRACE_FUNC() NSLog(@"%s", __func__)

@interface SIDocument ()

@property (readwrite, retain) NSArray* observedKeys;

// An array of all found images.
@property (readwrite, retain) NSArray* images;

@end


@implementation SIDocument

// Public properties.
@synthesize needleImagePicker, matchingImages, resultsImageBrowserView, rootURL, haystackPathControl;

// Private properties.
@synthesize images, observedKeys;



- (id)init
{
    if ((self = [super init]) == nil)
		return nil;
	
	[self setObservedKeys:[NSArray arrayWithObjects:
						   @"matchingImages", // Observe matching images in order to update the browser when the results change
						   @"rootURL",        // Observe changes to rootURL so we can re-scan.
						   nil]];
	
	for (NSString* keyPath in [self observedKeys])
		[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
						   
    return self;
}

- (void)dealloc
{
	for (NSString* keyPath in [self observedKeys])
		[self removeObserver:self forKeyPath:keyPath];
}

- (void)awakeFromNib
{
	// Configure the results image browser
	[[self resultsImageBrowserView] setCanControlQuickLookPanel:YES];
	[[self resultsImageBrowserView] setCellsStyleMask:(IKCellsStyleNone | IKCellsStyleShadowed | IKCellsStyleTitled /*| IKCellsStyleSubtitled*/)];
	
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		[self runRootDirChooserSheet:nil];
	}];
}

- (IBAction)runRootDirChooserSheet:(id)sender
{	
	NSOpenPanel* open_panel = [NSOpenPanel openPanel];
	[open_panel setCanChooseDirectories:YES];
	[open_panel setCanChooseFiles:NO];
	
	if ([sender respondsToSelector:@selector(clickedPathComponentCell)])
		[open_panel setDirectoryURL:[[sender clickedPathComponentCell] URL]];;
	
	[open_panel beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSInteger result) {
		if (result != NSOKButton)
		{
			if ([self rootURL] == nil)
			{	
				// Didnt' have a root URL previously; showing the window now would leave it unusable.
				[self close];
			}
			
			return;
		}
		
		[self setRootURL:[open_panel URL]];
	}];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"matchingImages"])
		[[self resultsImageBrowserView] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
	else if ([keyPath isEqualToString:@"rootURL"])
	{
		if ([self rootURL] != nil)
		{
			NSString* windowTitle = [[self rootURL] lastPathComponent];
			[self setDisplayName:windowTitle];
			[[self windowForSheet] setTitle:windowTitle];
			[[self rootURL] startAccessingSecurityScopedResource];
			[self performSelectorOnMainThread:@selector(trawlRootURL) withObject:nil waitUntilDone:NO];
		}
	}
}


#pragma mark -
#pragma mark Managing the trawl progress sheet

@synthesize trawlProgressWindow, trawlProgressIndicator, trawlProgressImageCount;

- (void)showTrawlProgressSheet
{
	[[NSApplication sharedApplication] beginSheet:[self trawlProgressWindow] modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	[[self trawlProgressIndicator] startAnimation:self];
}

- (void)hideTrawlProgressSheet
{
	[[NSApplication sharedApplication] endSheet:[self trawlProgressWindow]];
}

- (void)updateTrawlProgressSheet:(NSDictionary*)trawl_info
{
	if ([[trawl_info objectForKey:@"searchComplete"] boolValue])
	{
		if ([[self trawlProgressIndicator] isIndeterminate])
		{
			[[self trawlProgressIndicator] setIndeterminate:NO];
			[[self trawlProgressIndicator] setMinValue:0];
		}
		
		[[self trawlProgressIndicator] setMaxValue:[[trawl_info objectForKey:@"fileCount"] doubleValue]];
		[[self trawlProgressIndicator] setDoubleValue:[[trawl_info objectForKey:@"completeCount"] doubleValue]];
		[[self trawlProgressIndicator] displayIfNeeded];
	}
	else
	{
		if (![[self trawlProgressIndicator] isIndeterminate])
		{
			[[self trawlProgressIndicator] setIndeterminate:YES];
		}
	}
	
	[[self trawlProgressImageCount] setStringValue:[NSString stringWithFormat:@"%ld / %ld", [[trawl_info objectForKey:@"completeCount"] integerValue], [[trawl_info objectForKey:@"fileCount"] integerValue]]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet close];
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
	if (![typeName isEqualToString:@"SimilarImagesSearch"])
	{
		NSLog(@"%s doesn't support data of type %@", __func__, typeName);
		return nil;
	}
	TRACE_FUNC();
	// Pack up the root URL in a secure bookmark.
	NSError* error;
	NSData* rootURLData = [[self rootURL] bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
	
	if (rootURLData == nil)
	{
		NSLog(@"%s: Error saving: couldn't create data of rootURL. %@", __func__, error);
		return nil;
	}

	NSMutableDictionary* searchInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											//   [self images], @"images",
											   rootURLData, @"rootURL",
											   nil];

	//return [NSPropertyListSerialization dataWithPropertyList:archivedSearchInfo format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListImmutable error:NULL];
	return [NSKeyedArchiver archivedDataWithRootObject:searchInfo];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if (![typeName isEqualToString:@"SimilarImagesSearch"])
	{
		NSLog(@"%s doesn't support data of type %@", __func__, typeName);
		return NO;
	}
TRACE_FUNC();
	NSDictionary* searchInfo = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	NSError* error;
	BOOL bookmarkIsStale;
	NSURL* newRootURL = [NSURL URLByResolvingBookmarkData:[searchInfo objectForKey:@"rootURL"] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:&error];
	
	if (newRootURL == nil)
	{
		NSLog(@"%s: Error loading: couldn't create URL from data. %@", __func__, error);
		return NO;
	}
	
	[self setRootURL:newRootURL];
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
		int dist = HAMMING_DISTANCE([[item objectForKey:@"hash"] unsignedIntegerValue], needle);
		
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
#pragma mark Working with the search results

- (NSArray*)selectedResultImageURLs
{
	NSIndexSet* selectedIndices = [[self resultsImageBrowserView] selectionIndexes];
	
	if ([selectedIndices count] == 0)
		return nil;
	
	NSMutableArray* selectedURLs = [NSMutableArray array];
	
	[selectedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[selectedURLs addObject:[[[[self matchingImages] objectAtIndex:idx] objectForKey:@"bitem"] imageURL]];
	}];

	return selectedURLs;
}

- (IBAction)revealSearchResultInFinder:(id)sender
{
	if ([self selectedResultImageURLs])
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[self selectedResultImageURLs]];
}

- (IBAction)openSearchResultWithDefaultApp:(id)sender
{
	//[[NSWorkspace sharedWorkspace] openURL:[[self selectedResultImageURLs] lastObject]];
	[[NSWorkspace sharedWorkspace] openURLs:[self selectedResultImageURLs] withAppBundleIdentifier:@"com.apple.preview" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:NULL];
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
