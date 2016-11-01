//
//  ViewController.m
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "CardResultViewController.h"
#import "VideoViewController.h"
#import "YTServerAPI.h"
#import "DemoViewController.h"


@interface CardResultViewController ()
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *idCardLabel;
@property (strong, nonatomic) IBOutlet UIButton *confirmButton;

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *id;

@end

@implementation CardResultViewController
- (instancetype) init{
    NSString *nibName = @"CardResultViewController";
    self = [super initWithNibName:nibName bundle:nil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    barButton.title = @"返回";
    self.navigationController.navigationBar.topItem.backBarButtonItem = barButton;
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationItem setTitle:@"确认信息"];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"nav_back64.png"] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    UIImage *buttongBgImg = [[UIImage imageNamed:@"bt_blue"] resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6)];
    [self.confirmButton setBackgroundImage:buttongBgImg forState:UIControlStateNormal];
    
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    self.name = [userDefault stringForKey:@"idCardName"];
    self.id = [userDefault stringForKey:@"idCardNo"];
    
    self.nameLabel.text = self.name;
    self.idCardLabel.text = self.id;
    
  }
- (IBAction)clickConfirm:(id)sender {
    [self showLoading:@""];
    [[YTServerAPI instance] getLivefour:^(NSInteger error, NSString *number){
        [self hideLoading];
        if (error == 0) {
            VideoViewController *controller = [[VideoViewController alloc]init];
            [controller setReadLips:number];
            [controller setCardId:self.id];
            [controller setCardName:self.name];
            [self.navigationController pushViewController:controller animated:YES];
        }
    }];
}
- (IBAction)clickBack:(id)sender {
    DemoViewController* controller = [[DemoViewController alloc]init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
