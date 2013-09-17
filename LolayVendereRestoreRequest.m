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

#import "LolayVendereRestoreRequest.h"
#import <StoreKit/StoreKit.h>
#import "LolayVendereError.h"

#define LolayVendereRestoreRequestDefaultTimeout 20

@interface LolayVendereRestoreRequest () <SKPaymentTransactionObserver>

@property (nonatomic, strong) NSSet* transactions;
@property (nonatomic, strong) NSConditionLock* lock;
@property (nonatomic, retain) NSError* error;

@end

@implementation LolayVendereRestoreRequest

enum {
	WAITING = 1,
	COMPLETED = 2
};

#pragma mark - NSObject

- (id) init {
    self = [super init];
	
    if (self) {
        _lock = [[NSConditionLock alloc] initWithCondition:WAITING];
		_lock.name = @"LolayVendereRestoreRequestLock";
    }
	
    return self;
}

#pragma mark - Payments

- (void) reset {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	self.transactions = nil;
	self.error = nil;
	self.lock = [[NSConditionLock alloc] initWithCondition:WAITING];
	self.lock.name = @"LolayVendereRestoreRequestLock";
}

- (NSSet*) restorePaymentsWithTimeout:(NSTimeInterval) timeout error:(NSError**) error {
	if (self.lock.condition != WAITING) {
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorWaiting userInfo:nil];
		}
		[self reset];
        return nil;
	}
	
    if (timeout <= 0) {
        timeout = LolayVendereRestoreRequestDefaultTimeout;
    }
    NSDate* expiration = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
	
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	
	BOOL locked = [self.lock lockWhenCondition:COMPLETED beforeDate:expiration];
	
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
	
	[self.lock unlockWithCondition:WAITING];
	[self reset];
	return transactions;
}

+ (NSSet*) restorePaymentsWithTimeout:(NSTimeInterval) timeout error:(NSError**) error {
	return [[[LolayVendereRestoreRequest alloc] init] restorePaymentsWithTimeout:timeout error:error];
}

- (NSSet*) restorePaymentsWithError:(NSError**) error {
	return [self restorePaymentsWithTimeout:LolayVendereRestoreRequestDefaultTimeout error:error];
}

+ (NSSet*) restorePaymentsWithError:(NSError**) error {
	return [LolayVendereRestoreRequest restorePaymentsWithTimeout:LolayVendereRestoreRequestDefaultTimeout error:error];
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
    for (SKPaymentTransaction* transaction in transactions) {
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
}

- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue*) queue {
	if (self.lock.condition != COMPLETED) {
		[self.lock lock];
		[self.lock unlockWithCondition:COMPLETED];
	}
}

- (void) paymentQueue:(SKPaymentQueue*) queue restoreCompletedTransactionsFailedWithError:(NSError*) error {
	self.error = error;
	if (self.lock.condition != COMPLETED) {
		[self.lock lock];
		[self.lock unlockWithCondition:COMPLETED];
	}
}

@end
