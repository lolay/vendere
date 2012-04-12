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

#import "LolaySynchronousPaymentRequest.h"
#import "LolaySKPaymentTransaction.h"

#define LolayPaymentTransactionCancelled 1;

@interface LolaySynchronousPaymentRequest ()
@property (nonatomic, strong) NSMutableArray* transactions;
@property (nonatomic, strong) NSConditionLock* lock;
@property (nonatomic, retain) NSError* error;
@end

@implementation LolaySynchronousPaymentRequest

@synthesize transactions = transactions_;
@synthesize lock = lock_;
@synthesize error = error_;


enum {
    TRANSACTION_COMPLETE, NO_TRANSACTIONS };

- (id) init {
    self = [super init];
    if (self) {
        self.lock = [[NSConditionLock alloc] initWithCondition:NO_TRANSACTIONS];
        self.transactions = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

#pragma mark - AppStore

/*
 * Returns array of LolaySKPaymentTransaction.  If array is empty then the transaction has failed.
 */
- (NSArray*) makePaymentForProduct:(NSString*)productIdentifier error:(NSError**) error {
    SKPayment* payment = [SKPayment paymentWithProductIdentifier:productIdentifier];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
    [self.lock lockWhenCondition:TRANSACTION_COMPLETE];
    NSArray* theTransactions = self.transactions;
    self.transactions = [NSMutableArray arrayWithCapacity:1];
    [self.lock unlockWithCondition:NO_TRANSACTIONS];

    if (error != NULL) {
        *error = self.error;
        self.error = nil;
    }
    
    return theTransactions;
}

#pragma mark - SKPaymentTransactionObserver

- (void) failedTransaction: (SKPaymentTransaction*) transaction {
    if (transaction.error.code != SKErrorPaymentCancelled) {
        //TODO what to do with failed transaction??? For now just log it.
        DLog(@"Got a failed transaction: %@", transaction);
    }
    self.error = transaction.error;
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) recordTransaction:(SKPaymentTransaction*) transaction {
    LolaySKPaymentTransaction* lvdTransaction = [LolaySKPaymentTransaction transactionWithIdentifier:transaction.transactionIdentifier receipt:transaction.transactionReceipt transactionDate:transaction.transactionDate];
    [self.transactions addObject:lvdTransaction];
}

// This comes into play when user renews the subscription, we will get a new transaction, 
// and we'll have to send the receipt to server again.  The question is: how???
- (void) restoreTransaction: (SKPaymentTransaction*) transaction {
    //TODO what to do with restored transaction because of user renewal???
    [self recordTransaction: transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) completeTransaction: (SKPaymentTransaction*) transaction {
    [self recordTransaction: transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
}

- (void)paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*) transactions {
    [self.lock lock];
    for (SKPaymentTransaction* transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                [self.lock unlockWithCondition:TRANSACTION_COMPLETE];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                [self.lock unlockWithCondition:TRANSACTION_COMPLETE];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                [self.lock unlockWithCondition:TRANSACTION_COMPLETE];
                break;
            case SKPaymentTransactionStatePurchasing:
                [self.lock unlockWithCondition:NO_TRANSACTIONS];
                break;
        }
    }
}
@end
