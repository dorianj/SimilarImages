/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

    
/*
	A class to efficiently deep-search a directory and generate info for all images.
 */

#import <Foundation/Foundation.h>
@class DJPersistentCache;
@interface DJImageTrawler : NSObject {

@private
	NSURL* _root;
	volatile int64_t _unprocessedImageCount, _processedImageCount;
}

@property (readonly) NSOperationQueue* processingQueue, * searchingQueue;
@property (readonly) NSMutableArray* images;

- (id)initWithURL:(NSURL*)root_directory;
- (void)trawlImagesWithProgressBlock:(void(^)(NSDictionary*))block;
- (void)addUnprocessedImage;

+ (DJPersistentCache*)hashCache;
@end
