#import <Foundation/Foundation.h>
#import <substrate.h>
#import "hide.h"

%ctor {
    AXHide_Install();
}