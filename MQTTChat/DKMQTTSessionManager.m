//
//  DKMQTTSessionManager.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/16.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "DKMQTTSessionManager.h"
#import "MQTTCoreDataPersistence.h"
#import "MQTTLog.h"
#import "ReconnectTimer.h"
#import "ForegroundReconnection.h"
@interface DKMQTTSessionManager()

@property (nonatomic, readwrite) DKMQTTSessionManagerState state;
@property (nonatomic, readwrite) NSError *lastErrorCode;

@property (strong, nonatomic) ReconnectTimer *reconnectTimer;
@property (nonatomic) BOOL reconnectFlag;

@property (strong, nonatomic) MQTTSession *session;

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
@property (strong, nonatomic) MQTTSSLSecurityPolicy *securityPolicy;
@property (strong, nonatomic) NSArray *certificates;
@property (nonatomic) MQTTProtocolVersion protocolLevel;

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

#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX_DEFAULT 64.0
#define BACKGROUND_DISCONNECT_AFTER 8.0
@implementation DKMQTTSessionManager
- (DKMQTTSessionManager *)initWithPersistence:(BOOL)persistent
                              maxWindowSize:(NSUInteger)maxWindowSize
                                maxMessages:(NSUInteger)maxMessages
                                    maxSize:(NSUInteger)maxSize
                 maxConnectionRetryInterval:(NSTimeInterval)maxRetryInterval
                        connectInForeground:(BOOL)connectInForeground {
    self = [super init];

    [self updateState:DKMQTTSessionManagerStateStarting];
    self.internalSubscriptions = [[NSMutableDictionary alloc] init];
    self.effectiveSubscriptions = [[NSMutableDictionary alloc] init];

    self.persistent = persistent;
    self.maxWindowSize = maxWindowSize;
    self.maxSize = maxSize;
    self.maxMessages = maxMessages;
    self.reconnectTimer = [[ReconnectTimer alloc] initWithRetryInterval:RECONNECT_TIMER
                                                       maxRetryInterval:maxRetryInterval
                                                         reconnectBlock:^{
                                                             __weak DKMQTTSessionManager *weakSelf = self;
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

- (DKMQTTSessionManager *)initWithPersistence:(BOOL)persistent
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

- (instancetype)init {
    self = [self initWithPersistence:MQTT_PERSISTENT
                       maxWindowSize:MQTT_MAX_WINDOW_SIZE
                         maxMessages:MQTT_MAX_MESSAGES
                             maxSize:MQTT_MAX_SIZE
          maxConnectionRetryInterval:RECONNECT_TIMER_MAX_DEFAULT
                 connectInForeground:YES];
    return self;
}

- (DKMQTTSessionManager *)initWithPersistence:(BOOL)persistent
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

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
        willTopic:(NSString *)willTopic
             will:(NSData *)will
          willQos:(MQTTQosLevel)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId {
    [self connectTo:host
               port:port
                tls:tls
          keepalive:keepalive
              clean:clean
               auth:auth
               user:user
               pass:pass
               will:YES
          willTopic:willTopic
            willMsg:will
            willQos:willQos
     willRetainFlag:willRetainFlag
       withClientId:clientId];
}

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
             will:(BOOL)will
        willTopic:(NSString *)willTopic
          willMsg:(NSData *)willMsg
          willQos:(MQTTQosLevel)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId {
    [self connectTo:host
               port:port
                tls:tls
          keepalive:keepalive
              clean:clean
               auth:auth
               user:user
               pass:pass
               will:will
          willTopic:willTopic
            willMsg:willMsg
            willQos:willQos
     willRetainFlag:willRetainFlag
       withClientId:clientId
     securityPolicy:nil
       certificates:nil];
}

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
             will:(BOOL)will
        willTopic:(NSString *)willTopic
          willMsg:(NSData *)willMsg
          willQos:(MQTTQosLevel)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId
   securityPolicy:(MQTTSSLSecurityPolicy *)securityPolicy
     certificates:(NSArray *)certificates
protocolLevel:(MQTTProtocolVersion)protocolLevel {
    [self connectTo:host
               port:port
                tls:tls
          keepalive:keepalive
              clean:clean
               auth:auth
               user:user
               pass:pass
               will:will
          willTopic:willTopic
            willMsg:willMsg
            willQos:willQos
     willRetainFlag:willRetainFlag
       withClientId:clientId
     securityPolicy:securityPolicy
       certificates:certificates
      protocolLevel:protocolLevel
            runLoop:[NSRunLoop currentRunLoop]];
}

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
             will:(BOOL)will
        willTopic:(NSString *)willTopic
          willMsg:(NSData *)willMsg
          willQos:(MQTTQosLevel)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId
   securityPolicy:(MQTTSSLSecurityPolicy *)securityPolicy
     certificates:(NSArray *)certificates {
    [self connectTo:host
               port:port
                tls:tls
          keepalive:keepalive
              clean:clean
               auth:auth
               user:user
               pass:pass
               will:will
          willTopic:willTopic
            willMsg:willMsg
            willQos:willQos
     willRetainFlag:willRetainFlag
       withClientId:clientId
     securityPolicy:securityPolicy
       certificates:certificates
      protocolLevel:MQTTProtocolVersion311 // use this level as default, keeps it backwards compatible
            runLoop:[NSRunLoop currentRunLoop]];
}

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
             will:(BOOL)will
        willTopic:(NSString *)willTopic
          willMsg:(NSData *)willMsg
          willQos:(MQTTQosLevel)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId
   securityPolicy:(MQTTSSLSecurityPolicy *)securityPolicy
     certificates:(NSArray *)certificates
    protocolLevel:(MQTTProtocolVersion)protocolLevel
          runLoop:(NSRunLoop *)runLoop {
    DDLogVerbose(@"MQTTSessionManager connectTo:%@", host);
    BOOL shouldReconnect = self.session != nil;
    if (!self.session ||
        ![host isEqualToString:self.host] ||
        port != self.port ||
        tls != self.tls ||
        keepalive != self.keepalive ||
        clean != self.clean ||
        auth != self.auth ||
        ![user isEqualToString:self.user] ||
        ![pass isEqualToString:self.pass] ||
        ![willTopic isEqualToString:self.willTopic] ||
        ![willMsg isEqualToData:self.willMsg] ||
        willQos != self.willQos ||
        willRetainFlag != self.willRetainFlag ||
        ![clientId isEqualToString:self.clientId] ||
        securityPolicy != self.securityPolicy ||
        certificates != self.certificates ||
        runLoop != self.runLoop) {
        self.host = host;
        self.port = (int)port;
        self.tls = tls;
        self.keepalive = keepalive;
        self.clean = clean;
        self.auth = auth;
        self.user = user;
        self.pass = pass;
        self.will = will;
        self.willTopic = willTopic;
        self.willMsg = willMsg;
        self.willQos = willQos;
        self.willRetainFlag = willRetainFlag;
        self.clientId = clientId;
        self.securityPolicy = securityPolicy;
        self.certificates = certificates;
        self.protocolLevel = protocolLevel;
        self.runLoop = runLoop;

        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:auth ? user : nil
                                                    password:auth ? pass : nil
                                                   keepAlive:keepalive
                                                cleanSession:clean
                                                        will:will
                                                   willTopic:willTopic
                                                     willMsg:willMsg
                                                     willQoS:willQos
                                              willRetainFlag:willRetainFlag
                                               protocolLevel:protocolLevel
                                                     runLoop:runLoop
                                                     forMode:NSDefaultRunLoopMode
                                              securityPolicy:securityPolicy
                                                certificates:certificates];

        MQTTCoreDataPersistence *persistence = [[MQTTCoreDataPersistence alloc] init];

        persistence.persistent = self.persistent;
        persistence.maxWindowSize = self.maxWindowSize;
        persistence.maxSize = self.maxSize;
        persistence.maxMessages = self.maxMessages;

        self.session.persistence = persistence;

        self.session.delegate = self;
        self.reconnectFlag = FALSE;
    }
    if (shouldReconnect) {
        DDLogVerbose(@"[MQTTSessionManager] reconnecting");
        [self disconnect];
        [self reconnect];
    } else {
        DDLogVerbose(@"[MQTTSessionManager] connecting");
        [self connectToInternal];
    }
}

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(MQTTQosLevel)qos retain:(BOOL)retainFlag {
    if (self.state != DKMQTTSessionManagerStateConnected) {
        [self connectToLast];
    }
    UInt16 msgId = [self.session publishData:data
                                     onTopic:topic
                                      retain:retainFlag
                                         qos:qos publishHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"发送成功");
        }
        else{
            NSLog(@"发送失败");
        }
    }];
    return msgId;
}

- (void)disconnect {
    [self updateState:DKMQTTSessionManagerStateClosing];
    [self.session close];
    [self.reconnectTimer stop];
}

- (BOOL)requiresTearDown {
    return (self.state != DKMQTTSessionManagerStateClosed &&
            self.state != DKMQTTSessionManagerStateStarting);
}

- (void)updateState:(DKMQTTSessionManagerState)newState {
    self.state = newState;

    if ([self.delegate respondsToSelector:@selector(sessionManager:didChangeState:)]) {
        [self.delegate sessionManager:self didChangeState:newState];
    }
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
    DDLogVerbose(@"[MQTTSessionManager] eventCode: %@ (%ld) %@", events[@(eventCode)], (long)eventCode, error);
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

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid {
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(sessionManager:didReceiveMessage:onTopic:retained:)]) {
            [self.delegate sessionManager:self didReceiveMessage:data onTopic:topic retained:retained];
        }
        if ([self.delegate respondsToSelector:@selector(handleMessage:onTopic:retained:)]) {
            [self.delegate handleMessage:data onTopic:topic retained:retained];
        }
    }
}

- (void)connected:(MQTTSession *)session sessionPresent:(BOOL)sessionPresent {
    if (self.clean || !self.reconnectFlag || !sessionPresent) {
        NSDictionary *subscriptions = [self.internalSubscriptions copy];
        [self.subscriptionLock lock];
        self.effectiveSubscriptions = [[NSMutableDictionary alloc] init];
        [self.subscriptionLock unlock];
        if (subscriptions.count) {
            [self.session subscribeToTopics:subscriptions subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
                if (!error) {
                    NSArray<NSString *> *allTopics = subscriptions.allKeys;
                    for (int i = 0; i < allTopics.count; i++) {
                        NSString *topic = allTopics[i];
                        NSNumber *gQos = gQoss[i];
                        [self.subscriptionLock lock];
                        NSMutableDictionary *newEffectiveSubscriptions = [self.subscriptions mutableCopy];
                        newEffectiveSubscriptions[topic] = gQos;
                        self.effectiveSubscriptions = newEffectiveSubscriptions;
                        [self.subscriptionLock unlock];
                    }
                }
            }];

        }
        self.reconnectFlag = TRUE;
    }
}

- (void)messageDelivered:(MQTTSession *)session msgID:(UInt16)msgID {
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(sessionManager:didDeliverMessage:)]) {
            [self.delegate sessionManager:self didDeliverMessage:msgID];
        }
        if ([self.delegate respondsToSelector:@selector(messageDelivered:)]) {
            [self.delegate messageDelivered:msgID];
        }
    }
}


- (void)connectToInternal {
    if (self.session && self.state == DKMQTTSessionManagerStateStarting) {
        [self updateState:DKMQTTSessionManagerStateConnecting];
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

- (NSDictionary<NSString *, NSNumber *> *)subscriptions {
    return self.internalSubscriptions;
}

- (void)setSubscriptions:(NSDictionary<NSString *, NSNumber *> *)newSubscriptions {
    if (self.state == DKMQTTSessionManagerStateConnected) {
        NSDictionary *currentSubscriptions = [self.effectiveSubscriptions copy];

        for (NSString *topicFilter in currentSubscriptions) {
            if (!newSubscriptions[topicFilter]) {
                [self.session unsubscribeTopic:topicFilter unsubscribeHandler:^(NSError *error) {
                    if (!error) {
                        NSLog(@"取消订阅成功");
                        [self.subscriptionLock lock];
                        NSMutableDictionary *newEffectiveSubscriptions = [self.subscriptions mutableCopy];
                        [newEffectiveSubscriptions removeObjectForKey:topicFilter];
                        self.effectiveSubscriptions = newEffectiveSubscriptions;
                        [self.subscriptionLock unlock];
                    }
                }];
            }
        }

        for (NSString *topicFilter in newSubscriptions) {
            if (!currentSubscriptions[topicFilter]) {
                NSNumber *number = newSubscriptions[topicFilter];
                MQTTQosLevel qos = number.unsignedIntValue;
                [self.session subscribeToTopic:topicFilter atLevel:qos subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
                    if (!error) {
                        NSLog(@"订阅成功");
                        NSNumber *gQos = gQoss[0];
                        [self.subscriptionLock lock];
                        NSMutableDictionary *newEffectiveSubscriptions = [self.subscriptions mutableCopy];
                        newEffectiveSubscriptions[topicFilter] = gQos;
                        self.effectiveSubscriptions = newEffectiveSubscriptions;
                        [self.subscriptionLock unlock];
                    }
                }];
            }
        }
    }
    self.internalSubscriptions = newSubscriptions;
    DDLogVerbose(@"MQTTSessionManager internalSubscriptions: %@", self.internalSubscriptions);
}


/// 设置需要监听的topic  @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param subTopics @{@"Nsstring":NSNumber,@"Nsstring":NSNumber]}
/// @param dataDicCallBack 主题返回的数据  对应的json数据和topic
-(void)subTopicsWithDic:(NSDictionary *)subTopics withTopicCallBack:(DKMQTTSubscribeHandler)dataDicCallBack {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.session subscribeToTopics:subTopics subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
                if (!error) {//被用掉了
                    NSLog(@"发送成功");
                }
                else{
                    NSLog(@"发送失败");
                }
            }];
        });
    });


}

///移除需要处理的监听
/// @param udSubTopics @[@"topic1",@"topic2"]
-(void)unSubTopicsWithArr:(NSArray *)udSubTopics withTopicCallBack:(DKMQTTUnsubscribeHandler)dataDicCallBack{
    [self.session unsubscribeTopics:udSubTopics unsubscribeHandler:^(NSError *error) {
        if (!error) {
            NSLog(@"发送成功");
        }
        else{
            NSLog(@"发送失败");
        }
    }];
}


-(void)subAckReceived:(MQTTSession *)session msgID:(UInt16)msgID grantedQoss:(NSArray<NSNumber *> *)qoss{

}
- (void)received:(MQTTSession *)session type:(MQTTCommandType)type qos:(MQTTQosLevel)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data{

}
- (void)messageDelivered:(MQTTSession *)session
                   msgID:(UInt16)msgID
                   topic:(NSString *)topic
                    data:(NSData *)data
                     qos:(MQTTQosLevel)qos
              retainFlag:(BOOL)retainFlag{

}
- (void)sending:(MQTTSession *)session type:(MQTTCommandType)type qos:(MQTTQosLevel)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data{

}
@end
