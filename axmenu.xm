#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

extern void AX_InstallRuntimeHooks();
extern void AX_StartOverlay();

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        AX_InstallRuntimeHooks();
        AX_StartOverlay();
    });
}