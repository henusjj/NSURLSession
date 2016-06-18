//
//  Manager.m
//  网络考试
//
//  Created by 史玉金 on 15/6/18.
//  Copyright © 2015年 史玉金. All rights reserved.
//


#import "Manager.h"

#define DOCUMENTDIRECTORY [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]

@interface Manager () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *session;

#pragma mark 属性：缓存池
@property (nonatomic, strong) NSMutableDictionary *cache;

#pragma mark 属性：Blocks
@property (nonatomic, strong) void (^progressBlock)(float progress);

@property (nonatomic, strong) void (^successBlock)(NSString *path);

@property (nonatomic, strong) void (^errorBlock)(NSError *error);

#pragma mark 属性：续传数据
@property (nonatomic, strong) NSData *resumeData;

@end

@implementation Manager

static id instance;

#pragma mark 单利方法
//  单例构造方法
+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
    {
        instance = [[Manager alloc] init];
    });
    
    return instance;
}


//  防止多次alloc的单利方法
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    if (instance == nil)
    {
        return [super allocWithZone:zone];
    }
    else
    {
        return instance;
    }
}

#pragma mark 懒加载方法
//  cache池的懒加载
- (NSMutableDictionary *)cache
{
    if (_cache == nil)
    {
        _cache = [NSMutableDictionary dictionaryWithCapacity:10];
    }
    return _cache;
}

//  session池的懒加载
- (NSURLSession *)session
{
    if (_session == nil)
    {
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        conf.timeoutIntervalForRequest = 50;
        
        _session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    
    return _session;
}

#pragma mark ********  下载方法  ********
//  下载方法
- (void)downloadWithURLString:(NSString *)URLString progressBlock:(void (^)(float progress))progressBlock successBlock:(void (^)(NSString *path))successBlock errorBlock:(void (^)(NSError *error))errorBlock
{
    // 对Block进行强引用
    self.progressBlock = progressBlock;
    
    self.successBlock = successBlock;
    
    self.errorBlock = errorBlock;
    
    // 如果已经有这个下载任务了，直接返回。并执行successBlock
    if ([self.cache objectForKey:URLString])
    {
        if (successBlock)
        {
            successBlock(@"此任务已经存在，请不要重复下载");
        }
        
        return;
    }
    
    // 判断是否有resumeData，先判断内存，再沙盒
    // 先准备沙盒中resume文件的路径
    NSString *resumePath = [[DOCUMENTDIRECTORY stringByAppendingPathComponent:URLString.lastPathComponent] stringByAppendingString:@".resume"];
    
    if (self.resumeData != nil)
    {
        // 执行下载方法
        NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithResumeData:self.resumeData];
        
        // 把返回值的task放进缓存池中
        [self.cache setValue:downloadTask forKey:URLString];
        
        [downloadTask resume];
        
        self.resumeData = nil;
        
        // 读取内存中的resumedata，此时实际上磁盘中也有resumedata，需要删除
        if([[NSFileManager defaultManager] fileExistsAtPath:resumePath])
        {
            [[NSFileManager defaultManager] removeItemAtPath:resumePath error:NULL];
        }
        
    }
    else if([[NSFileManager defaultManager] fileExistsAtPath:resumePath])
    {
        // 如果文件存在就读取到内存中
        self.resumeData = [NSData dataWithContentsOfFile:resumePath];
        
        // 执行下载方法
        NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithResumeData:self.resumeData];
        
        // 把返回值的task放进缓存池中
        [self.cache setValue:downloadTask forKey:URLString];
        
        [downloadTask resume];
        
        self.resumeData = nil;
        
        // 删除磁盘中的resumedata
        [[NSFileManager defaultManager] removeItemAtPath:resumePath error:NULL];
    }
    else
    {
        // 执行下载方法
        NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:URLString]];
        
        // 把返回值的task放进缓存池中
        [self.cache setValue:downloadTask forKey:URLString];
        
        [downloadTask resume];
    }
    
    
    
}


#pragma mark ********  暂停方法  ********

- (void)pauseWithURL:(NSString *)URLString
{
    if (!self.cache[URLString])
    {
        NSLog(@"这个APP没有在下载，不需要暂停");
        
        return;
    }
    
    NSURLSessionDownloadTask *downloadTask = (NSURLSessionDownloadTask *)self.cache[URLString];
    
    // 调用暂停，并创建恢复数据
    [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData)
    {
        
        NSString *resumePath = [DOCUMENTDIRECTORY stringByAppendingPathComponent:[URLString.lastPathComponent stringByAppendingString:@".resume"]];
        
        self.resumeData = resumeData;
        
        [resumeData writeToFile:resumePath atomically:YES];
        
        NSLog(@"已经暂停,resume数据保存在%@", resumePath);
    }];
    
    [self.cache removeObjectForKey:URLString];
}


#pragma mark NSURLSessionTaskDelegate方法

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 如果出错了，执行errorBlock
    if (error)
    {
        if (self.errorBlock)
        {
            if (error.code == -999) {
                return;
            }
            
            self.errorBlock(error);
        }
        
        //  出错了，删除缓存池中的任务
        [self.cache removeObjectForKey:task.originalRequest.URL.absoluteString];
    }
}


#pragma mark NSURLSessionDownloadDelegate方法
//  完成下载的代理方法
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    //  完成后，删除缓存池中的任务
    [self.cache removeObjectForKey:downloadTask.originalRequest.URL.absoluteString];
    
    //  拼接路径
    NSString *fileName = downloadTask.originalRequest.URL.lastPathComponent;
    
    NSString *filePath = [DOCUMENTDIRECTORY stringByAppendingPathComponent:fileName];
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    NSError *error = nil;
    
    //  将文件复制到要保存的路径
    [[NSFileManager defaultManager] copyItemAtURL:location toURL:fileURL error:&error];
    
    //  执行successBlock
    if (self.successBlock && !error)
    {
        self.successBlock(filePath);
    }
    else
    {
        self.errorBlock(error);
    }
}

//  将数据写入磁盘后调用的方法
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (self.progressBlock)
    {
        float progress = totalBytesWritten * 1.0 / totalBytesExpectedToWrite;
        
        self.progressBlock(progress);
    }
}

//  续传开始的方法
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"续传开始，当前文件从第 %zd 字节开始下载", fileOffset);
}

//提交代码错误，再次提交，编写（忽略）


@end












