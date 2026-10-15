#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <dirent.h>
#import <unistd.h>
#import <fcntl.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <errno.h>
#import <stdarg.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import "hide.h"

#ifdef __cplusplus
extern "C" {
#endif

// ============ защита caller ============
// возвращаем true ТОЛЬКО если стек вызова идёт из процесса Standoff 2.
// используется dladdr(return_address).
bool AXHide_IsCallerGame(void) {
    Dl_info info;
    void* ret = __builtin_return_address(0);
    if (!ret) return true;  // fallback — фильтруем
    if (dladdr(ret, &info) == 0) return true;
    if (!info.dli_fname) return true;
    // если имя образа содержит standoff2 — фильтруем
    if (strstr(info.dli_fname, "standoff2") ||
        strstr(info.dli_fname, "Standoff2")) {
        return true;
    }
    // если это твик сам — фильтруем
    if (strstr(info.dli_fname, "AXHideJB")) return true;
    // если это libsystem_kernel — фильтруем
    if (strstr(info.dli_fname, "libsystem")) return true;
    return false;
}

// ============ список скрываемых путей ============
static const char* kHiddenSubstrings[] = {
    "/var/jb",
    "/Library/MobileSubstrate",
    "/usr/lib/libsubstrate",
    "/usr/lib/libellekit",
    "/usr/lib/libhooker",
    "/usr/lib/TweakInject",
    "/usr/lib/libjailbreak",
    "/usr/lib/libkrw",
    "/usr/lib/libkernrw",
    "MobileSubstrate",
    "SubstrateLoader",
    "substrate.dylib",
    "ElleKit",
    "ellekit",
    "TweakInject",
    "AxMenu.dylib",
    "AXMenu.dylib",
    "AXHideJB.dylib",
    "cydia://",
    "sileo://",
    "zbra://",
    "/Applications/Sileo.app",
    "/Applications/Zebra.app",
    "/Applications/Cydia.app",
    "/Applications/Dopamine.app",
    "/Applications/TrollStore.app",
    "frida",
    "frida-server",
    "gum-ios",
    "cynject",
    "libcycript",
    "cycript",
    "/usr/sbin/frida",
    "/usr/bin/cycript",
    "/etc/apt",
    "/var/lib/dpkg",
    "/var/lib/apt",
    "/var/cache/apt",
    "/var/lib/cydia",
    "jailbreakd",
    "amfid_patch",
    NULL
};

static const char* kHiddenDylibNames[] = {
    "Substrate",
    "substrate",
    "ElleKit",
    "ellekit",
    "TweakInject",
    "AxMenu",
    "AXMenu",
    "AXHideJB",
    "Cycript",
    "cycript",
    "FridaGadget",
    "frida",
    "gum-ios",
    "jailbreakd",
    NULL
};

bool AXHide_IsHiddenPath(const char* path) {
    if (!path) return false;
    for (int i = 0; kHiddenSubstrings[i]; i++) {
        if (strstr(path, kHiddenSubstrings[i])) return true;
    }
    return false;
}

bool AXHide_IsHiddenDylib(const char* name) {
    if (!name) return false;
    for (int i = 0; kHiddenDylibNames[i]; i++) {
        if (strstr(name, kHiddenDylibNames[i])) return true;
    }
    return false;
}

// ============ fopen ============
static FILE* (*o_fopen)(const char*, const char*) = NULL;
static FILE* hk_fopen(const char* path, const char* mode) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return NULL;
    }
    return o_fopen(path, mode);
}

// ============ open (с защитой va_arg) ============
static int (*o_open)(const char*, int, ...) = NULL;
static int hk_open(const char* path, int flags, ...) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return -1;
    }
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    return o_open(path, flags, mode);
}

// ============ stat / lstat ============
static int (*o_stat)(const char*, struct stat*) = NULL;
static int hk_stat(const char* path, struct stat* buf) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return o_stat(path, buf);
}

static int (*o_lstat)(const char*, struct stat*) = NULL;
static int hk_lstat(const char* path, struct stat* buf) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return o_lstat(path, buf);
}

// ============ access ============
static int (*o_access)(const char*, int) = NULL;
static int hk_access(const char* path, int mode) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return o_access(path, mode);
}

// ============ opendir / readdir ============
static DIR* (*o_opendir)(const char*) = NULL;
static DIR* hk_opendir(const char* path) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return NULL;
    }
    return o_opendir(path);
}

static struct dirent* (*o_readdir)(DIR*) = NULL;
static struct dirent* hk_readdir(DIR* dirp) {
    if (!dirp) return NULL;
    struct dirent* entry = o_readdir(dirp);
    while (entry && AXHide_IsHiddenDylib(entry->d_name)) {
        entry = o_readdir(dirp);
    }
    return entry;
}

// ============ readlink ============
static ssize_t (*o_readlink)(const char*, char*, size_t) = NULL;
static ssize_t hk_readlink(const char* path, char* buf, size_t bufsize) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return o_readlink(path, buf, bufsize);
}

// ============ realpath ============
static char* (*o_realpath)(const char*, char*) = NULL;
static char* hk_realpath(const char* path, char* resolved) {
    if (AXHide_IsCallerGame() && AXHide_IsHiddenPath(path)) {
        errno = ENOENT;
        return NULL;
    }
    return o_realpath(path, resolved);
}

// ============ getenv ============
static char* (*o_getenv)(const char*) = NULL;
static char* hk_getenv(const char* name) {
    if (name && (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 ||
                 strcmp(name, "_MSSafeMode") == 0 ||
                 strcmp(name, "JB_ROOT") == 0 ||
                 strcmp(name, "DYLD_LIBRARY_PATH") == 0)) {
        return NULL;
    }
    return o_getenv(name);
}

// ============ dyld — БЕЗ изменения count ============
static uint32_t (*o_dyld_image_count)(void) = NULL;
static uint32_t hk_dyld_image_count(void) {
    // не трогаем count — Unity ломается
    return o_dyld_image_count();
}

static const char* (*o_dyld_get_image_name)(uint32_t) = NULL;
static const char* hk_dyld_get_image_name(uint32_t idx) {
    const char* name = o_dyld_get_image_name(idx);
    if (name && AXHide_IsHiddenDylib(name)) {
        return "";  // пустая строка вместо NULL — не ломает индексацию
    }
    return name;
}

// ============ sysctl — с полной защитой ============
static int (*o_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = NULL;
static int hk_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    int r = o_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r != 0) return r;
    if (!oldp || !oldlenp) return r;
    if (*oldlenp == 0) return r;
    if (namelen < 2) return r;
    if (name[0] != CTL_KERN) return r;
    if (name[1] != KERN_PROC) return r;
    struct kinfo_proc* kp = (struct kinfo_proc*)oldp;
    size_t cnt = *oldlenp / sizeof(struct kinfo_proc);
    for (size_t i = 0; i < cnt; i++) {
        kp[i].kp_proc.p_flag &= ~0x00000800;  // P_TRACED
        kp[i].kp_proc.p_flag &= ~0x00000004;  // P_LTRACED
    }
    return r;
}

// ============ ptrace ============
typedef int (*ptrace_t)(int, pid_t, caddr_t, int);
static ptrace_t o_ptrace = NULL;
static int hk_ptrace(int req, pid_t pid, caddr_t addr, int data) {
    if (req == 31) return 0;  // PT_DENY_ATTACH
    return o_ptrace ? o_ptrace(req, pid, addr, data) : 0;
}

// ============ csops ============
extern "C" int csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize);
typedef int (*csops_t)(pid_t, unsigned int, void*, size_t);
static csops_t o_csops = NULL;
static int hk_csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize) {
    if (ops == 0 && useraddr && usersize >= 4) {
        // CS_OPS_STATUS — отдаём фейковый валидный статус
        uint32_t* status = (uint32_t*)useraddr;
        *status = 0x1;  // CS_VALID
        return 0;
    }
    return o_csops ? o_csops(pid, ops, useraddr, usersize) : -1;
}

// ============ mach_vm_region_recurse ============
typedef kern_return_t (*mvr_t)(vm_map_t, mach_vm_address_t*, natural_t*, vm_region_recurse_info_t, natural_t*);
static mvr_t o_mvr = NULL;
static kern_return_t hk_mvr(vm_map_t task, mach_vm_address_t* address, natural_t* nesting, vm_region_recurse_info_t info, natural_t* infoCnt) {
    kern_return_t kr = o_mvr ? o_mvr(task, address, nesting, info, infoCnt) : KERN_FAILURE;
    if (kr != KERN_SUCCESS) return kr;
    // если у региона jb-имя — пропускаем
    vm_region_submap_info_data_64_t* sub = (vm_region_submap_info_data_64_t*)info;
    if (sub && sub->object_id == 0) {
        // fallback pass-through
    }
    return kr;
}

// ============ установка ============
void AXHide_Install(void) {
    NSLog(@"[AXHide] installing hooks v1.0.0...");

    MSHookFunction((void*)fopen,     (void*)hk_fopen,     (void**)&o_fopen);
    MSHookFunction((void*)open,      (void*)hk_open,      (void**)&o_open);
    MSHookFunction((void*)stat,      (void*)hk_stat,      (void**)&o_stat);
    MSHookFunction((void*)lstat,     (void*)hk_lstat,     (void**)&o_lstat);
    MSHookFunction((void*)access,    (void*)hk_access,    (void**)&o_access);
    MSHookFunction((void*)opendir,   (void*)hk_opendir,   (void**)&o_opendir);
    MSHookFunction((void*)readdir,   (void*)hk_readdir,   (void**)&o_readdir);
    MSHookFunction((void*)readlink,  (void*)hk_readlink,  (void**)&o_readlink);
    MSHookFunction((void*)realpath,  (void*)hk_realpath,  (void**)&o_realpath);
    MSHookFunction((void*)getenv,    (void*)hk_getenv,    (void**)&o_getenv);
    MSHookFunction((void*)_dyld_image_count,    (void*)hk_dyld_image_count,    (void**)&o_dyld_image_count);
    MSHookFunction((void*)_dyld_get_image_name, (void*)hk_dyld_get_image_name, (void**)&o_dyld_get_image_name);
    MSHookFunction((void*)sysctl,    (void*)hk_sysctl,    (void**)&o_sysctl);

    void* pt = dlsym(RTLD_DEFAULT, "ptrace");
    if (pt) MSHookFunction(pt, (void*)hk_ptrace, (void**)&o_ptrace);

    void* cs = dlsym(RTLD_DEFAULT, "csops");
    if (cs) MSHookFunction(cs, (void*)hk_csops, (void**)&o_csops);

    void* mvr = dlsym(RTLD_DEFAULT, "mach_vm_region_recurse");
    if (mvr) MSHookFunction(mvr, (void*)hk_mvr, (void**)&o_mvr);

    NSLog(@"[AXHide] all hooks installed");
}

#ifdef __cplusplus
}
#endif
