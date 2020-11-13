//
//  DKMQTTCommunicationManager.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/11.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "DKMQTTCommunicationManager.h"
#import "YYModel.h"
//#import "MQTTTestModel.h"
//#import "MQTTTestModel1.h"
#import "DKMQTTDataReceicveManager.h"
#import <UIKit/UIDevice.h>

@interface DKMQTTCommunicationManager ()<MQTTSessionManagerDelegate>
/*
 * MQTTClient: keep a strong reference to your MQTTSessionManager here
 */
@property (strong, nonatomic) MQTTSessionManager *manager;

@property (strong, nonatomic)  NSMutableDictionary *currentTopicDic;

@end

/// <#Description#>
@implementation DKMQTTCommunicationManager

#pragma mark 懒加载
-(MQTTSessionManager *)manager{
    if (!_manager) {
        _manager = [[MQTTSessionManager alloc] init];
        _manager.delegate = self;
    }
    return _manager;
}
#pragma mark 对外方法
/**
 单例

 @return self
 */
+(DKMQTTCommunicationManager *)shareInstance{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance=[[self alloc] init];
    });
    return instance;
}

/// 正常的登录及订阅
/// @param ip 服务器ip
/// @param port 服务器端口
/// @param userName 用户名
/// @param password 密码
/// @param topic 订阅的主题，可以订阅的主题与账户是相关联的，例：@"mqtt/test" //前缀
/// @param will 遗嘱 断开链接的话发送的？
/// @param willQos MQ的会话等级
/// @param keepalive 保活确认时间
/// @param listPath topicsList
-(void)loginWithIp:(NSString *)ip port:(UInt16)port userName:(NSString *)userName password:(NSString *)password baseTopic:(NSString *)topic will:(NSData *)will willQos:(MQTTQosLevel)willQos keepalive:(NSInteger)keepalive propertyList:(NSString *)listPath{

//数据准备
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *mqttPlistUrl = [bundleURL URLByAppendingPathComponent:listPath];
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfURL:mqttPlistUrl];
    self.currentTopicDic = [NSMutableDictionary dictionaryWithDictionary:dic];


    self.manager.subscriptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:willQos]
                                                             forKey:[NSString stringWithFormat:@"%@/#", topic]];
    [self.manager connectTo:ip
                       port:port
                        tls:NO
                  keepalive:keepalive
                      clean:true
                       auth:false
                       user:userName
                       pass:password
                  willTopic:topic
                       will:will
                    willQos:willQos
             willRetainFlag:FALSE
               withClientId:nil];//如果需要的话
    //NSString *clientID=[NSString stringWithFormat:@"%@|iOS|%@",[[NSBundle mainBundle] bundleIdentifier],[UIDevice currentDevice].identifierForVendor.UUIDString];
    
    [self.manager addObserver:self
                   forKeyPath:@"state"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];

}
//监听状态回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    switch (self.manager.state) {
        case MQTTSessionManagerStateClosed:
            self.statusCodeCallBack(@"连接关闭完成");
            break;
        case MQTTSessionManagerStateClosing:
            self.statusCodeCallBack(@"连接关闭中");
            break;
        case MQTTSessionManagerStateConnected:
            self.statusCodeCallBack(@"连接完成");
            break;
        case MQTTSessionManagerStateConnecting:
            self.statusCodeCallBack(@"连接开始");
            break;
        case MQTTSessionManagerStateError:
            self.statusCodeCallBack(@"连接错误");
            break;
        case MQTTSessionManagerStateStarting:
        default:
            self.statusCodeCallBack(@"连接开始");
            break;
    }
}
-(void)connect{
    /*
     * MQTTClient: connect to same broker again
     */

    [self.manager connectToLast];
}
-(void)disconnect{
    /*
     * MQTTClient: send goodby message and gracefully disconnect
     */
    [self.manager sendData:[@"leaves chat" dataUsingEncoding:NSUTF8StringEncoding]
                     topic:@""
                       qos:MQTTQosLevelExactlyOnce
                    retain:FALSE];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.manager disconnect];
}
///mqtt的连接状态
-(void)getMQTTConnectStatus:(MqttStatus)statusCodeCallBack{
    self.statusCodeCallBack = statusCodeCallBack;
}
/// 设置需要监听的topic  @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param subTopics @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
-(void)subTopicsWithDic:(NSDictionary *)subTopics withTopicCallBack:(MqttMassage)dataDicCallBack{
    self.dataDicCallBack = dataDicCallBack;
    [self.manager.session subscribeToTopics:subTopics];
}

///移除需要处理的监听
/// @param udSubTopics @[@"topic1",@"topic2"]
-(void)unSubTopicsWithDic:(NSArray *)udSubTopics{
    [self.manager.session unsubscribeTopics:udSubTopics];
}

/// 给对应的topic发送数据
/// @param data 发送的数据
/// @param topic 操作的topic
-(void)senderData:(NSData *)data withTopic:(NSString *)topic{
    /*
     * MQTTClient: send data to broker
     */
    //需要定义一个id 来确定是同一条数据发送 并且做定时器的超时判断
    [self.manager sendData:data//[self.message.text dataUsingEncoding:NSUTF8StringEncoding]
                     topic:topic
                       qos:MQTTQosLevelExactlyOnce
                    retain:FALSE];
}

/*
 * MQTTSessionManagerDelegate
 */
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    /*
     * MQTTClient: process received message
     */
    //转字符串
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //转字典
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    NSObject *objc;
    //self.currentTopicDic。plist文件中的属性表数据
    if (self.currentTopicDic.count > 0 && self.currentTopicDic[topic]) {
        //字符串转类
        Class cls = NSClassFromString(self.currentTopicDic[topic]);
        objc = [[cls alloc] init];
        //字典转模型
        BOOL status = [objc yy_modelSetWithDictionary:dic];
        if (status == NO) {
            return;
        }
    }
    if (objc != nil) {//解析模型成功
        //将最新的模型数据存储到本地
        [[DKMQTTDataReceicveManager shareManager].mqttTopicsDatas setObject:objc forKey:topic];
        //将最新的模型数据抛出去
        self.dataDicCallBack(objc,topic);
    }

}

/// 需要监听数据模型的返回
/// @param dataDicCallBack 模型 和 主题
-(void)topicDataCallBack:(MqttMassage)dataDicCallBack{
    self.dataDicCallBack = dataDicCallBack;
}

@end
