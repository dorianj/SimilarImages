/* Copyright (C) 2012 Dorian Johnson <2012@dorianj.net>
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@interface NSString (DJHashingAdditions)
- (NSString *)sha1Digest;
@end

NSString* DJHexadecimalStringFromBytes(const unsigned char* data, NSUInteger dataLength);
