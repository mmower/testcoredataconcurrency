//
//  SFAppDelegate.h
//  TestCoreData
//
//  Created by Matt Mower on 25/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SFAppDelegate : NSObject <NSApplicationDelegate> {
  NSTimer *_timer;
  dispatch_group_t _worker_group;
}

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)goAction:(id)sender;
- (void)completeAction:(id)sender;
- (IBAction)saveAction:(id)sender;

@end
