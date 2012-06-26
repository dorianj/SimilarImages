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



- (void)testRotationNumerically
{
	
	image_hash_t original;
	image_hash_t expected_hash90;
	image_hash_t expected_hash180;
	image_hash_t expected_hash270;
	image_hash_t actual_hash;
	
	
	original = 0x8080808080808080ULL;
	expected_hash90 = 0xFF00000000000000ULL;
	actual_hash = DJImageHashRotate(original, 90);
	STAssertTrue(actual_hash == expected_hash90, @"Rotate 90: expected %llx, got %llx", expected_hash90, actual_hash);
	
	original = 0x9999999999999999ULL;
	expected_hash90 = 0xFF0000FFFF0000FFULL;
	actual_hash = DJImageHashRotate(original, 90);
	STAssertTrue(actual_hash == expected_hash90, @"Rotate 90: expected %llx, got %llx", expected_hash90, actual_hash);
	
	original = 0x1c0fb305a805ec2aULL;
	actual_hash = DJImageHashRotate(DJImageHashRotate(DJImageHashRotate(DJImageHashRotate(original, 90), 90), 90), 90);
	STAssertTrue(original == actual_hash, @"Rotate 90x4 == original: expected %llx, got %llx", original, actual_hash);
}


- (void)testActualImageTransforms
{
	image_hash_t original = [self hashForTestFile:@"group1/bikes.jpg"];
	image_hash_t original_90deg = [self hashForTestFile:@"group1/bikes 90deg.jpg"];
	image_hash_t original_180deg = [self hashForTestFile:@"group1/bikes 180deg.jpg"];
	image_hash_t original_270deg = [self hashForTestFile:@"group1/bikes 270deg.jpg"];
	image_hash_t original_vert = [self hashForTestFile:@"group1/bikes vert.jpg"];
	image_hash_t original_horiz = [self hashForTestFile:@"group1/bikes horiz.jpg"];
	image_hash_t actual_hash;
	NSInteger actual_distance = 0;
	
	
	STAssertTrue(original && original_90deg && original_180deg && original_270deg && original_vert && original_horiz, @"Not all test images were found.");


	STAssertTrue(DJImageHashCompare(original, original) == 0, @"DJImageHashCompare must return 0 for identical inputs!");

	actual_hash =  DJImageHashRotate(original, 90);
	actual_distance = DJImageHashCompare(original_90deg, actual_hash);
	STAssertTrue(actual_distance < 2, @"DJImageHashRotate 90deg: distance should be <2, but was %d", actual_distance);

	actual_distance = DJImageHashCompare(original_180deg, DJImageHashRotate(original, 180));
	STAssertTrue(actual_distance < 2, @"DJImageHashRotate 180deg: distance should be <2, but was %d", actual_distance);
	
	actual_distance = DJImageHashCompare(original_270deg, DJImageHashRotate(original, 270));
	STAssertTrue(actual_distance < 2, @"DJImageHashRotate 270deg: distance should be <2, but was %d", actual_distance);	

	actual_distance = DJImageHashCompare(original_vert, DJImageHashVerticalFlip(original));
	STAssertTrue(actual_distance < 2, @"DJImageHashVerticalFlip: distance should be <2, but was %d", actual_distance);

	actual_distance = DJImageHashCompare(original_horiz, DJImageHashHorizontalFlip(original));
	STAssertTrue(actual_distance < 2, @"DJImageHashHorizontalFlip: distance should be <2, but was %d", actual_distance);
}

- (image_hash_t)hashForTestFile:(NSString*)path
{
	
	return DJImageHashFromURL([NSURL fileURLWithPath:[[NSString stringWithFormat:@"~/dev/SimilarImages/Support/test_images/%@", path] stringByExpandingTildeInPath]]);
}


@end
