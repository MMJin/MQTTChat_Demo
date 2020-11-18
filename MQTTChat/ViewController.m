
//
//  ViewController.m
//  MQTTChat
//
//  Created by Christoph Krey on 12.07.15.
//  Copyright (c) 2015-2016 Owntracks. All rights reserved.
//

#import "ViewController.h"
#import "ChatCell.h"
#import "DKMQTTCommunicationManager.h"
#import "BaseViewController.h"
#import "MQTTTestModel.h"

@interface ViewController ()
/*
 * MQTTClient: keep a strong reference to your MQTTSessionManager here
 */
@property (strong, nonatomic) MQTTSessionManager *manager;

@property (strong, nonatomic) DKMQTTCommunicationManager *mqManager;


@property (strong, nonatomic) NSDictionary *mqttSettings;
@property (strong, nonatomic) NSMutableArray *chat;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UITextField *message;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSString *base;
@property (weak, nonatomic) IBOutlet UIButton *connect;
@property (weak, nonatomic) IBOutlet UIButton *disconnect;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *mqttPlistUrl = [bundleURL URLByAppendingPathComponent:@"mqtt.plist"];
    self.mqttSettings = [NSDictionary dictionaryWithContentsOfURL:mqttPlistUrl];
    self.base = self.mqttSettings[@"base"];

    self.chat = [[NSMutableArray alloc] init];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.estimatedRowHeight = 150;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    self.message.delegate = self;


    _mqManager = [DKMQTTCommunicationManager shareInstance];
//    [_mqManager loginWithIp:self.mqttSettings[@"host"] port:[self.mqttSettings[@"port"] intValue] userName:self.mqttSettings[@"user"] password:self.mqttSettings[@"password"] baseTopic:[NSString stringWithFormat:@"%@",self.base] will:[@"offline" dataUsingEncoding:NSUTF8StringEncoding] willQos:MQTTQosLevelExactlyOnce keepalive:20 propertyList:@"topicsModle.plist"];
    
    __weak typeof(self)weakself = self;
    [_mqManager subTopicsWithDic:@{@"MQTTChat/testtopic/text1":[NSNumber numberWithInt:MQTTQosLevelExactlyOnce],@"MQTTChat/text1":[NSNumber numberWithInt:MQTTQosLevelExactlyOnce]} withTopicCallBack:^(NSDictionary * _Nonnull dataDic, NSString * _Nonnull topic) {

//        NSLog(@"返回的topic -- is --%@----json数据%@",topic,dataDic);
//        [weakself.chat insertObject:[NSString stringWithFormat:@"%@\n%@",topic,dataDic[@"msg"]] atIndex:0];
//        [weakself.tableView reloadData];
    }];

//    [_mqManager getMQTTConnectStatus:^(MQTTConnectState code) {
//        switch (code) {
//            case MQTTConnectStarting:
//                NSLog(@"连接开始");
//                break;
//            case MQTTConnectConnecting:
//                NSLog(@"连接中");
//                break;
//            case MQTTConnectConnected:
//                NSLog(@"连接开始");
//                break;
//            case MQTTConnectClosing:
//                NSLog(@"连接关闭中");
//                break;
//            case MQTTConnectClosed:
//                NSLog(@"连接关闭完成");
//                break;
//            default:
//                break;
//        }
//    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)clear:(id)sender {
    [self.chat removeAllObjects];
    [self.tableView reloadData];
}
- (IBAction)connect:(id)sender {
    /*
     * MQTTClient: connect to same broker again
     */
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    BaseViewController *vc = [[BaseViewController alloc]init];
    UINavigationController *nav = [[UINavigationController alloc]initWithRootViewController:vc];
    window.rootViewController = nav;
    [window makeKeyWindow];
   // [nav pushViewController:vc animated:YES];

}



- (IBAction)send:(id)sender {
    /*
     * MQTTClient: send data to broker
     */
    [_mqManager senderData:[@"哈哈哈" dataUsingEncoding:NSUTF8StringEncoding] withTopic:@"MQTTChat/testtopic/text1"];
}

/*
 * MQTTSessionManagerDelegate
 */
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    /*
     * MQTTClient: process received message
     */

    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *senderString = [topic substringFromIndex:self.base.length];

    [self.chat insertObject:[NSString stringWithFormat:@"%@:\n%@", senderString, dataString] atIndex:0];
    [self.tableView reloadData];
}

/*
 * UITableViewDelegate
 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"line"];
    cell.settingText.text = self.chat[indexPath.row];
    return cell;
}

/*
 * UITableViewDataSource
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chat.count;
}

@end
