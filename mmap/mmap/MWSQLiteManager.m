//
//  MWSQLiteManager.m
//  MWSQLiteManager
//
//  Created by 王大吉 on 5/6/2018.
//  Copyright © 2018 王大吉. All rights reserved.
//

#import "MWSQLiteManager.h"

// 表名
#define TRACKING_DATA_TABLE                      @"t_mw_table"
// userID字段
#define TRACKING_DATA_TABLE_USERID               @"userId"
// 数组字段
#define TRACKING_DATA_TABLE_REQUESTDIC           @"requestDic"
// sqlite路径
#define TRACKING_DATA_QUEUE                      @"mw_tracking.sqlite"




static sqlite3 *MW_db = nil;

@interface MWSQLiteManager ()

@property (strong, nonatomic, nonnull) dispatch_queue_t sqliteQueue; // the queue to do sqlite

@end

@implementation MWSQLiteManager

+ (MWSQLiteManager *)share {
    static MWSQLiteManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[MWSQLiteManager alloc] init];
        [manager openDB];// 打开数据库
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // 创建队列
//        self.sqliteQueue = dispatch_queue_create(@"cn.merculet.open.SDWebImageDownloaderOperationCoderQueue", <#dispatch_queue_attr_t  _Nullable attr#>)
        
    }
    return self;
}

- (sqlite3 *)openDB {
    
    if (MW_db != nil) {
        return MW_db;
    }
    
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:TRACKING_DATA_QUEUE];
    
    // [MWLog log:[NSString stringWithFormat:@"sqlite路径： %@", dbPath]];
//    NSLog(@"%@",dbPath);
    
    int result = sqlite3_open(dbPath.UTF8String, &MW_db);
    if (result == SQLITE_OK) {
        // [MWLog log:@"打开数据库成功"];
        // 创建表
        [self createTable];
    } else {
        // [MWLog log:@"打开数据库失败"];
    }
    return MW_db;
}


- (void)closeDB {
    
    int result = sqlite3_close(MW_db);
    if (result == SQLITE_OK) {
        MW_db = nil;
        // [MWLog log:@"关闭数据库成功"];
    } else {
        // [MWLog log:@"关闭数据库失败"];
    }
}

- (void)createTable {
    
    NSString *sql = [NSString stringWithFormat:@"create table IF NOT EXISTS %@(number integer primary key not NULL, '%@' text not NULL, '%@' blob NOT NULL)", TRACKING_DATA_TABLE, TRACKING_DATA_TABLE_USERID, TRACKING_DATA_TABLE_REQUESTDIC];
    
    
    int result = sqlite3_exec(MW_db, sql.UTF8String, NULL, NULL, NULL);
    
    if ([self canUseMMAP]) {
        // 开启映射
        sqlite3_exec(MW_db, "PRAGMA mmap_size=268435456;", NULL, NULL, NULL);
    }
    
    if (result == SQLITE_OK) {
        // [MWLog log:@"创建表成功"];
    } else {
        // [MWLog log:@"创建表失败"];
    } 
}

// 插入
- (void)insertWithRequestDic:(nonnull NSDictionary *)requestDic byUserId:(nonnull NSString *)userId {

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSData *statusData = [NSKeyedArchiver archivedDataWithRootObject:requestDic];
    double dataLength = statusData.length/1024.0/1024.0/1024.0;
    if (dataLength > [self availableMeory])
    {
        // [MWLog log:@"插入的数据比磁盘量要大"];
        return;
    }
    
//    NSString *sql = [NSString stringWithFormat:@"INSERT INTO t_mw_table(userId, requestDic) VALUES(?,?)"];
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@, %@) VALUES(?,?)", TRACKING_DATA_TABLE, TRACKING_DATA_TABLE_USERID, TRACKING_DATA_TABLE_REQUESTDIC];
    sqlite3_stmt *stmt = nil;
    
    // 检查语句
    if (sqlite3_prepare(MW_db, sql.UTF8String, -1, &stmt, NULL) != SQLITE_OK) {
        // [MWLog log:@"insert prepare error"];

    } else {
      
        sqlite3_bind_text(stmt, 1, userId.UTF8String, -1, NULL);
        sqlite3_bind_blob(stmt, 2, statusData.bytes, (int)statusData.length, NULL);
        
        int reslut = sqlite3_step(stmt);
        
        if (reslut == SQLITE_DONE) {
        } else {
            // [MWLog log:[NSString stringWithFormat:@"userID为：%@的数据插入失败", userId]];
        }
    }
    sqlite3_finalize(stmt);
    
    dispatch_semaphore_signal(semaphore);
}

// 更新
- (void)updateRequestDic:(nonnull NSDictionary *)requestDic byUserId:(nonnull NSString *)userId {
    
    NSData *statusData = [NSKeyedArchiver archivedDataWithRootObject:requestDic];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = '%@'",TRACKING_DATA_TABLE, TRACKING_DATA_TABLE_REQUESTDIC, statusData, TRACKING_DATA_TABLE_USERID, userId];
    
    int result = sqlite3_exec(MW_db, sql.UTF8String, NULL, NULL, NULL);
    if (result == SQLITE_OK) {
    } else {
        // [MWLog log:[NSString stringWithFormat:@"userID为：%@的数据更新失败", userId]];
    }
}

// 根据userID删除
- (void)deleteWithUserId:(nonnull NSString *)userId {
    
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = '%@'",TRACKING_DATA_TABLE, TRACKING_DATA_TABLE_USERID, userId];
    
    int result = sqlite3_exec(MW_db, sql.UTF8String, NULL, NULL, NULL);
    if (result == SQLITE_OK) {
    } else {
        // [MWLog log:[NSString stringWithFormat:@"userID为：%@的数据删除失败", userId]];
    }
}

// 根据userID查询
- (nullable NSArray *)queryRequestDicsWithUserId:(NSString *)userId {
    
    NSString *sql = [NSString stringWithFormat:@"select * from %@ where %@ = '%@'",TRACKING_DATA_TABLE ,TRACKING_DATA_TABLE_USERID, userId];
    
    // 创建跟随指针 保存sql语句
    sqlite3_stmt *stmt = nil;
    // 判断语句是否正确
    int result = sqlite3_prepare_v2(MW_db, sql.UTF8String, -1, &stmt, NULL);
    
    NSMutableArray *requestDics = [NSMutableArray array];
    
    if (result == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int length = sqlite3_column_bytes(stmt, 2);
            const void *requestDicBytes = sqlite3_column_blob(stmt, 2);
            NSData *data = [NSData dataWithBytes:requestDicBytes length:length];
            NSDictionary *requestDic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [requestDics addObject:requestDic];
        }
        sqlite3_finalize(stmt);
        
    } else {
        // [MWLog log:@"查询失败"];
    }
    return requestDics;
}

// 删除全部
- (void)deleteAllRequestDics {
    
    NSString *sql = [NSString stringWithFormat:@"delete from %@",TRACKING_DATA_TABLE];
    int result = sqlite3_exec(MW_db, sql.UTF8String, NULL, NULL, NULL);
    if (result == SQLITE_OK) {
        
    } else {
        // [MWLog log:@"删除失败"];
    }
}

// 查询全部
- (NSArray *)queryAllRequestDics  {
    
    NSString *sql = [NSString stringWithFormat:@"select * from %@", TRACKING_DATA_TABLE];
    
    sqlite3_stmt *stmt = nil;
    int result = sqlite3_prepare_v2(MW_db, sql.UTF8String, -1, &stmt, NULL);
    
    NSMutableArray *requestDics = [NSMutableArray array];
    
    if (result == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int length = sqlite3_column_bytes(stmt, 2);
            const void *requestDicBytes = sqlite3_column_blob(stmt, 2);
            NSData *data = [NSData dataWithBytes:requestDicBytes length:length];
            NSDictionary *requestDic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [requestDics addObject:requestDic];
        }
        sqlite3_finalize(stmt);
        
    } else {
        // [MWLog log:@"查询全部失败"];
    }
    return requestDics;
    
}

// 本地磁盘可用空间
- (double)availableMeory
{
    float totalSpace;
    float totalFreeSpace=0.f;
    
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes floatValue]/1024.0f/1024.0f/1024.0f;
        totalFreeSpace = [freeFileSystemSizeInBytes floatValue]/1024.0f/1024.0f/1024.0f;
        
        // [MWLog log:[NSString stringWithFormat:@"Memory Capacity of %.2f GB with %.2f GB Free memory available.", totalSpace, totalFreeSpace]];
        
    } else {
        totalSpace = 1.0f;
        // [MWLog log:[NSString stringWithFormat:@"Error Obtaining System Memory Info: Domain = %@, Code = %li", [error domain], (long)[error code]]];
    }
    return totalFreeSpace;
}

#pragma mark SQLite information

// 3.7.17 , mmap can use version
#define MWSqliteCanUseMMAPVersion @"3.7.17"

- (BOOL)canUseMMAP {
    
    NSString *version = [NSString stringWithFormat:@"%s", sqlite3_libversion()];
    NSComparisonResult result = [version compare:MWSqliteCanUseMMAPVersion options:NSNumericSearch];
    if (result == NSOrderedDescending || result == NSOrderedSame) {
        return YES;
    }
    return NO;
}

@end
