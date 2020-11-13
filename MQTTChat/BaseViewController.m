//
//  BaseViewController.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/12.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "BaseViewController.h"
#import "DKMQTTDataReceicveManager.h"
#import "ChatCell.h"
#import "DKMQTTCommunicationManager.h"
#import "MQTTTestModel.h"
#import "Masonry.h"
@interface BaseViewController ()<UITextFieldDelegate>
@property(nonatomic,strong)UITextField *textF;
@property (strong, nonatomic) DKMQTTCommunicationManager *mqManager;
@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *mqttPlistUrl = [bundleURL URLByAppendingPathComponent:@"mqtt.plist"];
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfURL:mqttPlistUrl];

    self.view.backgroundColor = [UIColor redColor];
    UILabel *lab = [[UILabel alloc]init];
    lab.text = @"Chat";
    [self.view addSubview:lab];

    [lab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(80);
        make.left.mas_equalTo(20);
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(40);
    }];


    NSArray *dataArr = @[@"Clear",@"Connect",@"Disconnect"];
    for (int i = 0; i<dataArr.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width-20 -(i+1)*80, 80, 80, 30);
        btn.titleLabel.font = [UIFont systemFontOfSize:13];
        //btn.center = CGPointMake(btn.center.x, lab.center.y);
        [btn setTitle:dataArr[i] forState:UIControlStateNormal];
        btn.tag = 100 + 1;
        [btn addTarget:self action:@selector(clickAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];

    }

    _textF = [[UITextField alloc]init];
    _textF.delegate = self;
    _textF.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_textF];

    [_textF mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(lab.mas_bottom).offset(10);
        make.left.mas_equalTo(20);
        make.width.mas_equalTo([UIScreen mainScreen].bounds.size.width-20-60-10);
        make.height.mas_equalTo(40);
    }];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [sendBtn setTitle:@"send" forState:UIControlStateNormal];
    sendBtn.tag = 200;
    [sendBtn addTarget:self action:@selector(clickAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sendBtn];

    [sendBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(lab.mas_bottom).offset(10);
        make.left.mas_equalTo(_textF.mas_right).offset(10);
        make.width.mas_equalTo(60);
        make.height.mas_equalTo(40);
    }];


    _mqManager = [DKMQTTCommunicationManager shareInstance];
    [_mqManager loginWithIp:dic[@"host"] port:[dic[@"port"] intValue] userName:dic[@"user"] password:dic[@"password"] baseTopic:dic[@"base"] will:[@"offline" dataUsingEncoding:NSUTF8StringEncoding] willQos:MQTTQosLevelExactlyOnce keepalive:20 propertyList:@"topicsModle.plist"];

    __weak typeof(self)weakself = self;
    [_mqManager subTopicsWithDic:@{@"MQTTChat/testtopic/text1":[NSNumber numberWithInt:MQTTQosLevelExactlyOnce],@"MQTTChat/text1":[NSNumber numberWithInt:MQTTQosLevelExactlyOnce]} withTopicCallBack:^(id _Nonnull dataModel, NSString * _Nonnull topic) {


        if ([dataModel isKindOfClass:[MQTTTestModel class]]) {
                    MQTTTestModel *model = (MQTTTestModel*)dataModel;
                    NSLog(@"监听数据返回=-=-=-=-%@",model.msg);
                }
//        NSLog(@"返回的topic -- is --%@----json数据%@",topic,dataDic);
//        [weakself.chat insertObject:[NSString stringWithFormat:@"%@\n%@",topic,dataDic[@"msg"]] atIndex:0];
//        [weakself.tableView reloadData];
    }];

    [_mqManager getMQTTConnectStatus:^(NSString *code) {
                NSLog(@"连接=========%@",code);
    }];


    
//    NSLog(@"本地数据获取%@",[DKMQTTDataReceicveManager shareManager].mqttTopicsDatas[@"MQTTChat/testtopic/text1"]);
//    [[DKMQTTCommunicationManager shareInstance] topicDataCallBack:^(id  _Nonnull dataModel, NSString * _Nonnull topic) {
//        if ([dataModel isKindOfClass:[MQTTTestModel class]]) {
//            MQTTTestModel *model = (MQTTTestModel*)dataModel;
//            NSLog(@"监听数据返回=-=-=-=-%@",model.msg);
//        }
//        }];

}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_textF resignFirstResponder];
    return YES;
}
-(void)clickAction:(UIButton *)sender{
    NSLog(@"监听数据返回=-=-=-=-");
    if (sender.tag == 100) {

    }
    else if(sender.tag == 101){

    }
    else if (sender.tag == 102){

    }
    else if (sender.tag == 200){

    }
}
@end
