//
//  SproutedLAMEInstaller.m
//  PDVideoCapture
//
//  Created by Philip Dow on xx.
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


#import <SproutedAVI/SproutedLAMEInstaller.h>

@implementation SproutedLAMEInstaller

- (id) init {
	
	if ( self = [super init] ) {
		
	}
	
	return self;
	
}

- (void)windowWillClose:(NSNotification *)aNotification {
	
}

#pragma mark -

+ (NSString*) LAMEFrameworkBundlePath 
{
	NSString *frameworkPath = [[NSBundle bundleWithIdentifier:@"com.sprouted.avi"] pathForResource:@"LAME" ofType:@"framework"];
	return frameworkPath;
}

+ (NSString*) LAMEComponentBundlePath 
{
	NSString *frameworkPath = [[NSBundle bundleWithIdentifier:@"com.sprouted.avi"] pathForResource:@"LAMEEncoder" ofType:@"component"];
	return frameworkPath;
}

+ (NSString*) LAMEFrameworkInstallPath 
{
	static NSString *path = @"/Library/Frameworks/LAME.framework/";
	return path;
}

+ (NSString*) LAMEComponentInstallPath 
{
	static NSString *path = @"/Library/QuickTime/LAMEEncoder.component/";
	return path;
}

+ (BOOL) LAMEComponentsInstalled 
{
	NSFileManager *fm = [NSFileManager defaultManager];
	return ( [fm fileExistsAtPath:[SproutedLAMEInstaller LAMEFrameworkInstallPath]] && 
			[fm fileExistsAtPath:[SproutedLAMEInstaller LAMEComponentInstallPath]] );
	
}

#pragma mark -

+ (BOOL) simplyInstallLameComponents
{
	return [[[[SproutedLAMEInstaller alloc] init] autorelease] installLameComponents];
}

- (BOOL) installLameComponents 
{
	// installs the LAME.framework and LAMEEncoder.component into the required system directories
	NSLog(@"Installing LAME.framework and LAMEEncoder.component");
	
	BOOL success = YES;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ( [fm fileExistsAtPath:[SproutedLAMEInstaller LAMEFrameworkBundlePath]] && 
			![fm fileExistsAtPath:[SproutedLAMEInstaller LAMEFrameworkInstallPath]] )
		success = [fm copyPath:[SproutedLAMEInstaller LAMEFrameworkBundlePath] 
				toPath:[SproutedLAMEInstaller LAMEFrameworkInstallPath] 
				handler:self];
		
	if ( [fm fileExistsAtPath:[SproutedLAMEInstaller LAMEComponentBundlePath]] && 
			![fm fileExistsAtPath:[SproutedLAMEInstaller LAMEComponentInstallPath]] )
		success = ( success && [fm copyPath:[SproutedLAMEInstaller LAMEComponentBundlePath] 
				toPath:[SproutedLAMEInstaller LAMEComponentInstallPath] 
				handler:self] );	
	
	if ( success ) 
	{
		// set the group to admin, common for items in the framework and components directories
		NSDictionary *groupDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"admin", NSFileGroupOwnerAccountName, nil];
		
		success = [fm changeFileAttributes:groupDict atPath:[SproutedLAMEInstaller LAMEFrameworkInstallPath]];
		success = ( success && [fm changeFileAttributes:groupDict atPath:[SproutedLAMEInstaller LAMEComponentInstallPath]] );	
	}
	
	if ( success ) NSLog(@"Successfully installed mp3 encoding components");
	else NSLog(@"Unable to install mp3 encoding components");
	
	return success;
}

#pragma mark -
#pragma mark File Manager Delegation

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path 
{
	// simply for the sake of consistency
}

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo 
{
	// log the error and return no
	NSLog(@"\nEncountered file manager error: source = %@, error = %@, destination = %@\n",
			[errorInfo objectForKey:@"Path"], 
			[errorInfo objectForKey:@"Error"], 
			[errorInfo objectForKey:@"ToPath"]);
	
	return NO;
}

@end
