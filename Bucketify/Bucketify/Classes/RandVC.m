//
//  RandVC.m
//  Bucketify
//
//  Created by Christopher Loessl on 21/02/14.
//  Copyright (c) 2014 Christopher Loessl. All rights reserved.
//

#import "RandVC.h"

@interface RandVC ()

@property (weak, nonatomic) IBOutlet UIButton *buttonGo;
@property (weak, nonatomic) IBOutlet UILabel *labelStatus;

@end

@implementation RandVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action

- (IBAction)buttonGo:(UIButton *)sender {
}


@end
