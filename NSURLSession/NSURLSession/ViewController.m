//
//  ViewController.m
//  NSURLSession
//
//  Created by 史玉金 on 15/6/18.
//  Copyright © 2015年 史玉金. All rights reserved.
//

#import "ViewController.h"

#import "Manager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)startDown:(UIButton *)sender {
    
    Manager *manager = [Manager sharedManager];
    
    [manager downloadWithURLString:@"http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.1.1.dmg" progressBlock:^(float progress)
     {
         NSLog(@"当前下载进度为: %f", progress);
     }
                      successBlock:^(NSString *path)
     {
         NSLog(@"文件下载地址为: %@", path);
     }
                        errorBlock:^(NSError *error)
     {
         NSLog(@"文件下载出错了: %@", error);
     }];

    
}
- (IBAction)cannelDown:(UIButton *)sender {
    Manager *manager = [Manager sharedManager];
    
    [manager pauseWithURL:@"http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.1.1.dmg"];

    
}

@end
