//
//  Copyright 2012 Lolay, Inc.
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

#import "LolaySynchronousProductsRequest.h"
#import "LolayVendere.h"

#define LDSSynchronousProductsRequestDefaultTimeout 20000;

@interface LolaySynchronousProductsRequest ()
@property (nonatomic, strong) NSSet* productsIdentifiers;
@property (nonatomic, strong) SKProductsResponse* response;
@property (nonatomic, strong) NSConditionLock* lock;
@end

@implementation LolaySynchronousProductsRequest

@synthesize productsIdentifiers = productsIdentifiers_;
@synthesize response = response_;
@synthesize lock = lock_;

enum { HAS_PRODUCTS, NO_PRODUCTS };

+ (SKProductsResponse*) productsResponseForProductIdentifiers:(NSSet*) productIdentifiers timeout:(NSTimeInterval) timeout error:(NSError**) error {
    LolaySynchronousProductsRequest* productsRequest = [[LolaySynchronousProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    return [productsRequest productsResponseWithTimeout:timeout error:error];
}

- (id) initWithProductIdentifiers:(NSSet*) productIdentifiers {
    self = [super init];
    if (self) {
        self.productsIdentifiers = productIdentifiers;
        self.lock = [[NSConditionLock alloc] initWithCondition:NO_PRODUCTS];
    }
    return self;
}

- (SKProductsResponse*) productsResponseWithTimeout:(NSInteger) timeout error:(NSError**) error {
    if (timeout <= 0) {
        timeout = LDSSynchronousProductsRequestDefaultTimeout;
    }
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    SKProductsRequest* productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:self.productsIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];

    SKProductsResponse* theResponse = nil;
    BOOL locked = [self.lock lockWhenCondition:HAS_PRODUCTS beforeDate:date];
    if (locked) {
        theResponse = self.response;
        self.response = nil;
        [self.lock unlockWithCondition:NO_PRODUCTS];
    } else {
        // timed out
        productsRequest.delegate = nil;
        NSError* newError = [NSError errorWithDomain:@"LVD" code:LVDProductsRequestTimedOut userInfo:nil];
        if (error != NULL) {
			*error = newError;
		}
        return nil;
    }
    return theResponse;
} 

- (void)productsRequest:(SKProductsRequest*) request didReceiveResponse:(SKProductsResponse*) response {
    NSArray* responseProducts = response.products;
    DLog(@"Got products from AppStore %@", responseProducts);
    
    for (NSString* invalidProductId in response.invalidProductIdentifiers) {
        DLog(@"Invalid product id: %@" , invalidProductId);
    }
    
    [self.lock lock];
    self.response = response;
    [self.lock unlockWithCondition:HAS_PRODUCTS];
} 

@end
