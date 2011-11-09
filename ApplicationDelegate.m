//
//  ApplicationDelegate.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/22/08.
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


#import "ApplicationDelegate.h"

@implementation ApplicationDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSDate *expirationDate = [NSDate dateWithString:kExpirationDate];
	NSDate *todaysDate = [NSDate date];
	
	if ( [expirationDate compare:todaysDate] == NSOrderedAscending )
	{
		NSRunAlertPanel(@"Sprouted AVI has expired", 
				@"The trial period has expired. You'll need to download a newer version, if one is available.", 
				nil, nil, nil);
		[NSApp terminate:self];
	}
	else
	{
		SproutedAVIController *aviController = [SproutedAVIController sharedController];
		[aviController setDelegate:self];
		[aviController showWindow:self];
		
		NSString *recordingTitle = NSLocalizedStringFromTableInBundle(@"untitled audio recording",
				@"Localizable",
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
				@"");
		
		NSDictionary *recordingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				recordingTitle, kSproutedAudioRecordingTitleKey, nil];
		
		[aviController setAudioRecordingAttributes:recordingAttributes];
	}
}

- (IBAction) recordAudio:(id)sender
{
	[[SproutedAVIController sharedController] recordAudio:sender];
}

- (IBAction) recordVideo:(id)sender
{
	[[SproutedAVIController sharedController] recordVideo:sender];
}

- (IBAction) takeSnapshot:(id)sender
{
	[[SproutedAVIController sharedController] takeSnapshot:sender];
}

#pragma mark -

- (NSNumber*) validateYourself:(SproutedAVIController*)aController
{
	NSBundle *framework = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	NSString *executablePath = [framework executablePath];
	
	NSNumber *executableSize = [[[NSFileManager defaultManager] 
			fileAttributesAtPath:executablePath 
			traverseLink:NO]
			objectForKey:NSFileSize];
	
	return executableSize;
}

#pragma mark -

- (void) sproutedAudioRecorder:(SproutedAudioRecorder*)recorder insertRecording:(NSString*)sourcePath title:(NSString*)title
{
	if ( [recorder saveAction] == kSproutedAudioSavedToiTunes )
	{
		[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
				inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
	}
	else
	{
		NSString *desktopFolder = [self desktopFolder];
		if ( desktopFolder == nil ) desktopFolder = [@"~/Desktop" stringByExpandingTildeInPath];
		if ( desktopFolder == nil || ![[NSFileManager defaultManager] fileExistsAtPath:desktopFolder] )
		{
			[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
					inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
		}
		else
		{
			NSString *kFilename = [title stringByAppendingPathExtension:[sourcePath pathExtension]];
			NSString *destinationPath = [[desktopFolder stringByAppendingPathComponent:kFilename] pathWithoutOverwritingSelf];
			
			if ( [[NSFileManager defaultManager] respondsToSelector:@selector(moveItemAtPath:toPath:error:)] )
			{
				NSError *error = nil;
				if ( ![[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:destinationPath error:&error] )
				{
					if ( error != nil ) [NSApp presentError:error];
					[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
							inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
				}
				else
				{
					[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
							inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
				}
			}
			else
			{
				if ( ![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:nil] )
				{
					[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
							inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
				}
				else
				{
					[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
							inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
				}
			}
		}
	}
}

- (void) sproutedVideoRecorder:(SproutedVideoRecorder*)recorder insertRecording:(NSString*)sourcePath title:(NSString*)title
{
	NSString *desktopFolder = [self desktopFolder];
	if ( desktopFolder == nil ) desktopFolder = [@"~/Desktop" stringByExpandingTildeInPath];
	if ( desktopFolder == nil || ![[NSFileManager defaultManager] fileExistsAtPath:desktopFolder] )
	{
		[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
				inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
	}
	else
	{
		NSString *kFilename = [@"Video Recording" stringByAppendingPathExtension:[sourcePath pathExtension]];
		NSString *destinationPath = [[desktopFolder stringByAppendingPathComponent:kFilename] pathWithoutOverwritingSelf];
		
		if ( [[NSFileManager defaultManager] respondsToSelector:@selector(moveItemAtPath:toPath:error:)] )
		{
			NSError *error = nil;
			if ( ![[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:destinationPath error:&error] )
			{
				if ( error != nil ) [NSApp presentError:error];
				[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
						inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
						inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
			}
		}
		else
		{
			if ( ![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:nil] )
			{
				[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
						inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
						inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
			}
		}
	}
}

- (void) sproutedSnapshot:(SproutedSnapshot*)recorder insertRecording:(NSString*)sourcePath title:(NSString*)title
{
	NSString *desktopFolder = [self desktopFolder];
	if ( desktopFolder == nil ) desktopFolder = [@"~/Desktop" stringByExpandingTildeInPath];
	if ( desktopFolder == nil || ![[NSFileManager defaultManager] fileExistsAtPath:desktopFolder] )
	{
		[[NSWorkspace sharedWorkspace] selectFile:sourcePath inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
	}
	else
	{
		NSString *kFilename = [@"Picture" stringByAppendingPathExtension:[sourcePath pathExtension]];
		NSString *destinationPath = [[desktopFolder stringByAppendingPathComponent:kFilename] pathWithoutOverwritingSelf];
		
		if ( [[NSFileManager defaultManager] respondsToSelector:@selector(moveItemAtPath:toPath:error:)] )
		{
			NSError *error = nil;
			if ( ![[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:destinationPath error:&error] )
			{
				if ( error != nil ) [NSApp presentError:error];
				[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
						inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
						inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
			}
		}
		else
		{
			if ( ![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:nil] )
			{
				[[NSWorkspace sharedWorkspace] selectFile:sourcePath 
						inFileViewerRootedAtPath:[sourcePath stringByDeletingLastPathComponent]];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:destinationPath 
						inFileViewerRootedAtPath:[destinationPath stringByDeletingLastPathComponent]];
			}
		}
	}
}

#pragma mark -

- (NSString*) desktopFolder 
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	return basePath;
}

@end
