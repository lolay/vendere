//
//  Created by Lolay, Inc.
//  Copyright 2012 Lolay, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * This captures data from SKPaymentTransaction in an archivable form
 */
@interface LolaySKPaymentTransaction : NSObject
@property (nonatomic, strong) NSDate* transactionDate;
@property (nonatomic, strong) NSString* identifier;
@property (nonatomic, strong) NSData* receipt;

+ (LolaySKPaymentTransaction*) transactionWithIdentifier:(NSString*) identifier receipt:(NSData*) receipt transactionDate:(NSDate*) transactionDate;

@end
