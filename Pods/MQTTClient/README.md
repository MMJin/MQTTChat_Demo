MQTT-Client-Framework 
=====================

an Objective-C native MQTT Framework http://mqtt.org

### Tested with a long list of brokers

* mosquitto
* paho
* rabbitmq
* hivemq
* rsmb
* mosca
* vernemq
* emqtt
* moquette
* ActiveMQ
* Apollo
* CloudMQTT
* aws
* hbmqtt (MQTTv311 only, limitations)
* [aedes](https://github.com/mcollina/aedes) 

### As a CocoaPod

Use the CocoaPod MQTTClient! 

Add this to your Podfile:

```
pod 'MQTTClient'
```
which is a short for
```
pod 'MQTTClient/Min'
pod 'MQTTClient/Manager'
```

The Manager subspec includes the MQTTSessionManager class.

Additionally add this subspec if you want to use MQTT over Websockets:

```
pod 'MQTTClient/Websocket'
```

If you want to do your logging with CocoaLumberjack (my suggestion), use
```
pod 'MQTTClient/MinL'
pod 'MQTTClient/ManagerL'
pod 'MQTTClient/WebsocketL'
```
instead.

### As a dynamic library

Or use the dynamic library created in the MQTTFramework target.

### As source

Or include the source from here.

### With Carthage

[Carthage](https://github.com/Carthage/Carthage)
```
github "ckrey/MQTT-Client-Framework"
```

### docs

Documentation generated with doxygen http://doxygen.org in the `./MQTTClient/dist/documentation` subdirectory.

Here is the [PDF](MQTTClient/dist/documentation/latex/refman.pdf).

You may open the HTML version of the documentation here  [index.html](MQTTClient/dist/documentation/html/index.html)

Run `make install` in the `./MQTTClient/dist/documentation/html` subdirectory to install the the documentation as a DOCSET on your Mac.

### Usage

Create a new client and connect to a broker:

```objective-c
#import "MQTTClient.h"

\@interface MyDelegate : ... <MQTTSessionDelegate>
...

        MQTTCFSocketTransport *transport = [[MQTTCFSocketTransport alloc] init];
        transport.host = @"localhost";
        transport.port = 1883;

        MQTTSession *session = [[MQTTSession alloc] init];
        session.transport = transport;
        
	session.delegate = self;

	[session connectAndWaitTimeout:30];  //this is part of the synchronous API

```

Subscribe to a topic:

```objective-c
[session subscribeToTopic:@"example/#" atLevel:2 subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss){
    if (error) {
        NSLog(@"Subscription failed %@", error.localizedDescription);
    } else {
        NSLog(@"Subscription sucessfull! Granted Qos: %@", gQoss);
    }
 }]; // this is part of the block API

```

Add the following to receive messages for the subscribed topics
```objective-c
 - (void)newMessage:(MQTTSession *)session
	data:(NSData *)data
	onTopic:(NSString *)topic
	qos:(MQTTQosLevel)qos
	retained:(BOOL)retained
	mid:(unsigned int)mid {
	// this is one of the delegate callbacks
}
```

Publish a message to a topic:

```objective-c
[session publishAndWaitData:data
                    onTopic:@"topic"
                     retain:NO
	                qos:MQTTQosLevelAtLeastOnce]; // this is part of the asynchronous API
```




### Comparison MQTT Clients for iOS (incomplete)

|Wrapper|---|----|MQTTKit  |Marquette|Moscapsule|Musqueteer|MQTT-Client|MqttSDK|CocoaMQTT|
|-------|---|----|---------|---------|----------|----------|-----------|-------|---------|
|       |   |    |Obj-C    |Obj-C    |Swift     |Obj-C     |Obj-C      |Obj-C  |Swift    |
|Library|IBM|Paho|Mosquitto|Mosquitto|Mosquitto |Mosquitto |native     |native |native   |


