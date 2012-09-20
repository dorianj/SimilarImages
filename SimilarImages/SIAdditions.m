/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/* Copyright 2007-2009 Dorian Johnson; created 2007-06-10 (DJHexadecimalStringFromBytes, sha1Digest) */


#import "SIAdditions.h"
#import <CommonCrypto/CommonDigest.h>

NSString* DJHexadecimalStringFromBytes(const unsigned char* data, NSUInteger dataLength)
{
	static unsigned char hexDigits[] = "0123456789abcdef";
	unsigned char* output = malloc(dataLength*2+1);
	
	for (NSUInteger i = 0; i < dataLength; i++)
	{			
		output[2*i]   = hexDigits[data[i] >> 4];	
		output[2*i+1] = hexDigits[data[i] & 0x0f];
	}	
	
	output[dataLength] = '\0';
	
	NSString *finishedString = [NSString stringWithCString:(const char *)output encoding:NSASCIIStringEncoding];
	free(output);
	return finishedString;
}


@implementation NSString (DJHashingAdditions)

- (NSString *)sha1Digest
{
	unsigned char hashedChars[20];
	CC_SHA1([self UTF8String], (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], hashedChars);
	return DJHexadecimalStringFromBytes(hashedChars, 20);
}


@end

