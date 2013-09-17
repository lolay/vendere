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

#import "LolayVendereProductsRequest.h"
#import <StoreKit/StoreKit.h>
#import "LolayVendereError.h"

#define LolayVendereProductsRequestDefaultTimeout 20

@interface LolayVendereProductsRequest () <SKProductsRequestDelegate>

@property (nonatomic, strong) NSSet* productsIdentifiers;
@property (nonatomic, strong) SKProductsResponse* response;
@property (nonatomic, strong) NSConditionLock* lock;

@end

@implementation LolayVendereProductsRequest

enum {
	WAITING = 1,
	COMPLETED = 2
};

#pragma mark - NSObject

- (id) initWithProductIdentifiers:(NSSet*) productIdentifiers {
    self = [super init];
	
    if (self) {
        _productsIdentifiers = productIdentifiers;
        _lock = [[NSConditionLock alloc] initWithCondition:WAITING];
		_lock.name = @"LolayVendereProductsRequestLock";
    }
	
    return self;
}

#pragma mark - Payments

- (void) reset {
	self.response = nil;
	self.productsIdentifiers = nil;
	self.lock = [[NSConditionLock alloc] initWithCondition:WAITING];
	self.lock.name = @"LolayVendereProductsRequestLock";
}

- (SKProductsResponse*) productsResponseWithTimeout:(NSInteger) timeout error:(NSError**) error {
	if (self.lock.condition != WAITING) {
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorWaiting userInfo:nil];
		}
		[self reset];
        return nil;
	}
	
    if (timeout <= 0) {
        timeout = LolayVendereProductsRequestDefaultTimeout;
    }
    NSDate* expiration = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
    
    SKProductsRequest* productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:self.productsIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];
	
	SKProductsResponse* response = nil;

	// FIXME: Is there a better way than using a lock?
	// Create a latch waiting for when completed
    BOOL locked = [self.lock lockWhenCondition:COMPLETED beforeDate:expiration];
	[self.lock unlock];
	
    if (locked) {
		response = self.response;
		
    } else {
        // Timed out
        productsRequest.delegate = nil;
        if (error != NULL) {
			*error = [NSError errorWithDomain:LolayVendereErrorDomain code:LolayVendereErrorTimeout userInfo:nil];
		}
		response = nil; // Just in case
    }

	[self reset];
	return response;
}

+ (SKProductsResponse*) productsResponseForProductIdentifiers:(NSSet*) productIdentifiers timeout:(NSTimeInterval) timeout error:(NSError**) error {
    return [[[LolayVendereProductsRequest alloc] initWithProductIdentifiers:productIdentifiers] productsResponseWithTimeout:timeout error:error];
}

- (SKProductsResponse*) productsResponseError:(NSError**) error {
	return [self productsResponseWithTimeout:LolayVendereProductsRequestDefaultTimeout error:error];
}

+ (SKProductsResponse*) productsResponseForProductIdentifiers:(NSSet*) productIdentifiers error:(NSError**) error {
	return [LolayVendereProductsRequest productsResponseForProductIdentifiers:productIdentifiers timeout:LolayVendereProductsRequestDefaultTimeout error:error];
}

#pragma mark - SKProductsRequestDelegate

- (void) productsRequest:(SKProductsRequest*) request didReceiveResponse:(SKProductsResponse*) response {
    NSArray* responseProducts = response.products;
    DLog(@"Got products from AppStore %@", responseProducts);
    
	// Log, but suppress any invalid product identifiers
    for (NSString* invalidProductId in response.invalidProductIdentifiers) {
        DLog(@"Invalid product id: %@" , invalidProductId);
    }
    
    self.response = response;
	request.delegate = nil; // Just in case
	
	// Trigger an unlatch
	if (self.lock.condition != COMPLETED) {
		[self.lock lock];
		[self.lock unlockWithCondition:COMPLETED];
	}
}

@end
