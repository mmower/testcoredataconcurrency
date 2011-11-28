//
//  SFAppDelegate.m
//  TestCoreData
//
//  Created by Matt Mower on 25/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SFAppDelegate.h"

static const NSUInteger FROOB_COUNT = 5000;

@interface SFAppDelegate ()

- (NSManagedObjectContext *)childManagedObjectContext;

@end

@implementation SFAppDelegate


@synthesize window = _window;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;

static dispatch_queue_t background_queue;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Ensure the primary MOC (and the underlying store) are initialized
  (void)[self managedObjectContext];
  
  background_queue = dispatch_queue_create("background", DISPATCH_QUEUE_SERIAL);
}

typedef void (^ConfigBlock)(NSManagedObject *);


- (void)createObject:(NSString *)type context:(NSManagedObjectContext *)context config:(ConfigBlock)configBlock {
  NSManagedObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:type inManagedObjectContext:context];
  configBlock( newObject );
  
  NSError *error = nil;
  if( ![context save:&error] ) {
    NSLog( @"Save error: %@", [error localizedDescription] );
    [[NSException exceptionWithName:@"SaveException" reason:[error localizedDescription] userInfo:nil] raise];
  }
}


- (void)scheduleBlocks {
  dispatch_queue_t worker_queue = dispatch_queue_create("worker", DISPATCH_QUEUE_CONCURRENT);
  _worker_group = dispatch_group_create();
  
  NSUInteger froobCount = 0;
  
  while( froobCount < FROOB_COUNT ) {
    if( ( random() % 100 ) < 10 ) {
      dispatch_group_async( _worker_group, worker_queue, ^{
        NSError *error = nil;
        NSManagedObjectContext *context = [self childManagedObjectContext];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
        [fetch setEntity:[NSEntityDescription entityForName:@"Froob" inManagedObjectContext:context]];
        NSArray *results = [context executeFetchRequest:fetch error:&error];
        if( !results ) {
          NSLog( @"Query error: %@", [error localizedDescription] );
          [[NSException exceptionWithName:@"FetchException" reason:[error localizedDescription] userInfo:nil] raise];
        }
        
        NSUInteger sum = 0;
        for( NSManagedObject *froob in results ) {
          sum += [[froob valueForKey:@"value"] intValue];
        }
        
        NSLog( @"At this time there are %lu froobs totalling %lu", [results count], sum );
      });
    } else {
      dispatch_group_async( _worker_group, worker_queue, ^{
        [self createObject:@"Froob" context:[self childManagedObjectContext] config:^(NSManagedObject *obj) {
          [obj setValue:[NSNumber numberWithInt:rand() % 10] forKey:@"value"];
        }];
      });
      froobCount += 1;
    }
  }
}


- (IBAction)goAction:(id)sender {
  dispatch_async(background_queue, ^{
    [self scheduleBlocks];
  });
  _timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
}


- (NSUInteger)count:(NSString *)entitiName error:(NSError **)error {
  NSLog( @"Let's count the froobs" );
  NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
  [fetch setEntity:[NSEntityDescription entityForName:entitiName inManagedObjectContext:[self managedObjectContext]]];
  [fetch setIncludesSubentities:NO];
  NSUInteger count = [[self managedObjectContext] countForFetchRequest:fetch error:error];
  return count;  
}


- (void)completeAction:(id)sender {
  [_timer invalidate];

  NSError *error = nil;
  NSUInteger count = [self count:@"Froob" error:&error];
  if( count == NSNotFound ) {
    [[NSException exceptionWithName:@"FetchException" reason:[error localizedDescription] userInfo:nil] raise];
  }
  
  if( count != FROOB_COUNT ) {
    NSLog( @"The FroobCount has failed %lu vs %lu", count, FROOB_COUNT );
  } else {
    NSLog( @"All is well!!!!" );
  }
  
  count = [self count:@"Frobnosticator" error:&error];
  if( count == NSNotFound ) {
    [[NSException exceptionWithName:@"FetchException" reason:[error localizedDescription] userInfo:nil] raise];
  }
  NSLog( @"Also %lu Frobnisticators were created.", count );
}

- (void)timerFired:(NSTimer *)timer {
  NSError *error = nil;
  
  NSLog( @"Checking for all work blocks to have finished" );
  
  long blocks_waiting = dispatch_group_wait( _worker_group, DISPATCH_TIME_NOW );
  NSLog( @"blocks waiting = %ld", blocks_waiting );
  if( !blocks_waiting ) {
    NSLog( @"Finished waiting" );
    [self performSelectorOnMainThread:@selector(completeAction:) withObject:self waitUntilDone:NO];
  } else {
    error = nil;
    NSUInteger count = [self count:@"Froob" error:&error];
    NSLog( @"Intermediate count = %lu", count );
    
    [self createObject:@"Frobnosticator" context:[self managedObjectContext] config:^(NSManagedObject *obj){}];
  }
  
  NSLog( @"Leaving timer callback" );
}

/**
    Returns the directory the application uses to store the Core Data store file. This code uses a directory named "TestCoreData" in the user's Library directory.
 */
- (NSURL *)applicationFilesDirectory {

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryURL = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [[libraryURL URLByAppendingPathComponent:@"Application Support"] URLByAppendingPathComponent:@"TestCoreData"];
}

/**
    Creates if necessary and returns the managed object model for the application.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"TestCoreData" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

/**
    Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (__persistentStoreCoordinator) {
        return __persistentStoreCoordinator;
    }

    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
        
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    else {
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue] != YES) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]]; 
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
  
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"TestCoreData.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __persistentStoreCoordinator = coordinator;

    return __persistentStoreCoordinator;
}

/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (__managedObjectContext) {
        return __managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];

    return __managedObjectContext;
}

- (NSManagedObjectContext *)childManagedObjectContext {
  NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
  [context setParentContext:[self managedObjectContext]];
  return context;
}

/**
    Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
 */
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}

/**
    Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
 */
- (IBAction)saveAction:(id)sender {
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    // Save changes in the application's managed object context before the application terminates.

    if (!__managedObjectContext) {
        return NSTerminateNow;
    }

    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }

    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }

    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
