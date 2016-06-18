//
//  Manager.h
//  网络考试
//
//  Created by 史玉金 on 15/6/18.
//  Copyright © 2015年 史玉金. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Manager : NSObject

+ (instancetype)sharedManager;

- (void)downloadWithURLString:(NSString *)URLString progressBlock:(void (^)(float progress))progressBlock successBlock:(void (^)(NSString *path))successBlock errorBlock:(void (^)(NSError *error))errorBlock;

- (void)pauseWithURL:(NSString *)URLString;

@end
