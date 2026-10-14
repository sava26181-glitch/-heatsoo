#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <cmath>
#import "esp.h"

Config g_cfg;
std::vector<ESPPlayer> g_esp_players;
int g_local_team = 0;

// ---------- IL2CPP API ----------
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_domain_assembly_open_t)(void*, const char*);
typedef void* (*il2cpp_assembly_get_image_t)(void*);
typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_method_from_name_t)(void*, const char*, int);
typedef void* (*il2cpp_method_get_pointer_t)(void*);

static il2cpp_domain_get_t p_domain_get = nullptr;
static il2cpp_domain_assembly_open_t p_assembly_open = nullptr;
static il2cpp_assembly_get_image_t p_assembly_get_image = nullptr;
static il2cpp_class_from_name_t p_class_from_name = nullptr;
static il2cpp_class_get_method_from_name_t p_class_get_method = nullptr;
static il2cpp_method_get_pointer_t p_method_get_pointer = nullptr;

static bool AX_ResolveIL2CPP() {
    void* h = dlopen("UnityFramework", RTLD_NOW);
    if (!h) h = dlopen(NULL, RTLD_NOW);
    if (!h) return false;
    p_domain_get         = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    p_assembly_open      = (il2cpp_domain_assembly_open_t)dlsym(h, "il2cpp_domain_assembly_open");
    p_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    p_class_from_name    = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    p_class_get_method   = (il2cpp_class_get_method_from_name_t)dlsym(h, "il2cpp_class_get_method_from_name");
    p_method_get_pointer = (il2cpp_method_get_pointer_t)dlsym(h, "il2cpp_method_get_pointer");
    return p_domain_get && p_assembly_open && p_class_from_name && p_class_get_method && p_method_get_pointer;
}

static void* g_image = nullptr;
static void* AX_GetImage() {
    if (g_image) return g_image;
    void* domain = p_domain_get();
    if (!domain) return nullptr;
    const char* asms[] = { "Assembly-CSharp", "Assembly-CSharp-firstpass" };
    for (int i = 0; i < 2; i++) {
        void* a = p_assembly_open(domain, asms[i]);
        if (!a) continue;
        void* img = p_assembly_get_image(a);
        if (img) { g_image = img; return img; }
    }
    return nullptr;
}

static void* AX_FindClass(const char* ns, const char* klass) {
    void* img = AX_GetImage();
    if (!img) return nullptr;
    return p_class_from_name(img, ns, klass);
}

// ------------- вот здесь убран static -------------
void* AX_FindMethodPtr(const char* ns, const char* klass, const char* method, int argc) {
    void* k = AX_FindClass(ns, klass);
    if (!k) return nullptr;
    void* m = p_class_get_method(k, method, argc);
    if (!m) return nullptr;
    return p_method_get_pointer(m);
}

// ---------- WorldToScreen ----------
typedef Vec3 (*WorldToScreen_t)(void*, Vec3, void*);
static WorldToScreen_t p_world_to_screen = nullptr;

bool AX_WorldToScreen(Vec3 world, Vec3* screen) {
    static void* (*get_main)() = nullptr;
    if (!get_main) {
        get_main = (void*(*)())AX_FindMethodPtr("UnityEngine", "Camera", "get_main", 0);
    }
    if (!get_main || !p_world_to_screen) return false;
    void* cam = get_main();
    if (!cam) return false;
    *screen = p_world_to_screen(cam, world, nullptr);
    return screen->z > 0.0f;
}

Vec3 AX_CalcAimAngle(Vec3 from, Vec3 to) {
    Vec3 d = { to.x - from.x, to.y - from.y, to.z - from.z };
    float hyp = sqrtf(d.x*d.x + d.z*d.z);
    Vec3 out;
    out.x = atan2f(-d.y, hyp) * 180.0f / M_PI;
    out.y = atan2f(d.x, d.z) * 180.0f / M_PI;
    out.z = 0;
    return out;
}

// ---------- Update hook ----------
static void (*o_PlayerUpdate)(void*, void*) = nullptr;
static void hk_PlayerUpdate(void* self, void* method) {
    if (o_PlayerUpdate) o_PlayerUpdate(self, method);
    AX_Tick(self);
}

// ---------- install ----------
void AX_InstallRuntimeHooks() {
    if (!AX_ResolveIL2CPP()) {
        NSLog(@"[AX] IL2CPP resolve failed");
        return;
    }
    NSLog(@"[AX] IL2CPP resolved");

    void* p_wts = AX_FindMethodPtr("UnityEngine", "Camera", "WorldToScreenPoint", 1);
    if (p_wts) p_world_to_screen = (WorldToScreen_t)p_wts;
    NSLog(@"[AX] WorldToScreenPoint = %p", p_wts);

    void* p_update = AX_FindMethodPtr("", "Player", "Update", 0);
    if (p_update) {
        MSHookFunction(p_update, (void*)hk_PlayerUpdate, (void**)&o_PlayerUpdate);
        NSLog(@"[AX] Player.Update hooked");
    } else {
        NSLog(@"[AX] Player.Update NOT FOUND");
    }
}
