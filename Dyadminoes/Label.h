//
//  Label.h
//  Dyadminoes
//
//  Created by Bennett Lin on 3/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface Label : SKLabelNode

-(id)initWithName:(NSString *)name
         andColor:(UIColor *)color
      andFontSize:(CGFloat)fontSize
      andPosition:(CGPoint)position
     andZPosition:(CGFloat)zPosition
  andHorizontalAlignment:(SKLabelHorizontalAlignmentMode)horizontalAlignment;

@end