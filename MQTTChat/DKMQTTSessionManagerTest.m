//
//  DKMQTTSessionManagerTest.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/17.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "DKMQTTSessionManagerTest.h"
#import "MQTTClient.h"
#import "DKMQTTDataReceicveManager.h"
#import "YYModel.h"
#import "ForegroundReconnection.h"
#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX_DEFAULT 64.0
#define BACKGROUND_DISCONNECT_AFTER 8.0

typedef NS_ENUM(int, DKMQTTSessionManagerState) {
    DKMQTTSessionManagerStateStarting,
    DKMQTTSessionManagerStateConnecting,
    DKMQTTSessionManagerStateError,
    DKMQTTSessionManagerStateConnected,
    DKMQTTSessionManagerStateClosing,
    DKMQTTSessionManagerStateClosed
};

@interface DKMQTTSessionManagerTest()<MQTTSessionDelegate>
@property(nonatomic,strong)MQTTSession *session;
//当前控制器监听的topic
@property (strong, nonatomic)  NSMutableDictionary *currentTopicDic;

/** SessionManager status
 */
@property (nonatomic, readwrite) DKMQTTSessionManagerState state;
@property (nonatomic, readwrite) NSError *lastErrorCode;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL tls;
@property (nonatomic) NSInteger keepalive;
@property (nonatomic) BOOL clean;
@property (nonatomic) BOOL auth;
@property (nonatomic) BOOL will;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;
@property (strong, nonatomic) NSString *willTopic;
@property (strong, nonatomic) NSData *willMsg;
@property (nonatomic) NSInteger willQos;
@property (nonatomic) BOOL willRetainFlag;
@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) NSRunLoop *runLoop;

#if TARGET_OS_IPHONE == 1
@property (strong, nonatomic) ForegroundReconnection *foregroundReconnection;
#endif

@property (nonatomic) BOOL persistent;
@property (nonatomic) NSUInteger maxWindowSize;
@property (nonatomic) NSUInteger maxSize;
@property (nonatomic) NSUInteger maxMessages;

@property (strong, nonatomic) NSDictionary<NSString *, NSNumber *> *internalSubscriptions;
@property (strong, nonatomic) NSDictionary<NSString *, NSNumber *> *effectiveSubscriptions;
@property (strong, nonatomic) NSLock *subscriptionLock;

@end
@implementation DKMQTTSessionManagerTest
-(MQTTSession *)session{
    if (!_session) {
        _session = [[MQTTSession alloc] init];
        _session.delegate = self;
    }
    return _session;
}
+(DKMQTTSessionManagerTest *)shareInstance{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance=[[self alloc] init];
    });
    return instance;
}
- (instancetype)init {
    self = [self initWithPersistence:MQTT_PERSISTENT
                       maxWindowSize:MQTT_MAX_WINDOW_SIZE
                         maxMessages:MQTT_MAX_MESSAGES
                             maxSize:MQTT_MAX_SIZE
          maxConnectionRetryInterval:RECONNECT_TIMER_MAX_DEFAULT
                 connectInForeground:YES];
    return self;
}
- (DKMQTTSessionManagerTest *)initWithPersistence:(BOOL)persistent
                              maxWindowSize:(NSUInteger)maxWindowSize
                                maxMessages:(NSUInteger)maxMessages
                                    maxSize:(NSUInteger)maxSize {
    self = [self initWithPersistence:persistent
                       maxWindowSize:maxWindowSize
                         maxMessages:maxMessages
                             maxSize:maxSize
          maxConnectionRetryInterval:RECONNECT_TIMER_MAX_DEFAULT
                 connectInForeground:YES];
    return self;
}
- (DKMQTTSessionManagerTest *)initWithPersistence:(BOOL)persistent
                               maxWindowSize:(NSUInteger)maxWindowSize
                                 maxMessages:(NSUInteger)maxMessages
                                     maxSize:(NSUInteger)maxSize
                  maxConnectionRetryInterval:(NSTimeInterval)maxRetryInterval
                         connectInForeground:(BOOL)connectInForeground {
     self = [super init];

    // [self updateState:MQTTSessionManagerStateStarting];
     self.internalSubscriptions = [[NSMutableDictionary alloc] init];
     self.effectiveSubscriptions = [[NSMutableDictionary alloc] init];

     self.persistent = persistent;
     self.maxWindowSize = maxWindowSize;
     self.maxSize = maxSize;
     self.maxMessages = maxMessages;
     self.reconnectTimer = [[ReconnectTimer alloc] initWithRetryInterval:RECONNECT_TIMER
                                                        maxRetryInterval:maxRetryInterval
                                                          reconnectBlock:^{
                                                              __weak DKMQTTSessionManagerTest *weakSelf = self;
                                                              [weakSelf reconnect];
                                                          }];
 #if TARGET_OS_IPHONE == 1
     if (connectInForeground) {
         self.foregroundReconnection = [[ForegroundReconnection alloc] initWithMQTTSessionManager:self];
     }
 #endif
     self.subscriptionLock = [[NSLock alloc] init];

     return self;
 }

 - (DKMQTTSessionManagerTest *)initWithPersistence:(BOOL)persistent
                               maxWindowSize:(NSUInteger)maxWindowSize
                                 maxMessages:(NSUInteger)maxMessages
                                     maxSize:(NSUInteger)maxSize
                         connectInForeground:(BOOL)connectInForeground {
     self = [self initWithPersistence:persistent
                        maxWindowSize:maxWindowSize
                          maxMessages:maxMessages
                              maxSize:maxSize
           maxConnectionRetryInterval:RECONNECT_TIMER_MAX_DEFAULT
                  connectInForeground:connectInForeground];
     return self;
 }
- (void)connectToInternal {
    if (self.session && self.session.status == DKMQTTSessionManagerStateStarting) {
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
    }
}

- (void)reconnect {
    [self updateState:DKMQTTSessionManagerStateStarting];
    [self connectToInternal];
}

- (void)connectToLast {
    if (self.state == DKMQTTSessionManagerStateConnected) {
        return;
    }
    [self.reconnectTimer resetRetryInterval];
    [self reconnect];
}
- (void)triggerDelayedReconnect {
    [self.reconnectTimer schedule];
}


-(void)connectedWithHost:(NSString *)host port:(NSInteger)port userName:(NSString *)userName password:(NSString *)password mqttStatus:(MqttStatus)status{
    //数据准备 self.currentTopicDic 管理需要存入本地的topic 还有当前页面需要监听的topic数据
    self.currentTopicDic = [NSMutableDictionary new];
    self.globalTopicDic = [NSMutableDictionary new];
    //mqtt链接状态判断
    self.statusCodeCallBack = status;
    
    MQTTCFSocketTransport *transport = [[MQTTCFSocketTransport alloc]init];
    transport.host = host;
    transport.port = (UInt32)port;
    self.host = host;
    self.port = (UInt32)port;

    self.session.transport = transport;
    self.session.userName = userName;
    self.session.password = password;
    [self.session connectAndWaitTimeout:1];

    [self.session connect];



    //监听stata 的状态
    [self.session addObserver:self
                   forKeyPath:@"status"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];
}

-(void)disconnect{
    /*
     * MQTTClient: send goodby message and gracefully disconnect
     */
    [self.session publishData:[@"leaves chat" dataUsingEncoding:NSUTF8StringEncoding] onTopic:@""  retain:NO qos:1 publishHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"发送成功");
        }
        else{
            NSLog(@"发送失败");
        }
    }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.session disconnect];
}

//监听状态回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    switch (self.session.status) {
        case MQTTSessionStatusClosed:
            self.statusCodeCallBack(@"连接关闭完成");
            [self.session connect];
            break;
        case MQTTSessionStatusDisconnecting:
            self.statusCodeCallBack(@"连接关闭中");
            break;
        case MQTTSessionStatusConnected:
            self.statusCodeCallBack(@"连接完成");
            break;
        case MQTTSessionStatusConnecting:
            self.statusCodeCallBack(@"连接中");
            break;
        case MQTTSessionStatusError:
            self.statusCodeCallBack(@"连接错误");
            break;
        case MQTTSessionStatusCreated:
        default:
            self.statusCodeCallBack(@"无连接");
            break;
    }
}
-(void)subTopicsWithDic:(NSDictionary *)subTopics WithDicModel:(NSDictionary *)subTopicModels withTopicCallBack:(MqttMassage)dataDicCallBack mqttStatus:(MqttStatus)status{
    self.dataDicCallBack = dataDicCallBack;
    __weak typeof(self)weakSelf = self;
    [self.currentTopicDic setValuesForKeysWithDictionary:subTopicModels];//可以处理为订阅成功再加
    self.statusCodeCallBack = status;
    [self.session subscribeToTopics:subTopics subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
        if (!error) {
            NSLog(@"多主题订阅成功");
        }
        else{
            NSLog(@"多主题订阅失败");
        }
    }];
}
-(void)subTopic:(NSDictionary *)topic withTopicCallBack:(MqttMassage)dataDicCallBack mqttStatus:(MqttStatus)status{
    self.dataDicCallBack = dataDicCallBack;
    NSArray *key = topic.allKeys;
    [self.currentTopicDic setValuesForKeysWithDictionary:topic];//可以处理为订阅成功再加
    self.statusCodeCallBack = status;
    __weak typeof(self)weakSelf = self;
    [self.session subscribeToTopic:key[0] atLevel:1 subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
        if (!error) {
            NSLog(@"单个订阅成功");
            weakSelf.statusCodeCallBack(@"单个订阅成功");
        }
        else{
            NSLog(@"单个订阅失败");
            weakSelf.statusCodeCallBack(@"单个订阅失败");
        }
    }];

};
-(void)unsubTopic:(NSString *)topic mqttStatus:(MqttStatus)status{
    
    __weak typeof(self)weakSelf = self;
    self.statusCodeCallBack = status;
    [self.session unsubscribeTopic:topic unsubscribeHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"取消单个订阅成功");
            weakSelf.statusCodeCallBack(@"取消单个订阅成功");
        }
        else{
            NSLog(@"取消单个订阅失败");
            weakSelf.statusCodeCallBack(@"取消单个订阅失败");
        }
    }];
}
-(void)unSubTopicsWithDic:(NSArray *)udSubTopics mqttStatus:(MqttStatus)status{
    __weak typeof(self)weakSelf = self;
    self.statusCodeCallBack = status;
    [self.session unsubscribeTopics:udSubTopics unsubscribeHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"取消多个订阅成功");
        }
        else{
            NSLog(@"取消多个订阅失败");
        }
    }];
}

-(void)senderData:(NSData *)data withTopic:(NSString *)topic{
    if (self.state != DKMQTTSessionManagerStateConnected) {
        [self connectToLast];
    }
    [self.session publishData:data onTopic:topic retain:NO qos:1 publishHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"发送成功");
        }
        else{
            NSLog(@"发送失败");
        }
    }];
}
#pragma mark - MQTT Callback methods

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error {
#ifdef DEBUG
    __unused const NSDictionary *events = @{
                                            @(MQTTSessionEventConnected): @"connected",
                                            @(MQTTSessionEventConnectionRefused): @"connection refused",
                                            @(MQTTSessionEventConnectionClosed): @"connection closed",
                                            @(MQTTSessionEventConnectionError): @"connection error",
                                            @(MQTTSessionEventProtocolError): @"protocoll error",
                                            @(MQTTSessionEventConnectionClosedByBroker): @"connection closed by broker"
                                            };
   // DDLogVerbose(@"[MQTTSessionManager] eventCode: %@ (%ld) %@", events[@(eventCode)], (long)eventCode, error);
#endif
    switch (eventCode) {
        case MQTTSessionEventConnected:
            self.lastErrorCode = nil;
            [self updateState:DKMQTTSessionManagerStateConnected];
            [self.reconnectTimer resetRetryInterval];
            break;

        case MQTTSessionEventConnectionClosed:
            [self updateState:DKMQTTSessionManagerStateClosed];
            break;

        case MQTTSessionEventConnectionClosedByBroker:
            if (self.state != DKMQTTSessionManagerStateClosing) {
                [self triggerDelayedReconnect];
            }
            [self updateState:DKMQTTSessionManagerStateClosed];
            break;

        case MQTTSessionEventProtocolError:
        case MQTTSessionEventConnectionRefused:
        case MQTTSessionEventConnectionError:
            [self triggerDelayedReconnect];
            self.lastErrorCode = error;
            [self updateState:DKMQTTSessionManagerStateError];
            break;

        default:
            break;
    }
}
- (void)updateState:(DKMQTTSessionManagerState)newState {
    self.state = newState;
}
-(void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid{
    NSLog(@"闪电鞭%@",topic);
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
    if (1) {//是否要存到本地

    }
    if (objc != nil) {//解析模型成功
        //将最新的模型数据存储到本地
        [[DKMQTTDataReceicveManager shareManager].mqttTopicsDatas setObject:objc forKey:topic];
        //将最新的模型数据抛出去
        self.dataDicCallBack(objc,topic);
    }
}
@end
