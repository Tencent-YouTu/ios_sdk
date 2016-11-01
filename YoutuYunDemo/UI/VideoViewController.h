//
//  VideoViewController.h
//  WeBank
//
//  Created by doufeifei on 14/12/23.
//
//

#import <UIKit/UIKit.h>
#import "WBBaseViewController.h"

@interface VideoViewController : WBBaseViewController

-(void)setReadLips:(NSString *)r;
-(void)setValidateId:(UInt32)i;

-(void)setCardId:(NSString *)c;
-(void)setCardName:(NSString *)c;

@end
