//
//  DKMQTTDataReceicveManager.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/13.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "DKMQTTDataReceicveManager.h"

@implementation DKMQTTDataReceicveManager
#pragma mark - 初始化数据库管理者
+ (DKMQTTDataReceicveManager *)shareManager {
    static DKMQTTDataReceicveManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DKMQTTDataReceicveManager alloc] init];
        manager.mqttTopicsDatas = [[NSMutableDictionary alloc]init];
        NSLog(@" 初始化数据库管理者");
    });
    return manager;
}
@end
