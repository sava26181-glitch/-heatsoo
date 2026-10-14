#pragma once
#include <vector>

struct Vec3 { float x, y, z; };

struct Config {
    bool  esp         = false;
    bool  esp_box     = true;
    bool  esp_line    = false;
    bool  esp_health  = false;
    bool  esp_name    = false;
    bool  aimbot      = false;
    float aim_fov     = 45.0f;
    float aim_smooth  = 8.0f;
    int   aim_bone    = 0;
    bool  aim_visible = false;
};
extern Config g_cfg;

struct ESPPlayer {
    Vec3  world_head;
    Vec3  world_feet;
    float health = 100.0f;
    int   team   = 0;
    bool  valid  = false;
};
extern std::vector<ESPPlayer> g_esp_players;
extern int g_local_team;

#ifdef __cplusplus
extern "C" {
#endif

bool  AX_WorldToScreen(Vec3 world, Vec3* screen);
Vec3  AX_CalcAimAngle(Vec3 from, Vec3 to);
void  AX_CollectESP();
void  AX_DrawESP();
void  AX_Tick(void* local_player);
void  AX_InstallRuntimeHooks();
void  AX_StartOverlay();
void* AX_FindMethodPtr(const char* ns, const char* klass, const char* method, int argc);

#ifdef __cplusplus
}
#endif
