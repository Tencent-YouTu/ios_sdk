//
//  WBBaseViewController.h
//  WeBank
//
//  Created by doufeifei on 14/12/11.
//
//

#import <UIKit/UIKit.h>

@interface WBBaseViewController : UIViewController

- (void)showLoading:(NSString *)text;
- (void)showLoading:(NSString *)text toView:(UIView *)view;
- (void)hideLoading;

- (void)showAlert:(NSString *)title message:(NSString *)text;

- (void)configNavigationBar;
@end
