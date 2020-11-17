//
//  TestViewController1.m
//  MQTTChat
//
//  Created by FCNC05 on 2020/11/16.
//  Copyright © 2020 Owntracks. All rights reserved.
//

#import "TestViewController1.h"
#import "TestViewController2.h"
#import "DKMQTTCommunicationManager.h"
#import "MQTTTestModel1.h"

@interface TestViewController1 ()
@property(nonatomic,strong)UIButton *btn;
@end

@implementation TestViewController1

- (void)viewDidLoad {
    [super viewDidLoad];
    __weak typeof(self)weakSelf = self;
        [[DKMQTTCommunicationManager shareInstance] topicDataCallBack:^(id  _Nonnull dataModel, NSString * _Nonnull topic) {
            if ([dataModel isKindOfClass:[MQTTTestModel1 class]]) {
                MQTTTestModel1 *model = (MQTTTestModel1*)dataModel;
                NSLog(@"监听数据返回=-=-=-=-%@",model.msg);
                weakSelf.btn.backgroundColor = [UIColor yellowColor];
            }
        }];

    _btn = [UIButton buttonWithType:UIButtonTypeCustom];
    _btn.frame = CGRectMake(0, 100, 80, 80);
    _btn.backgroundColor = [UIColor redColor];
    [_btn addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
}
-(void)test
{
    TestViewController2 *vc = [TestViewController2 new];
    [self.navigationController pushViewController:vc animated:YES];
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
