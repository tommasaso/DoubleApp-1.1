//  ViewController.m
//  DoubleAssignment
//
//  Created by Tommaso Elia on 03/02/18.
//  Copyright © 2018 DoubleTeam. All rights reserved.
//


#include "key.h"
#include "precomp.h"
#import <DoubleControlSDK/DoubleControlSDK.h>


#define SHORT_SLEEP 2
#define LONG_SLEEP 0

@interface ViewController (/*private*/) <DRDoubleDelegate>

@property (nonatomic)  NSString*               subscriptionKey;
@property (nonatomic)  NSString*               subscriptionKey2;
@property (nonatomic)  NSString*               subscriptionKey3;
@property (nonatomic)  NSString*               luisAppID;
@property (nonatomic)  NSString*               luisSubscriptionID;
@property (nonatomic)  NSString*               authenticationUri;
@property (nonatomic)  bool                    wantIntent;
@property (nonatomic)  SpeechRecognitionMode   mode;
@property (nonatomic)  NSString*               defaultLocale;

// Responses from the server are recieved asynchronously and by default the audio recording stops after a resonse is recieved. Thus we need to explicitly restart the microphone after each response is recieved. In order to stop the recording for good, after the stop button is pushed, we must not reactivate the audio recording after a response is recieved. This behaviour is implemented through this flag, which states if the stop button was pushed (YES) or not (NO).
@property (nonatomic) bool stopRecButtonFlag;

@property (nonatomic) NSInteger noRecCounter; // empty responses due to silence
@property (nonatomic) NSInteger noRecPartialCounter; // counter needed to reset the speech recognition client (short sleep)
@property (nonatomic) NSInteger notEmptyCounter; // not empty responses
@property (nonatomic) NSInteger allResponsesCounter; // total number of responses (sum of empty responses and not empty ones)
@property (nonatomic) NSInteger allResponsesPartialCounter; // counter needed to reset the speech recognition client (long sleep)
@property (nonatomic) NSMutableString *myResults; // string to be published on myResultLabel
@property (nonatomic) NSMutableString *myIntentsList; //string to be published on myIntentsLabel
@property (nonatomic) NSMutableString *myEntitiesList; //string to be published on MyEntities Label
@property (nonatomic) NSString *actualSubscriptionKey; // needed to switch among different subscription keys trying to extend the web socket connection time
@end

NSString* ConvertSpeechRecoConfidenceEnumToString(Confidence confidence);
NSString* ConvertSpeechErrorToString(int errorCode);


// The Main App ViewController

@implementation ViewController

@synthesize startRecButton;
@synthesize stopRecButton;

// Initializazion to be done when app starts

-(void)viewDidLoad {
    [super viewDidLoad];
    /*** [SpeechAndIntentRecognizer initializer] (initialize method)***/
    
    [DRDouble sharedDouble].delegate = self;
    
    // counters initialization
    self.notEmptyCounter = 0;
    self.noRecCounter = 0;
    self.noRecPartialCounter = 0;
    self.allResponsesCounter = 0;
    self.allResponsesPartialCounter = 0;
    
    
    // set the values as defined in the key.h header file
    self.subscriptionKey = SUBSCRIPTION_KEY3; // set the subscription key as the one defined in the header file
    self.subscriptionKey2 = SUBSCRIPTION_KEY3;
    self.subscriptionKey3 = SUBSCRIPTION_KEY3;
    self.authenticationUri = AUTHENTICATION_URI;
    self.mode = SPEECH_RECOGNITION_MODE;
    self.luisAppID = LUIS_APP_ID;
    self.luisSubscriptionID = LUIS_SUBSCRIPTION_ID;
    
    self.actualSubscriptionKey = self.subscriptionKey; // the first subscribtion key to be used at laoding time
    
    self.wantIntent = YES; // specify you want also intent recognition besides speech recognition
    self.defaultLocale =@"en-us"; // speech recognition language
    
    // declare strings to print text on UI labeles
    self.myResults = [ NSMutableString  stringWithCapacity:  1000 ];
    self.myIntentsList = [ NSMutableString  stringWithCapacity:  1000 ];
    self.myEntitiesList = [ NSMutableString  stringWithCapacity:  1000 ];
    
    [[self stopRecButton] setEnabled: NO]; // disable stopRecButton
    
    /*** END ***/
}

// this method handles the Click event of the startRecButton control
// @param sender The event sender
-(IBAction)StartRecButton_Click:(id)sender {
    
    [[self startRecButton] setEnabled: NO]; // disable startRecButton
    self.headerText.text = @"SPEECH RECOGNITION WITH INTENT DETECTION ENABLED"; // set the header label text
    
    /*** [SpeechAndIntentRecognizer startRecording] ***/
    if (micClient == nil) // if there is no MicrophoneClientWithIntent create it
    {
        micClient = [SpeechRecognitionServiceFactory createMicrophoneClientWithIntent:(self.defaultLocale)
                                                                              withKey:(self.actualSubscriptionKey)
                                                                        withLUISAppID:(self.luisAppID)
                                                                       withLUISSecret:(self.luisSubscriptionID)
                                                                         withProtocol:(self)];
    }
    
    self.stopRecButtonFlag = NO; // (stop button was not pushed yet) enable continous recording behaviour (see onFinalResponse method)
    [micClient startMicAndRecognition];  // activates the microphone and start the speech recognition with intent detection
    /*** END ***/
    
    [[self stopRecButton] setEnabled: YES];  // enable the stopRecButton
    
}

// this method handles the Click event of the stopRecButton control
// @param sender The event sender
-(IBAction)StopRecButton_Click:(id)sender {
    
    [[self stopRecButton] setEnabled: NO]; // disable stopRecButton
    
    /*** [SpeechAndIntentRecognizer stopRecording] ***/
    // reinitialize the counters at each execution
    self.notEmptyCounter = 0;
    self.noRecCounter = 0;
    self.allResponsesCounter = 0;
    self.noRecPartialCounter = 0;
    
    self.stopRecButtonFlag = YES; // (stop button pusheed set the flag accordingly) disable continuous recording behaviour (see onFinalResponse method)
    
    [micClient endMicAndRecognition]; // disable the microphone and disconnect from the server
    /*** END ***/
    
    self.headerText.text = @"SPEECH RECOGNITION DISABLED"; // set the Header lable
    [[ self startRecButton ] setEnabled: YES ]; // enable startRecButton
    
}

// ALL THE FUNCTIONS AND THE PROTOCOL METHODS MUST BE INCLUDED IN THE SpeechAndIntentRecognizer CLASS AS IS

// Called when a final response is received.
// @param response The final result.
-(void)onFinalResponseReceived:(RecognitionResult*)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.headerText.text = @"SPEECH RECOGNITION WITH INTENT DETECTION ENABLED"; // reset the header label text upon recieving a final response
        self.allResponsesCounter++;
        self.allResponsesPartialCounter++;
        
        if ([response.RecognizedPhrase count] == 0)  // if the chunks sent were just silence
        {
            self.noRecCounter++; // increase the noRec counter
            self.noRecPartialCounter++;
        }
        else // the response contains recognized phrases with the related confidence
        {
            self.notEmptyCounter++;
            
            // convert all the recognized results in one string to be shown in the corresponding UIlabel
            [self.myResults setString: @"Final n-BEST Results:\n\n"];
            for (int i = 0; i < [response.RecognizedPhrase count]; i++)
            {
                RecognizedPhrase* phrase = response.RecognizedPhrase[i];
                [self.myResults appendString: [NSString stringWithFormat:(@"[%d] Confidence: %@ Text: \"%@\"\n"),
                                               i,ConvertSpeechRecoConfidenceEnumToString(phrase.Confidence),
                                               phrase.DisplayText]];
            }
            
            self.myResultsLabel.text = self.myResults; // publish the composed string on myResultsLabel
            
        }
        // [micClient startMicAndRecognition]; // reactivate the microphone after the response is recieved (continous behaviuour)
        
        //display the counters in the log
        NSLog(@"Number of NOTEMPTY requests: %ld", self.notEmptyCounter);
        NSLog(@"Number of NOREC requests: %ld", self.noRecCounter);
        NSLog(@"Number of TOTAL requests: %ld", self.allResponsesCounter);
        NSLog(@"Number of NORECPARTIAL requests: %ld", self.noRecPartialCounter);
        NSLog(@"ACTUAL KEY %@", self.actualSubscriptionKey);
        
        int waitTime;
        
        if (!self.stopRecButtonFlag) // if the stop button was not pushed then continuous recording behaviour
        {
            if ((self.allResponsesCounter % 40) == 0) // if total responses since last reset of client reset it with a long sleep time for reinitialization
            {
                self.allResponsesPartialCounter = 0;
                waitTime = LONG_SLEEP;
            }
            else
            {
                waitTime = SHORT_SLEEP;
            }
            
            if ((self.noRecCounter % 10) == 0) {
                [micClient startMicAndRecognition]; // reactivate the microphone after the response is recieved (continous behaviuour)
            }
            else // else reinitialize the micClient
            {
                // change the subscription key following the order 1 -> 2 -> 3 -> 1 and so on
                if ([self.actualSubscriptionKey isEqualToString: self.subscriptionKey])
                {
                    self.actualSubscriptionKey = self.subscriptionKey2;
                }
                else if ([self.actualSubscriptionKey isEqualToString: self.subscriptionKey2])
                {
                    self.actualSubscriptionKey = self.subscriptionKey3;
                }
                else
                {
                    self.actualSubscriptionKey = self.subscriptionKey;
                }
                
                [micClient endMicAndRecognition]; // Turns the microphone off and breaks the connection to the speech recognition service.
                NSLog(@"going to sleep for %d seconds", waitTime);
                sleep(waitTime); // sleeps for the time set previously according to the allResponsesPartialCounter
                self.noRecPartialCounter = 0;
                micClient = [SpeechRecognitionServiceFactory createMicrophoneClientWithIntent:(self.defaultLocale)
                                                                                      withKey:(self.actualSubscriptionKey)
                                                                                withLUISAppID:(self.luisAppID)
                                                                               withLUISSecret:(self.luisSubscriptionID)
                                                                                 withProtocol:(self)];
                [micClient startMicAndRecognition]; // Turns the microphone on and begins streaming data from the microphone to the speech recognition service.
            }
            
        }
    });
}


//Called when a final response is received and its intent is parsed
//@param result The intent result.
-(void)onIntentReceived:(IntentResult*) result {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Convert the string sent by the LUIS server into a (id) json, equivalent to a NSDictionary
        NSString *jsonString = result.Body;
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        // store intents and entities in the corresponding arrays
        NSArray *myIntents = [json objectForKey:@"intents"];
        NSArray *myEntities = [json objectForKey:@"entities"];
        
        // show the top scoring intent in the corresponding UILabel
        self.myIntentsLabel.text = [[NSString alloc] initWithFormat:@"--- Intents Detected ---\n\nTop Scoring Intent: %@\nwith score: %@",
                                    [myIntents[0] objectForKey:@"intent"],
                                    [myIntents[0] objectForKey:@"score"]];
        
        // store alle the entities (types adn values) in a single string
        [self.myEntitiesList setString:@"--- Entities Detected ---\n\n"];
        for (int i = 0; i < [myEntities count]; i++)
        {
            [self.myEntitiesList appendString:[[NSString alloc] initWithFormat:@"Entity: %@ Type: %@ \n",
                                               [myEntities[i] objectForKey:@"entity"],
                                               [myEntities[i] objectForKey:@"type"]]];
            
        }
        
        // and show them all in the corresponding UILabel
        self.myEntitiesLabel.text = self.myEntitiesList;
        
    });
}

-(void)onLogEvent:(unsigned long) eventId {
    //NSLog(@" -------ONLOG %ld", eventId);
    
}

// Called when the microphone status has changed.
// @param recording The current recording state
-(void)onMicrophoneStatus:(Boolean)recording {
}

// method called when partial response is received
// @param response is the partial result
-(void)onPartialResponseReceived:(NSString*) response {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.headerText.text = @"--- LISTENING ---";}); // while recieving partial responses show the message: LISTENING in the header UILabel
    
}

// Called when an error is received
// @param errorMessage The error message.
// @param errorCode The error code.  Refer to SpeechClientStatus for details.

-(void)onError:(NSString*)errorMessage withErrorCode:(int)errorCode {
    
    NSLog(@"**************************************** Error received by onError ---/n%@ %@", errorMessage, ConvertSpeechErrorToString(errorCode));
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ self  startRecButton ] setEnabled: YES ]; // enable the startRecButton
        // show the error code and relative message in the Header Lable
        self.headerText.text = [[NSString alloc] initWithFormat:(@"--- Error received by onError ---/n%@ %@"), errorMessage, ConvertSpeechErrorToString(errorCode)];
        
    });
    
}

// Converts an integer error code to an error string.
// @param errorCode The error code
// @return The string representation of the error code.
NSString* ConvertSpeechErrorToString(int errorCode) {
    switch ((SpeechClientStatus)errorCode) {
        case SpeechClientStatus_SecurityFailed:         return @"SpeechClientStatus_SecurityFailed";
        case SpeechClientStatus_LoginFailed:            return @"SpeechClientStatus_LoginFailed";
        case SpeechClientStatus_Timeout:                return @"SpeechClientStatus_Timeout";
        case SpeechClientStatus_ConnectionFailed:       return @"SpeechClientStatus_ConnectionFailed";
        case SpeechClientStatus_NameNotFound:           return @"SpeechClientStatus_NameNotFound";
        case SpeechClientStatus_InvalidService:         return @"SpeechClientStatus_InvalidService";
        case SpeechClientStatus_InvalidProxy:           return @"SpeechClientStatus_InvalidProxy";
        case SpeechClientStatus_BadResponse:            return @"SpeechClientStatus_BadResponse";
        case SpeechClientStatus_InternalError:          return @"SpeechClientStatus_InternalError";
        case SpeechClientStatus_AuthenticationError:    return @"SpeechClientStatus_AuthenticationError";
        case SpeechClientStatus_AuthenticationExpired:  return @"SpeechClientStatus_AuthenticationExpired";
        case SpeechClientStatus_LimitsExceeded:         return @"SpeechClientStatus_LimitsExceeded";
        case SpeechClientStatus_AudioOutputFailed:      return @"SpeechClientStatus_AudioOutputFailed";
        case SpeechClientStatus_MicrophoneInUse:        return @"SpeechClientStatus_MicrophoneInUse";
        case SpeechClientStatus_MicrophoneUnavailable:  return @"SpeechClientStatus_MicrophoneUnavailable";
        case SpeechClientStatus_MicrophoneStatusUnknown:return @"SpeechClientStatus_MicrophoneStatusUnknown";
        case SpeechClientStatus_InvalidArgument:        return @"SpeechClientStatus_InvalidArgument";
    }
    return [[NSString alloc] initWithFormat:@"Unknown error: %d\n", errorCode];
}

// Converts a Confidence value to a string
// @param confidence The confidence value.
// @return The string representation of the confidence enumeration.
NSString* ConvertSpeechRecoConfidenceEnumToString(Confidence confidence) {
    switch (confidence) {
        case SpeechRecoConfidence_None:
            return @"None";
            
        case SpeechRecoConfidence_Low:
            return @"Low";
            
        case SpeechRecoConfidence_Normal:
            return @"Normal";
            
        case SpeechRecoConfidence_High:
            return @"High";
    }
}


//Action for low memory
-(void)didReceiveMemoryWarning {
#if !defined(TARGET_OS_MAC)
    [ super  didReceiveMemoryWarning ];
# endif
}

@end
