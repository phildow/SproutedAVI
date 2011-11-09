//
//  SproutedLeopardAudioRecorder.h
//  Sprouted AVI
//
//  Created by Philip Dow on 5/1/08.
//  Copyright Philip Dow / Sprouted. All rights reserved.
//

/*
 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.
 
 * Neither the name of the author nor the names of its contributors may be used to endorse or
 promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import <Cocoa/Cocoa.h>
#import <QTKit/QTkit.h>
#import <ID3/TagAPI.h>
#import <SproutedUtilities/SproutedUtilities.h>
#import <SproutedInterface/SproutedInterface.h>
#import <SproutedAVI/SproutedAudioRecorder.h>

@class SproutedLAMEInstaller;
@class PDMovieSlider;

@interface SproutedLeopardAudioRecorder : SproutedAudioRecorder {
	
	// in addition to what's provided by the sproutedrecorder
	
	IBOutlet NSLevelIndicator *mAudioLevelMeter;
	IBOutlet NSTextField *sizeField;
	
	// QTKit capture session
	QTCaptureSession *mCaptureSession;
    QTCaptureMovieFileOutput *mCaptureMovieFileOutput;
	QTCaptureDeviceInput *mCaptureAudioDeviceInput;
	
	NSTimer	*mAudioLevelTimer;
}

- (BOOL) setupRecording;
- (BOOL) takedownRecording;
- (void) prepareForPlaying;

// making the recording

- (IBAction) recordPause:(id)sender;
- (IBAction) startRecording:(id)sender;
- (IBAction) setChannelGain:(id)sender;

// playing the recording

- (IBAction) playPause:(id)sender;
- (IBAction) changePlaybackVolume:(id)sender;
- (void) playlockCallback:(NSTimer*)aTimer;

- (IBAction) fastForward:(id)sender;
- (IBAction) rewind:(id)sender;

- (void) updateAudioLevels:(NSTimer *)aTimer;
- (void) updateTimeAndSizeDisplay:(NSTimer*)aTimer;

@end
