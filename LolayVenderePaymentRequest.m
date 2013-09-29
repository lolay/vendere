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

#import "LolayVenderePaymentRequest.h"
#import <StoreKit/StoreKit.h>
#import "LolayVendereError.h"
#import "LolayVendereProductsRequest.h"

#define LolayVenderePaymentRequestDefaultTimeout 20

@interface LolayVenderePaymentRequest () <SKPaymentTransactionObserver>

@property (nonatomic, strong) NSString* productIdentifier;
@property (nonatomic, strong) NSSet* transactions;
@property (nonatomic, strong) NSConditionLock* lock;
@property (nonatomic, retain) NSError* error;

@end

@implementation LolayVenderePaymentRequest

enum {
	WAITING = 1,
	COMPLETED = 2
};

#pragma mark - NSObject

- (id) init {
    self = [super init];
	
    if (self) {
        _lock = [[NSConditionLock alloc] initWithCondition:WAITING];
    }
	
    return self;
}

#pragma mark - Payments

- (void) reset {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	self.productIdentifier = nil;
	self.transactions = nil;
	self.error = nil;
	self.lock = [[NSConditionLock alloc] initWithCondition:WAITING];
}

/*
 * Returns array of LolaySKPaymentTransaction.  If array is empty then the transaction has failed.
 */
- (NSSet*) makePaymentForProduct:(NSString*) productIdentifier timeout:(NSTimeInterval) timeout error:(NSError**) error {
	if (! [SKPaymentQueue canMakePayments]) {
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorCantMakePayments userInfo:nil];
		}
		[self reset];
        return nil;
	}
	
	if (self.lock.condition != WAITING) {
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorWaiting userInfo:nil];
		}
		[self reset];
        return nil;
	}
	
    if (timeout <= 0) {
        timeout = LolayVenderePaymentRequestDefaultTimeout;
    }
    NSDate* expiration = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
	
	NSError* productsError = nil;
	self.productIdentifier = productIdentifier;
	SKProductsResponse* productsResponse = [LolayVendereProductsRequest productsResponseForProductIdentifiers:[[NSSet alloc] initWithObjects:productIdentifier, nil] timeout:timeout error:&productsError];
	if (productsError) {
		if (error != NULL) {
			*error = productsError;
		}
		return nil;
	}
	
	SKProduct* product = nil;
	for (SKProduct* oneProduct in productsResponse.products) {
		if ([oneProduct.productIdentifier isEqualToString:productIdentifier]) {
			product = oneProduct;
			break;
		}
	}
	
	if (product == nil) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorInvalidProductIdentifier userInfo:nil];
		}
		return nil;
	}
	
    SKPayment* payment = [SKPayment paymentWithProduct:product];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
	// Trigger a latch for when the asynchronous tasks are completed
    BOOL locked = [self.lock lockWhenCondition:COMPLETED beforeDate:expiration];
	[self.lock unlock];
	
	NSSet* transactions = nil;

	if (locked) {
		if (self.error) {
			if (error != NULL) {
				*error = self.error;
			}
		} else {
			transactions = self.transactions;
		}
		
	} else {
		// Timed out
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorTimeout userInfo:nil];
		}
	}

	[self reset];
	return transactions;
}

+ (NSSet*) makePaymentForProduct:(NSString*) productIdentifier timeout:(NSTimeInterval) timeout error:(NSError**) error {
	return [[[LolayVenderePaymentRequest alloc] init] makePaymentForProduct:productIdentifier timeout:timeout error:error];
}

- (NSSet*) makePaymentForProduct:(NSString*) productIdentifier error:(NSError**) error {
	return [self makePaymentForProduct:productIdentifier timeout:LolayVenderePaymentRequestDefaultTimeout error:error];
}

+ (NSSet*) makePaymentForProduct:(NSString*) productIdentifier error:(NSError**) error {
	return [LolayVenderePaymentRequest makePaymentForProduct:productIdentifier timeout:LolayVenderePaymentRequestDefaultTimeout error:error];
}

#pragma mark - SKPaymentTransactionObserver

- (void) addTransaction:(SKPaymentTransaction*) transaction {
	if (self.transactions == nil) {
		self.transactions = [[NSSet alloc] initWithObjects:transaction, nil];
	} else {
		self.transactions = [self.transactions setByAddingObject:transaction];
	}
}

- (void) failedTransaction: (SKPaymentTransaction*) transaction {
    if (transaction.error.code != SKErrorPaymentCancelled) {
        DLog(@"Got a failed transaction: %@", transaction);
    }
    self.error = transaction.error;
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) restoredTransaction: (SKPaymentTransaction*) transaction {
    [self addTransaction: transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) purchasedTransaction: (SKPaymentTransaction*) transaction {
    [self addTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) paymentQueue:(SKPaymentQueue*) queue updatedTransactions:(NSArray*) transactions {
	BOOL completed = NO;
    for (SKPaymentTransaction* transaction in transactions) {
		DLog(@"productIdentifier=%@, transactionState=%i", transaction.payment.productIdentifier ,transaction.transactionState);
		if ([transaction.payment.productIdentifier isEqualToString:self.productIdentifier] && transaction.transactionState != SKPaymentTransactionStatePurchasing) {
			completed = YES;
		}
		
		switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchased:
				[self purchasedTransaction:transaction];
				break;
			case SKPaymentTransactionStateFailed:
				[self failedTransaction:transaction];
				break;
			case SKPaymentTransactionStateRestored:
				[self restoredTransaction:transaction];
				break;
		}
    }
	
	if (completed && self.lock.condition != COMPLETED) {
		// Trigger the latch
		[self.lock lock];
		[self.lock unlockWithCondition:COMPLETED];
	}
}

@end
