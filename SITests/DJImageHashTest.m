//
//  DJImageHashTest.m
//  SimilarImages
//
//  Created by Dorian Johnson on 2012/6/25.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DJImageHashTest.h"

#import "DJImageHash.h"

@implementation DJImageHashTest

- (void)testActualImageTransforms
{
	DJImageHash* original = [self hashForTestFile:@"group1/bikes.jpg"];
	DJImageHash* original_90deg = [self hashForTestFile:@"group1/bikes 90deg.jpg"];
	DJImageHash* original_180deg = [self hashForTestFile:@"group1/bikes 180deg.jpg"];
	DJImageHash* original_270deg = [self hashForTestFile:@"group1/bikes 270deg.jpg"];
	DJImageHash* original_vert = [self hashForTestFile:@"group1/bikes vert.jpg"];
	DJImageHash* original_horiz = [self hashForTestFile:@"group1/bikes horiz.jpg"];
	NSNumber* similarity;
	NSNumber* expected_similarity = [NSNumber numberWithFloat:90];
	
	STAssertTrue(original && original_90deg && original_180deg && original_270deg && original_vert && original_horiz, @"Not all test images were found.");


//	STAssertTrue([[original similarityTo:original considerTransforms:NO] compare:expected_similarity] == NSOrderedDescending, @"similarityTo: must 100 for identical inputs.");

	similarity = [original similarityTo:original_90deg considerTransforms:YES];
	STAssertTrue([similarity compare:expected_similarity] == NSOrderedDescending, @"DJImageHashRotate 90deg: similarity should be > %@, but was %@", expected_similarity, similarity);

	similarity = [original similarityTo:original_180deg considerTransforms:YES];
	STAssertTrue([similarity compare:expected_similarity] == NSOrderedDescending, @"DJImageHashRotate 180deg: similarity should be > %@, but was %@", expected_similarity, similarity);
	
	similarity = [original similarityTo:original_270deg considerTransforms:YES];
	STAssertTrue([similarity compare:expected_similarity] == NSOrderedDescending, @"DJImageHashRotate 270deg: similarity should be > %@, but was %@", expected_similarity, similarity);	

	similarity = [original similarityTo:original_vert considerTransforms:YES];
	STAssertTrue([similarity compare:expected_similarity] == NSOrderedDescending, @"DJImageHashVerticalFlip: similarity should be > %@, but was %@", expected_similarity, similarity);

	similarity = [original similarityTo:original_horiz considerTransforms:YES];
	STAssertTrue([similarity compare:expected_similarity] == NSOrderedDescending, @"DJImageHashHorizontalFlip: similarity should be > %@, but was %@", expected_similarity, similarity);
}

- (DJImageHash*)hashForTestFile:(NSString*)path
{
	return [[DJImageHash alloc] initWithURL:[NSURL fileURLWithPath:[[NSString stringWithFormat:@"~/dev/SimilarImages/Support/test_images/%@", path] stringByExpandingTildeInPath]]];
}


@end
