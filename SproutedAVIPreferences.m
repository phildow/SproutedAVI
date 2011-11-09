//
//  SproutedAVIPreferences.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/25/08.
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


#import <SproutedAVI/SproutedAVIPreferences.h>
#import <SproutedAVI/SproutedLAMEInstaller.h>
#import <SproutedAVI/SproutedAVIAlerts.h>

#define kFormatQuickTimeMovie		0
#define kFormatMP3					1

@implementation SproutedAVIPreferences

- (id) initWithController:(SproutedAVIController*)controller
{
	if ( self = [super initWithController:controller] )
	{
		[NSBundle loadNibNamed:@"AVIPreferences" owner:self];
	}
	return self;
}

#pragma mark -

- (IBAction) setAudioFormat:(id)sender
{
	if ( ( [sender isKindOfClass:[NSMatrix class]] && [[sender selectedCell] tag] == kFormatMP3 ) || [sender tag] == kFormatMP3 )
	{
		// ensure the component is available
		
		ComponentDescription	description;
		
		description.componentType = 'spit';
		description.componentSubType = 'mp3 ';
		description.componentManufacturer = 'PYEh';
		description.componentFlags = 0;
		description.componentFlagsMask = 0;

		Component c = FindNextComponent(0, &description);
		if ( c == nil ) 
		{
			BOOL registeredComponent = NO;
			
			// are the necessary qt components also available?
			if ( [SproutedLAMEInstaller LAMEComponentsInstalled] ) 
			{
				// the components are installed but we can't load them
				NSLog(@"%@ %s - Could not load LAME MP3 encoder component", [self className], _cmd);
				[[NSAlert lameEncoderUnavailable] runModal];
			}
			else
			{
				// the components are not installed, install them if the user would like to
				if ( [[NSAlert lameInstallRequired] runModal] == NSAlertFirstButtonReturn )
				{
					if ( [SproutedLAMEInstaller simplyInstallLameComponents] )
					{
						OSErr localError;
						FSSpec fsSpec;
						NSString *componentPath = [SproutedLAMEInstaller LAMEComponentInstallPath];
						
						if ( [componentPath getFSSpec:&fsSpec] )
						{
							localError = RegisterComponentFile(&fsSpec,0);
							if ( localError == noErr )
								registeredComponent = YES;
							else
								NSLog(@"%@ %s - unable to register component for file at path %@", [self className], _cmd, componentPath);
						}
						else
						{
							NSLog(@"%@ %s - unable to get fsspec for file at path %@", [self className], _cmd, componentPath);
						}
												
						// if the installation was successful but there was a component problem, let the user know a relaunch is required
						if ( registeredComponent == NO )
							[[NSAlert lameInstallSuccess] runModal];
					}
					else
					{
						[[NSAlert lameInstallFailure] runModal];
					}
				}
				else
				{
					// revert to the movie format once the action has finished calling this method
					[self performSelector:@selector(_selectAudioFormat:) 
							withObject:[NSNumber numberWithInt:kFormatQuickTimeMovie] 
							afterDelay:0.1];
				}
			}
			
			// reset the encoding if a relaunch is required
			if ( registeredComponent == NO )
			{
				// revert to the movie format once the action has finished calling this method
				[self performSelector:@selector(_selectAudioFormat:) 
						withObject:[NSNumber numberWithInt:kFormatQuickTimeMovie] 
						afterDelay:0.1];
			}
		}
	}
}

- (void) _selectAudioFormat:(NSNumber*)format
{
	[audioFormatMatrix selectCellWithTag:[format intValue]];
	[[NSUserDefaults standardUserDefaults] setInteger:[format integerValue] forKey:@"AudioRecordingFormat"];
}

@end
