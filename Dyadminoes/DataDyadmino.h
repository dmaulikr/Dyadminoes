//
//  DataDyadmino.h
//  Dyadminoes
//
//  Created by Bennett Lin on 6/1/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Helper.h"

@interface DataDyadmino : NSObject <NSCoding>

@property (nonatomic) NSUInteger myID;
@property (nonatomic) DyadminoOrientation myOrientation;
@property (nonatomic) HexCoord myHexCoord;
@property (nonatomic) NSInteger myRackOrder;

-(id)initWithID:(NSUInteger)id;

@end