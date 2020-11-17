//
//  TestViewController2.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/16.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "TestViewController2.h"
#import "DKMQTTCommunicationManager.h"
#import "MQTTTestModel1.h"
@interface TestViewController2 ()

@end

@implementation TestViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    [[DKMQTTCommunicationManager shareInstance] topicDataCallBack:^(id  _Nonnull dataModel, NSString * _Nonnull topic) {
        if ([dataModel isKindOfClass:[MQTTTestModel1 class]]) {
            MQTTTestModel1 *model = (MQTTTestModel1*)dataModel;
            NSLog(@"监听数据返回444=-=-=-=-%@",model.msg);
        }
        }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
