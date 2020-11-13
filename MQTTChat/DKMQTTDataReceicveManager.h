//
//  DKMQTTDataReceicveManager.h
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/13.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKMQTTDataReceicveManager : NSObject
//单利存储mqtt topic数据字典
@property(nonatomic,strong)NSMutableDictionary *mqttTopicsDatas;
//初始化数据管理
+ (DKMQTTDataReceicveManager *)shareManager;
@end

NS_ASSUME_NONNULL_END
