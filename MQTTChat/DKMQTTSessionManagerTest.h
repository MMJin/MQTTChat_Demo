//
//  DKMQTTSessionManagerTest.h
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/17.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReconnectTimer.h"
NS_ASSUME_NONNULL_BEGIN
typedef void(^MqttStatus)(NSString *code);
typedef void(^MqttMassage)(id dataModel,NSString *topic);

@interface DKMQTTSessionManagerTest : NSObject
@property(nonatomic,copy)MqttStatus statusCodeCallBack;//mq的连接状态

@property(nonatomic,copy)MqttMassage dataDicCallBack;//mq主题返回数据

@property (strong, nonatomic) ReconnectTimer *reconnectTimer;

//全区监听存储到本地的topic推送数据
@property (strong, nonatomic)  NSMutableDictionary *globalTopicDic;

//建立连接
-(void)connectedWithHost:(NSString *)host port:(NSInteger)port userName:(NSString *)userName password:(NSString *)password mqttStatus:(MqttStatus)status;
//订阅主题单个
-(void)subTopic:(NSDictionary *)topic withTopicCallBack:(MqttMassage)dataDicCallBack mqttStatus:(MqttStatus)status;
//订阅多个主题
/// 设置需要监听的topic  @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param subTopics @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param dataDicCallBack 主题返回的数据  对应的json数据和topic
-(void)subTopicsWithDic:(NSDictionary *)subTopics WithDicModel:(NSDictionary *)subTopicModels withTopicCallBack:(MqttMassage)dataDicCallBack mqttStatus:(MqttStatus)status;
//取消主题
-(void)unsubTopic:(NSString *)topic mqttStatus:(MqttStatus)status;
//取消多个主题
///移除需要处理的监听
/// @param udSubTopics @[@"topic1",@"topic2"]
-(void)unSubTopicsWithDic:(NSArray *)udSubTopics mqttStatus:(MqttStatus)status;
//发送数据
/// 给对应的topic发送数据
/// @param data 发送的数据
/// @param topic 操作的topic
-(void)senderData:(NSData *)data withTopic:(NSString *)topic;
//断开链接
-(void)disconnect;

@end

NS_ASSUME_NONNULL_END
