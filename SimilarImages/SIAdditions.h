/*	Copyright 2012 Dorian Johnson <2012@dorianj.net>
 */

#import <Foundation/Foundation.h>

@interface NSString (DJHashingAdditions)
- (NSString *)sha1Digest;
@end

NSString* DJHexadecimalStringFromBytes(const unsigned char* data, NSUInteger dataLength);
