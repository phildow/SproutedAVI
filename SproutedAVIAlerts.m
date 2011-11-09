//
//  SproutedAVIAlerts.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/22/08.
//  Copyright Philip Dow / Sprouted. All rights reserved.
//	All inquiries should be directed to developer@journler.com
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


#import <SproutedAVI/SproutedAVIAlerts.h>

//NSLocalizedStringFromTableInBundle( key, table, bundle, comment )

@implementation NSAlert (SproutedAVIAlerts)

+ (NSAlert*) snapshotUnavailable
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"no snapshot capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"no snapshot capture info", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) audioRecordingUnavailable 
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"no audio capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"no audio capture info",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}


+ (NSAlert*) videoRecordingUnavailable 
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"no video capture msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"no video capture info",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

#pragma mark -

+ (NSAlert*) lameInstallRequired
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"lameinstall required title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"lameinstall required msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(
			@"lameinstall required yes",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(
			@"lameinstall required no",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	
	return [alert autorelease];
}

+ (NSAlert*) lameInstallSuccess 
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"lameinstall success title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"lameinstall success msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) lameInstallFailure 
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"lameinstall failure title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"lameinstall failure msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

#pragma mark -

+ (NSAlert*) unableToStartRecording
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"audio recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"audio recording error cant start msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) unableToWriteMP3
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"audio recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"audio conversion error cant write msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) lameEncoderUnavailable
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"audio conversion error no encoder title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"audio conversion error no encoder msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) iTunesImportScriptUnavailable
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"audio recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"audio recording error script msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) unreadableAudioFile
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"audio recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"audio recording error saved file unreadable msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

#pragma mark -

+ (NSAlert*) unableToStopVideoRecording
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"video recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"video recording unable to stop msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

+ (NSAlert*) unreadableVideoFile
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedStringFromTableInBundle(
			@"video recording error title",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];
	[alert setInformativeText:NSLocalizedStringFromTableInBundle(
			@"video recording cant load msg",
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"")];

	return [alert autorelease];
}

@end