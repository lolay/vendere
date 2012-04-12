//
//  Copyright 2012 Lolay, Inc. All rights reserved.
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

#import "LolaySKPaymentTransaction.h"

@implementation LolaySKPaymentTransaction

@synthesize transactionDate = transactionDate_;
@synthesize identifier = identifier_;
@synthesize receipt = receipt_;

- (id) initWithIdentifier:(NSString*) identifier receipt:(NSData*) receipt transactionDate:(NSDate*) transactionDate {
    self = [super init];
    if (self) {
        self.identifier = identifier;
        self.receipt = receipt;
        self.transactionDate = transactionDate;
    }
    return self;
}

+ (LolaySKPaymentTransaction*) transactionWithIdentifier:(NSString*) identifier receipt:(NSData*) receipt transactionDate:(NSDate*) transactionDate {
    return [[LolaySKPaymentTransaction alloc] initWithIdentifier:identifier receipt:receipt transactionDate:transactionDate];
}

@end
