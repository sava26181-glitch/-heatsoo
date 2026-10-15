#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void AXHide_Install(void);
bool AXHide_IsHiddenPath(const char* path);
bool AXHide_IsHiddenDylib(const char* name);
bool AXHide_IsCallerGame(void);

#ifdef __cplusplus
}
#endif