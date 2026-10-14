#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <cmath>
#import "esp.h"

// *все методы ниже — заглушки, имена подставить из strings global-metadata.dat*
// *типовая схема Standoff 2: Player.get_Position / Player.get_Health / Player.get_Team*
// *список игроков обычно через PhotonNetwork.PlayerList*

typedef Vec3 (*get_Position_t)(void*, void*);
typedef float (*get_Health_t)(void*, void*);
typedef int (*get_Team_t)(void*, void*);
typedef bool (*get_IsLocal_t)(void*, void*);
typedef Vec3 (*get_HeadPos_t)(void*, void*);

static get_Position_t p_get_Position = nullptr;
static get_Health_t   p_get_Health   = nullptr;
static get_Team_t     p_get_Team     = nullptr;
static bool (*get_IsLocal)(void*, void*) = nullptr;
static Vec3 (*get_HeadPos)(void*, void*) = nullptr;

// extern: указывают на функции из hooks.mm
extern void* AX_FindMethodPtr(const char* ns, const char* klass, const char* method, int argc);
extern bool  AX_WorldToScreen(Vec3 world, Vec3* screen);
extern Vec3  AX_CalcAimAngle(Vec3 from, Vec3 to);

// ---------- собрать ESP-данные о врагах ----------
void AX_CollectESP() {
    g_esp_players.clear();
    // *1. получить локального игрока*
    // *2. получить список игроков*
    // *3. для каждого — позиция, HP, team, кость головы*
    // *4. отсеять локального и союзников*
    // *5. добавить в g_esp_players*
    // *6. если aimbot — найти ближайшего в FOV, применить угол*
}

// ---------- тик, вызываемый из хука Update ----------
extern "C" void AX_Tick(void* local_player) {
    if (!g_cfg.esp && !g_cfg.aimbot) return;

    AX_CollectESP();

    if (g_cfg.aimbot) {
        // *найти ближайшего к центру экрана врага*
        // *посчитать угол через AX_CalcAimAngle*
        // *применить через set_AimRotation / set_LookRotation*
    }

    // ESP рисуется в ax_overlay.mm через AX_DrawESP()
    extern void AX_DrawESP();
    AX_DrawESP();
}