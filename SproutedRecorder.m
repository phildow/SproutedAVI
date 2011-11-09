//
//  SproutedRecorder.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/23/08.
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


#import <SproutedAVI/SproutedRecorder.h>
#import <SproutedAVI/SproutedAVIController.h>

NSString *kSproutedAVIFrameworkErrorDomain = @"SproutedAVIFrameworkErrorDomain";

@implementation SproutedRecorder

- (id) initWithController:(SproutedAVIController*)controller
{
	// check to ensure I'm being used by an authorized party
	if ( [controller isMemberOfClass:[SproutedAVIController class]] /*&& [controller delegateIsValid]*/ )
	{
		return [super init];
	}
	else
	{
		return nil;
	}
}

- (void) dealloc
{
	//NSLog(@"%@ %s",[self className],_cmd);
	
	[error release], error = nil;
	
	// the top level nib owner is responsible for the items in the nib
	[view release], view = nil;
	
	[super dealloc];
}

#pragma mark -

- (NSString*) error
{
	return error;
}

- (void) setError:(NSString*)anError
{
	if ( error != anError )
	{
		[error release];
		error = [anError copyWithZone:[self zone]];
	}
}

#pragma mark -

- (NSView*) view
{
	return view;
}

- (BOOL) warnsWhenUnsavedChanges
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"WarnOfUnsavedRecordings"];
}

#pragma mark -

- (NSError*) stillRecordingError
{
	NSError *theError = nil;
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	NSString *errorDescription = NSLocalizedStringFromTableInBundle(@"still recording description",
			@"Localizable",
			myBundle,
			@"");
	NSString *recoverySuggestion = NSLocalizedStringFromTableInBundle(@"still recording recovery",
			@"Localizable",
			myBundle,
			@"");
	
	NSString *stopOption = NSLocalizedStringFromTableInBundle(@"still recording stop",
			@"Localizable",
			myBundle,
			@"");

	NSString *cancelOption = NSLocalizedStringFromTableInBundle(@"still recording cancel",
			@"Localizable",
			myBundle,
			@"");
		
	NSArray *recoveryOptions = [NSArray arrayWithObjects:stopOption, cancelOption, nil];
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			errorDescription, NSLocalizedDescriptionKey,
			recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
			recoveryOptions, NSLocalizedRecoveryOptionsErrorKey, 
			self, NSRecoveryAttempterErrorKey, nil];
	
	theError = [NSError errorWithDomain:kSproutedAVIFrameworkErrorDomain 
			code:kTryingToCloseWhileRecordingError 
			userInfo:errorInfo];
			
	return theError;
}

- (NSError*) unsavedChangesError
{
	NSError *theError = nil;
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	NSString *errorDescription = NSLocalizedStringFromTableInBundle(@"unsaved changes description",
			@"Localizable",
			myBundle,
			@"");
	NSString *recoverySuggestion = NSLocalizedStringFromTableInBundle(@"unsaved changes recovery",
			@"Localizable",
			myBundle,
			@"");
	
	NSString *saveOption = NSLocalizedStringFromTableInBundle(@"unsaved changes save",
			@"Localizable",
			myBundle,
			@"");
	
	NSString *dontSaveOption = NSLocalizedStringFromTableInBundle(@"unsaved changes dont save",
			@"Localizable",
			myBundle,
			@"");
			
	NSString *cancelOption = NSLocalizedStringFromTableInBundle(@"unsaved changes cancel",
			@"Localizable",
			myBundle,
			@"");
	
	NSArray *recoveryOptions = [NSArray arrayWithObjects:saveOption, dontSaveOption, cancelOption, nil];
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			errorDescription, NSLocalizedDescriptionKey,
			recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
			recoveryOptions, NSLocalizedRecoveryOptionsErrorKey, 
			self, NSRecoveryAttempterErrorKey, nil];
	
	theError = [NSError errorWithDomain:kSproutedAVIFrameworkErrorDomain 
			code:kUnsavedRecordingError 
			userInfo:errorInfo];
			
	return theError;
}

#pragma mark -

- (BOOL)attemptRecoveryFromError:(NSError *)theError optionIndex:(NSUInteger)recoveryOptionIndex
 {
	BOOL returnValue = NO;
	
	if ( [theError code] == kTryingToCloseWhileRecordingError )
	{
		if ( recoveryOptionIndex == 0 )
		{
			// stop recording and exit
			[self stopRecording:self];
			returnValue = YES;
		}
		else
		{
			// cancel and remain in place
			returnValue = NO;
		}
	}
	else if ( [theError code] == kUnsavedRecordingError )
	{
		if ( recoveryOptionIndex == 0 )
		{
			// save recording and exit
			[self saveRecording:self];
			returnValue = YES;
		}
		else if ( recoveryOptionIndex == 1 )
		{
			// discard recording and exit
			returnValue = YES;
		}
		else
		{
			// cancel and remain in place
			returnValue = NO;
		}
	}
	
	return returnValue;
}

- (void) attemptRecoveryFromError:(NSError *)anError 
		optionIndex:(NSUInteger)recoveryOptionIndex 
		delegate:(id)delegate 
		didRecoverSelector:(SEL)didRecoverSelector 
		contextInfo:(void *)contextInfo
{
	BOOL returnValue = [self attemptRecoveryFromError:anError optionIndex:recoveryOptionIndex];
	NSMethodSignature *signature = [delegate methodSignatureForSelector:didRecoverSelector];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	
	[invocation setSelector:didRecoverSelector];
	[invocation setTarget:delegate];
	
	[invocation setArgument:&returnValue atIndex:2];
	[invocation setArgument:&contextInfo atIndex:3];
	
	[invocation invoke];
}

#pragma mark -

- (BOOL) recorderShouldClose:(NSNotification*)aNotification error:(NSError**)anError
{
	return YES;
}

#pragma mark -

- (BOOL) recorderWillLoad:(NSNotification*)aNotification
{
	return YES;
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
	return YES;
}

- (BOOL) recorderWillClose:(NSNotification*)aNotification
{
	return YES;
}

- (BOOL) recorderDidClose:(NSNotification*)aNotification
{
	return YES;
}

#pragma mark -

- (IBAction) stopRecording:(id)sender
{
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
}

- (IBAction) saveRecording:(id)sender
{
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
}

@end
