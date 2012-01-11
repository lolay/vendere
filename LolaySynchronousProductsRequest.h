//
//  Created by Lolay, Inc.
//  Copyright 2012 Lolay, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface LolaySynchronousProductsRequest : NSObject <SKProductsRequestDelegate>

+ (SKProductsResponse*) productsResponseForProductIdentifiers:(NSSet*) productIdentifiers timeout:(NSTimeInterval) timeout error:(NSError**) error;
- (id) initWithProductIdentifiers:(NSSet *)productIdentifiers;
- (SKProductsResponse*) productsResponseWithTimeout:(NSInteger) timeout error:(NSError**) error;
@end
