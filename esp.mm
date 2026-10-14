#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <cmath>
#import "esp.h"

void AX_CollectESP() {
    g_esp_players.clear();
    // *имена методов подставить после strings global-metadata.dat*
}

void AX_Tick(void* local_player) {
    if (!g_cfg.esp && !g_cfg.aimbot) return;
    AX_CollectESP();
    if (g_cfg.aimbot) {
        // aimbot logic
    }
    if (g_cfg.esp) {
        AX_DrawESP();
    }
}
