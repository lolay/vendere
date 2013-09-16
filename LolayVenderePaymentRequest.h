//
//  Copyright 2012, 2013 Lolay, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

@interface LolayVenderePaymentRequest : NSObject

- (id) init;

/**
 *  Returns array of SKPaymentTransaction. When making a payment, it can be likely to get more than the original purchase back.
 */
- (NSSet*) makePaymentForProduct:(NSString*) productIdentifier error:(NSError**) error;
+ (NSSet*) makePaymentForProduct:(NSString*) productIdentifier error:(NSError**) error;
- (NSSet*) makePaymentForProduct:(NSString*) productIdentifier timeout:(NSTimeInterval) timeout error:(NSError**) error;
+ (NSSet*) makePaymentForProduct:(NSString*) productIdentifier timeout:(NSTimeInterval) timeout error:(NSError**) error;
- (NSSet*) restorePaymentsWithError:(NSError**) error;
+ (NSSet*) restorePaymentsWithError:(NSError**) error;
- (NSSet*) restorePaymentsWithTimeout:(NSTimeInterval) timeout error:(NSError**) error;
+ (NSSet*) restorePaymentsWithTimeout:(NSTimeInterval) timeout error:(NSError**) error;

@end
