//
//  WBBaseViewController.m
//  WeBank
//
//  Created by doufeifei on 14/12/11.
//
//

#import "WBBaseViewController.h"
#import "MBProgressHUD.h"
@interface WBBaseViewController ()
{
    MBProgressHUD *_hudLoading;
}
@end

@implementation WBBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self configNavigationBar];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showLoading:(NSString *)text
{
    [self showLoading:text toView:self.view];
}

- (void)showLoading:(NSString *)text toView:(UIView *)view
{
    _hudLoading = [MBProgressHUD showHUDAddedTo:view animated:YES];
    _hudLoading.mode = MBProgressHUDModeIndeterminate;
    _hudLoading.labelText = text;
    _hudLoading.labelColor = [UIColor whiteColor];
}

- (void)hideLoading
{
    _hudLoading.progress = 1.00f;
    [_hudLoading hide:YES];
}
- (void)showAlert:(NSString *)title message:(NSString *)text
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:text delegate:nil cancelButtonTitle:@"确定"otherButtonTitles:nil, nil];
    [alert show];
}

- (void)configNavigationBar
{
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"nav_back64.png"] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

@end
