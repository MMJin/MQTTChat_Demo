//
//  DKMQTTCommunicationManager.h
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/11.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MQTTClient.h"
//#import <MQTTClient/MQTTSessionManager.h>
#import "DKMQTTSessionManager.h"
NS_ASSUME_NONNULL_BEGIN
/**
 Enumeration of MQTTSessionManagerState values
 */
typedef NS_ENUM(int, MQTTConnectState) {
    MQTTConnectStarting,
    MQTTConnectConnecting,
    MQTTConnectError,
    MQTTConnectConnected,
    MQTTConnectClosing,
    MQTTConnectClosed
};
typedef void(^MqttStatus)(NSString *code);
typedef void(^MqttMassage)(id dataModel,NSString *topic);
@interface DKMQTTCommunicationManager : NSObject

@property(nonatomic,copy)MqttStatus statusCodeCallBack;//mq的连接状态

@property(nonatomic,copy)MqttMassage dataDicCallBack;//mq主题返回数据

/**
 单例

 @return self
 */
+(DKMQTTCommunicationManager *)shareInstance;

/// 正常的登录及订阅
/// @param ip 服务器ip
/// @param port 服务器端口
/// @param userName 用户名
/// @param password 密码
/// @param topic 订阅的主题，可以订阅的主题与账户是相关联的，例：@"mqtt/test" //前缀
/// @param will 遗嘱 断开链接的话发送的？
/// @param willQos MQ的会话等级
/// @param keepalive 保活确认时间
-(void)loginWithIp:(NSString *)ip port:(UInt16)port userName:(NSString *)userName password:(NSString *)password baseTopic:(NSString *)topic will:(NSData *)will willQos:(MQTTQosLevel)willQos keepalive:(NSInteger)keepalive propertyList:(NSString *)listPath;

///连接
-(void)connect;
///断开链接
-(void)disconnect;
///mqtt的连接状态
-(void)getMQTTConnectStatus:(MqttStatus)mqtt_statusCodeCallBack;

/// 设置需要监听的topic  @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param subTopics @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param dataDicCallBack 主题返回的数据  对应的json数据和topic
-(void)subTopicsWithDic:(NSDictionary *)subTopics withTopicCallBack:(MqttMassage)dataDicCallBack;

///移除需要处理的监听
/// @param udSubTopics @[@"topic1",@"topic2"]
-(void)unSubTopicsWithDic:(NSArray *)udSubTopics;

/// dataDicCallBack 主题返回的数据模型  对应的json数据和topic
-(void)topicDataCallBack:(MqttMassage)dataDicCallBack;

/// 给对应的topic发送数据
/// @param data 发送的数据
/// @param topic 操作的topic
-(void)senderData:(NSData *)data withTopic:(NSString *)topic;


@end

NS_ASSUME_NONNULL_END
