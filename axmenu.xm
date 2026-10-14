#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

#ifdef __cplusplus
extern "C" {
#endif

void AX_InstallRuntimeHooks();
void AX_StartOverlay();

#ifdef __cplusplus
}
#endif

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        AX_InstallRuntimeHooks();
        AX_StartOverlay();
    });
}
