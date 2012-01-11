//
//  Created by Lolay, Inc.
//  Copyright 2012 Lolay, Inc. All rights reserved.
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
