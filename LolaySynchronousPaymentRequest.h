//
//  Created by Lolay, Inc.
//  Copyright 2011 MyLife, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface LolaySynchronousPaymentRequest : NSObject <SKPaymentTransactionObserver>

- (id) init;

/**
 *  Returns array of LolaySKPaymentTransaction
 */
- (NSArray *)makePaymentForProduct:(NSString *)productIdentifier error:(NSError **)error;

@end
