//
//  ViewController.m
//  mmap
//
//  Created by wangwei on 2018/11/30.
//  Copyright © 2018 wangwei. All rights reserved.
//

#import "ViewController.h"

#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include<sys/mman.h>

#import <mach/mach_time.h>
#import <MMKV.h>
#import "MWSQLiteManager.h"


#define FastKVSeperatorString @"$FastKVSeperatorString$"

// 映射文件到内存
int MapFile( int fd , void ** outDataPtr, size_t mapSize , struct stat * stat);
// 执行文件
int ProcessFile( char * inPathName , char * string);
// 读取文件
int ReadFile( char * inPathName , void ** outDataPtr, struct stat * stat);


int ReadFile( char * inPathName , void ** outDataPtr, struct stat * stat)
{
    size_t originLength;  // 原数据字节数
    void * start;         //
    int fd;               // 文件
    int outError;         // 错误信息
    
    // 打开文件
    // Open the file.
    fd = open( inPathName, O_RDWR | O_CREAT, 0 );
    
    if( fd < 0 )
    {
        outError = errno;
        return 1;
    }
    
    // 获取文件状态
    int fsta = fstat( fd, stat );
    if( fsta != 0 )
    {
        outError = errno;
        return 1;
    }
    
    // 需要映射的文件大小
    originLength = (* stat).st_size;
    size_t mapsize = originLength;
    
    // 文件映射到内存
    int result = MapFile(fd, outDataPtr, mapsize ,stat);
    
    // 文件映射成功
    if( result == 0 )
    {
//        start = outDataPtr;
        //        fsync(fd);
        // 关闭映射，将修改同步到磁盘上，可能会出现延迟
        //        munmap(start, mapsize);
        
        // 关闭文件
//        close( fd );
    }
    else
    {
        // 映射失败
        NSLog(@"映射失败");
    }
    return 0;
}

int ProcessFile( char * inPathName , char * string)
{
    size_t originLength;  // 原数据字节数
    size_t dataLength;    // 数据字节数
    void * dataPtr;       //
    void * start;         //
    struct stat statInfo; // 文件状态
    int fd;               // 文件
    int outError;         // 错误信息
    
    // 打开文件
    // Open the file.
    fd = open( inPathName, O_RDWR | O_CREAT, 0 );
    
    if( fd < 0 )
    {
        outError = errno;
        return 1;
    }
    
    // 获取文件状态
    int fsta = fstat( fd, &statInfo );
    if( fsta != 0 )
    {
        outError = errno;
        return 1;
    }
    
    // 需要映射的文件大小
    dataLength = strlen(string);
    originLength = statInfo.st_size;
    size_t mapsize = originLength + dataLength;
    
    
    // 文件映射到内存
    int result = MapFile(fd, &dataPtr, mapsize ,&statInfo);
    
    // 文件映射成功
    if( result == 0 )
    {
        start = dataPtr;
        dataPtr = dataPtr + statInfo.st_size;
        
        memcpy(dataPtr, string, dataLength);

        
        //        fsync(fd);
        // 关闭映射，将修改同步到磁盘上，可能会出现延迟
        //        munmap(start, mapsize);
        
        // 关闭文件
        close( fd );
    }
    else
    {
        // 映射失败
        NSLog(@"映射失败");
    }
    return 0;
}
// MapFile 文件映射

// Exit:    fd              代表文件
//          outDataPtr      映射文件的起始位置
//          mapSize         映射的size
//          return value    返回值为0时，代表映射文件成功
//
int MapFile( int fd, void ** outDataPtr, size_t mapSize , struct stat * stat)
{
    int outError;         // 错误信息
    struct stat statInfo; // 文件状态
    
    statInfo = * stat;
    
    // Return safe values on error.
    outError = 0;
    *outDataPtr = NULL;
    
    *outDataPtr = mmap(NULL,
                       mapSize,
                       PROT_READ|PROT_WRITE,
                       MAP_FILE|MAP_SHARED,
                       fd,
                       0);
    
//        NSLog(@"映射出的文本内容：%s", * outDataPtr);
    if( *outDataPtr == MAP_FAILED )
    {
        outError = errno;
    }
    else
    {
        // 调整文件的大小
        ftruncate(fd, mapSize);
        fsync(fd);//刷新文件
    }
    return outError;
}


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *mTV;
@property (copy, nonatomic) NSString *fullpath;
@property (copy, nonatomic) NSString *mapFullpath;

@property (strong, nonatomic, nonnull) NSFileManager *fileManager;

@end

@implementation ViewController

- (NSString *)getFilefullPath {
    if (_fullpath.length == 0) {
        
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [NSString stringWithFormat:@"%@/text.txt",path];
        
        if (![self.fileManager fileExistsAtPath:filePath]) {
//            [self.fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:NULL];
            [self.fileManager createFileAtPath:filePath contents:nil attributes:nil];
        }
        
        self.fullpath = filePath;
    }
    return _fullpath;
}

- (NSString *)getMapfullPath {
    if (_mapFullpath.length == 0) {
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [NSString stringWithFormat:@"%@/mapText.txt",path];
        
        if (![self.fileManager fileExistsAtPath:filePath]) {
            [self.fileManager createFileAtPath:filePath contents:nil attributes:nil];
//            [self.fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
        self.mapFullpath = filePath;
    }
    return _mapFullpath;
}

- (IBAction)save {
    
    [[MMKV defaultMMKV] setObject:@"111" forKey:@"userid"];
    
//    [[MMKV defaultMMKV] setObject:@{@"name": @"hehe"} forKey:@"userDic"];
}


- (IBAction)get {
    
//    NSString *string = [[MMKV defaultMMKV] getObjectOfClass:[NSString class] forKey:@"userid"];
//    NSLog(@"userid: %@",string);
    
//    NSString *dic = [[MMKV defaultMMKV] getObjectOfClass:[NSString class] forKey:@"userDic"];
//    NSLog(@"userDic: %@",dic);
    CGFloat time = LogTimeBlock(^{
        NSArray *sqlArr = [[MWSQLiteManager share] queryRequestDicsWithUserId:@"wangwei"];
        NSLog(@"sqlArr: %ld", sqlArr.count);
    });
    NSLog(@"File readFile %@s", @(time));

    CGFloat time1 = LogTimeBlock(^{
        NSArray *mapArr = [self getEventArr];
        NSLog(@"mapArr: %ld", mapArr.count);
    });
    NSLog(@"MMAp readFile %@s", @(time1));
    
    
    
//    NSLog(@"mapFile: %@, mapArr: %@", sqlArr.description, mapArr.description);
}

// 根据userId获取所有的eventArr
- (nullable NSArray *)getEventArr {
    
    void * dataPtr;
    struct stat statInfo;
    
    NSString *mapFilePath = [self getMapfullPath];
    

    ReadFile([mapFilePath UTF8String], &dataPtr, &statInfo);
    
    NSData *data = [NSData dataWithBytes:dataPtr length:statInfo.st_size];
    
    NSString *result =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    
    // 分割字符串
    NSArray *dicStrArr = [result componentsSeparatedByString:FastKVSeperatorString];
    NSMutableArray *dicArr = [NSMutableArray array];
    @autoreleasepool {
        for (NSString *dicStr in dicStrArr) {
            NSDictionary *dic = [self dictionaryWithJsonString:dicStr];
            if (dic != nil) {
                [dicArr addObject:dic];
            }
        }
    }
    
    
    NSArray *list = [dicArr copy];
    return list;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    
    self.fileManager = [NSFileManager new];
    
    [self eventAction];
}

CGFloat LogTimeBlock (void (^block)(void)) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return -1.0;
    
    uint64_t start = mach_absolute_time ();
    block ();
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    
    uint64_t nanos = elapsed * info.numer / info.denom;
    return (CGFloat)nanos / NSEC_PER_SEC;
}

-  (void)eventAction {
    
    NSString *mapFilePath = [self getMapfullPath];
    NSString *filePath = [self getFilefullPath];
    
    
    NSDictionary *dic = @{@"wangwei": @"hahhah"};
    
    // 写入数据库的方法
    NSLog(@"start");
    CGFloat time1 = LogTimeBlock(^{
        for (int i=0; i<5000; i++) {
            [[MWSQLiteManager share] insertWithRequestDic:dic byUserId:@"wangwei"];
        }
    });
    NSLog(@"File writeFile %@s", @(time1));

    
    // 写入文件的方式
    CGFloat time = LogTimeBlock(^{
        for (int i=0; i<5000; i++) {
            NSMutableString *string = [NSMutableString string];
            [string appendString:[self dictionaryToJson:dic]];
            [string appendString:FastKVSeperatorString];
            int result = ProcessFile([mapFilePath UTF8String], [string UTF8String]);
            if (result == 1) {
                NSLog(@"发生错误啦");
            }
        }
    });
    NSLog(@"mapFile writeFile %@s", @(time));
    NSLog(@"end");
}



- (NSDictionary *)parseFromData:(NSData *)data {
    if (data.length == 0) {
        return nil;
    }
    
    // CRC check
    //    uint16_t crc = [[data subdataWithRange:NSMakeRange(0, data.length-2)] fkv_crc16];
    //    uint16_t crcInData;
    //    [data getBytes:&crcInData range:NSMakeRange(data.length-2, 2)];
    //    if (crc != crcInData) {
    //        return nil;
    //    }
    @try {
        
        NSString  *stringVal = [[NSString alloc] initWithBytes:[data bytes]
                                                        length:data.length
                                                      encoding:NSUTF8StringEncoding];
        
        id dic = [self dictionaryWithJsonString:stringVal];
        return [dic isKindOfClass:[NSDictionary class]] ? dic : nil;
    } @catch (NSException *e) {
        return nil;
    }
    //     *dic = [NSKeyedUnarchiver unarchiveObjectWithData:];
    //    return dic;
}

//字典转json格式字符串：
- (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    
    if (jsonString == nil) {
        
        return nil;
        
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *err;
    
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                         
                                                        options:NSJSONReadingMutableContainers
                         
                                                          error:&err];
    
    if(err) {
        
        NSLog(@"json解析失败：%@",err);
        
        return nil;
        
    }
    
    return dic;
    
}

@end
