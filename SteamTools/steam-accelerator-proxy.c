// steam-accelerator-proxy.c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <limits.h>
#include <libgen.h>

void die(const char *msg) {
    fprintf(stderr, "Error: %s: %s\n", msg, strerror(errno));
    exit(1);
}

int main(int argc, char *argv[], char *envp[]) {
    (void)envp;  // 不使用传入的 envp，我们从头构建
    
    char self_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", self_path, sizeof(self_path) - 1);
    if (len == -1) {
        die("Failed to get executable path");
    }
    self_path[len] = '\0';
    
    char *self_dir = dirname(self_path);
    
    // 调试模式
    char *debug = getenv("WATT_TOOLKIT_DEBUG");
    if (debug && strcmp(debug, "1") == 0) {
        fprintf(stderr, "Proxy path: %s\n", self_path);
        fprintf(stderr, "Proxy dir: %s\n", self_dir);
    }
    
    // 构建真实程序路径
    char real_path[PATH_MAX];
    snprintf(real_path, sizeof(real_path), "%s/Steam++.Accelerator.real", self_dir);
    
    if (access(real_path, X_OK) != 0) {
        fprintf(stderr, "Error: Cannot find %s\n", real_path);
        return 1;
    }
    
    if (debug && strcmp(debug, "1") == 0) {
        fprintf(stderr, "Real program: %s\n", real_path);
    }
    
    // 手动构建环境变量数组
    char *new_env[100];
    int env_idx = 0;
    
    // 设置 DOTNET_ROOT
    char dotnet_root_buf[PATH_MAX];
    snprintf(dotnet_root_buf, sizeof(dotnet_root_buf), "DOTNET_ROOT=%s", DOTNET_ROOT);
    new_env[env_idx++] = strdup(dotnet_root_buf);
    
    // 设置 DOTNET_ROOT_X64（AppHost 也会检查这个）
    char dotnet_root_x64_buf[PATH_MAX];
    snprintf(dotnet_root_x64_buf, sizeof(dotnet_root_x64_buf), "DOTNET_ROOT_X64=%s", DOTNET_ROOT);
    new_env[env_idx++] = strdup(dotnet_root_x64_buf);
    
    // 设置 LD_LIBRARY_PATH
    char ld_path_buf[PATH_MAX];
    snprintf(ld_path_buf, sizeof(ld_path_buf), "LD_LIBRARY_PATH=%s", LD_LIBRARY_PATH);
    new_env[env_idx++] = strdup(ld_path_buf);
    
    // 设置其他环境变量
    char bundle_cache_buf[PATH_MAX];
    snprintf(bundle_cache_buf, sizeof(bundle_cache_buf), "DOTNET_BUNDLE_EXTRACT_BASE_DIR=%s", CACHE_DIR);
    new_env[env_idx++] = strdup(bundle_cache_buf);
    new_env[env_idx++] = strdup("DOTNET_GCHeapHardLimitPercent=50");
    new_env[env_idx++] = strdup("DOTNET_EnableDiagnostics=0");
    
    // 复制其他有用的环境变量（排除可能干扰的）
    extern char **environ;
    for (char **env = environ; *env && env_idx < 98; env++) {
        // 跳过我们已设置的变量
        if (strncmp(*env, "DOTNET_ROOT=", 12) == 0 ||
            strncmp(*env, "DOTNET_ROOT_X64=", 16) == 0 ||
            strncmp(*env, "LD_LIBRARY_PATH=", 16) == 0) {
            continue;
        }
        // 跳过不安全的变量
        if (strncmp(*env, "LD_PRELOAD=", 11) == 0 ||
            strncmp(*env, "LD_AUDIT=", 9) == 0 ||
            strncmp(*env, "LD_DEBUG=", 9) == 0) {
            continue;
        }
        new_env[env_idx++] = *env;
    }
    new_env[env_idx] = NULL;
    
    // 构建参数数组
    char **new_argv = malloc((argc + 2) * sizeof(char*));
    if (!new_argv) {
        die("Memory allocation failed");
    }
    
    new_argv[0] = real_path;
    for (int i = 1; i < argc; i++) {
        new_argv[i] = argv[i];
    }
    new_argv[argc] = NULL;
    
    if (debug && strcmp(debug, "1") == 0) {
        fprintf(stderr, "=== Proxy Debug Info ===\n");
        fprintf(stderr, "DOTNET_ROOT macro: %s\n", DOTNET_ROOT);
        fprintf(stderr, "LD_LIBRARY_PATH macro: %s\n", LD_LIBRARY_PATH);
        fprintf(stderr, "CACHE_DIR macro: %s\n", CACHE_DIR);
        fprintf(stderr, "Building environment array:\n");
        for (int i = 0; new_env[i]; i++) {
            fprintf(stderr, "  env[%d]: %s\n", i, new_env[i]);
        }
        fprintf(stderr, "=========================\n");
    }
    
    // 执行真实程序
    if (debug && strcmp(debug, "1") == 0) {
        fprintf(stderr, "Executing: %s\n", real_path);
        fprintf(stderr, "Using environment array with %d variables\n", env_idx);
    }
    
    execve(real_path, new_argv, new_env);
    
    fprintf(stderr, "Error: Failed to execute %s: %s\n", real_path, strerror(errno));
    return 1;
}