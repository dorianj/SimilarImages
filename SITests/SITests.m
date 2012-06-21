/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import "SITests.h"

@implementation SITests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}


#import "DJImageHash.h"

- (void)testImageHash
{
	image_hash_t hash1 = 0xABC012348765FED9; // ABC0 1234 8765 FED9;
	image_hash_t expect, actual;
	
	actual = DJImageHashVerticalFlip(hash1);
	expect = 0xd9fe65873412c0ab;
	STAssertTrue(actual == expect, @"DJImageHashHorizontalFlip gave 0x%llx, expected 0x%llx.", actual, expect);
	
	
	actual = DJImageHashHorizontalFlip(0xaa99aa9990bb90bb);
	expect = 0x5599559909dd09dd;
	STAssertTrue(actual == expect, @"DJImageHashHorizontalFlip gave 0x%llx, expected 0x%llx.", actual, expect);
}

@end
 