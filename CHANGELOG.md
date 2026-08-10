# 变更记录

## 0.4.1 - 2026-08-10

### 修复

- 修正 MySQL 地址的 TOML section，避免将 `mysql_addr` 当成数据库参数。

## 0.4.0 - 2026-08-10

### 新增

- 支持 `--mode mysql --mysql-port PORT`，生成 MySQL 模式配置并设置 `mysql_addr`。

### 变更

- 删除 `--recommend-memory` 和 `--memory-limit`，只保留 `--memory-size`。

## 0.3.3 - 2026-08-10

### 修复

- `memory_limit` 不存在时在 `[[host]]` 和 `[[group.node]]` 中插入绝对内存值。

## 0.3.2 - 2026-08-10

### 变更

- 默认不启用 yasboot 推荐内存，新增 `--recommend-memory` 显式开关。
- 生成 TOML 后写入 `COLUMNAR_BUFFER_SIZE = "256M"`。

## 0.3.1 - 2026-08-10

### 修复

- `--memory-size` 直接更新 `hosts.toml` 和 `${cluster}.toml` 的内存值。

## 0.3.0 - 2026-08-10

### 新增

- 支持 `--memory-size` 绝对内存配置，并在每次部署前按目标机总内存计算百分比。

## 0.2.12 - 2026-08-10

### 修复

- C-008/E-001/E-017 直接以当前 SSH 用户运行 yasboot，避免非 root 用户调用 runuser。

## 0.2.11 - 2026-08-10

### 修复

- 为非交互验证补充系统 PATH，修复 C-008 找不到 `runuser`（YINSTALL-003）。

## 0.2.10 - 2026-08-10

### 修复

- 兼容缩进的 `[om.config]` 和 `[host.yasagent.config]` section（YINSTALL-002）。

## 0.2.9 - 2026-08-10

### 修复

- 修复 C-001 生成脚本的嵌套引号，避免远程执行时报 `unexpected end of file`。

## 0.2.8 - 2026-08-07

### 修复

- 固定本地 sudo 调用为 `/usr/bin/sudo`，兼容 devtoolset 环境。

## 0.2.7 - 2026-08-07

### 修复

- 使用 `/usr/bin/sudo` 执行特权脚本，避免 devtoolset PATH 覆盖。

## 0.2.6 - 2026-08-07

### 修复

- 固定 sudo 调用使用 `/usr/bin:/bin`，兼容 devtoolset 环境。

## 0.2.5 - 2026-08-07

### 修复

- 使用 `command sudo` 绕过环境中的同名 shell 函数，修复本地安装失败。

## 0.2.4 - 2026-08-07

### 修复

- 修复通过软链接启动时无法定位 `VERSION` 和模块目录的问题。

## 0.2.3 - 2026-08-07

### 新增

- 支持使用 `--generate-script` 生成由客户手工执行的本地安装脚本。
- 重命名公共模块为 `yins-common.sh`，避免与 myas 冲突。

## 0.2.2 - 2026-08-06

### 变更

- 本地和远程安装均要求传入 sys 密码；本地部署将其传给 `yasboot cluster deploy -p`。

## 0.2.1 - 2026-08-06

### 新增

- 新增 `--local` 单机部署模式，无需 SSH、SCP 或数据库管理员密码。
- 本地生成配置时使用 yasboot `-N`。

## 0.2.0 - 2026-08-06

### 新增

- 新增 `--db-port`，管理 Yasom、Yasagent、YashanDB 和 Replicat 端口。
- 生成 TOML 后修改 Yasom 和 Yasagent 监听地址。
- 增加版本元数据和端口配置测试。

## 0.1.0 - 2026-08-06

### 新增

- 初始单机主库、备库、操作系统准备和清理流程。
