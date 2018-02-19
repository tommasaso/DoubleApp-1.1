//
//  ViewController.h
//  DoubleAssignment
//
//  Created by Tommaso Elia on 03/02/18.
//  Copyright © 2018 DoubleTeam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SpeechSDK/SpeechRecognitionService.h"
#import <SpeechSDK/SpeechRecognitionService.h>
#import <DoubleControlSDK/DoubleControlSDK.h>

@interface ViewController : UIViewController <SpeechRecognitionProtocol>
{
//    NSMutableString * textOnScreen;
    MicrophoneRecognitionClient* micClient;
}

//@property(nonatomic, strong) IBOutlet UNIVERSAL_TEXTVIEW* quoteText;
@property (weak, nonatomic) IBOutlet UILabel* headerText;
@property (weak, nonatomic) IBOutlet UILabel* myResultsLabel;
@property (weak, nonatomic) IBOutlet UILabel* myIntentsLabel;
@property (weak, nonatomic) IBOutlet UILabel* myEntitiesLabel;

@property(nonatomic, strong) IBOutlet UNIVERSAL_BUTTON* startRecButton;
@property(nonatomic, strong) IBOutlet UNIVERSAL_BUTTON* stopRecButton;

-(IBAction)StartRecButton_Click:(id)sender;
-(IBAction)StopRecButton_Click:(id)sender;

@end
