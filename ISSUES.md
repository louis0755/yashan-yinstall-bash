# Issue Tracker

本仓库问题使用递增编号 `YINSTALL-NNN`，并同步到 GitHub 仓库 `louis0755/yashan-yinstall-bash` 的对应 Issue。提交和关闭说明引用同一编号。

## YINSTALL-001 — C-001 远程检查脚本语法错误

- 发现：2026-08-10
- 错误信息：`bash: line 10: syntax error: unexpected end of file`。
- 影响：数据库安装在 C-001 检查阶段中断。
- 状态：`FIXED`
- 修复：转义 `steps/db.sh` 中嵌套脚本的双引号。

## YINSTALL-002 — C-005 无法识别缩进的 TOML section

- 发现：2026-08-10
- 错误信息：`missing LISTEN_ADDR in [om.config]`。
- 原因：yasboot 生成的 section 带缩进，而 awk 使用整行精确匹配。
- 影响：安装在 C-005 阶段中断。
- 状态：`FIXED`
- 修复：去除 TOML section 首尾空白并保留 `LISTEN_ADDR` 原有缩进。
- 验证：`tests/test_ports.sh`。

## YINSTALL-003 — C-008 非交互 PATH 找不到 runuser

- 发现：2026-08-10
- 错误信息：`bash: line 3: runuser: command not found`。
- 原因：目标机 SSH 非交互 PATH 不含 `/usr/sbin`。
- 状态：`FIXED`
- 修复：验证步骤显式加入 `/usr/sbin:/usr/bin:/bin`。

### YINSTALL-003 补充错误

- 错误信息：`runuser: may not be used by non-root users`。
- 最终修复：只读验证直接执行 yasboot，不再调用 runuser。
- 修复版本：`0.2.12`。

## YINSTALL-004 — 支持绝对内存并计算部署百分比

- 发现：2026-08-10
- 需求：支持整数 `M`/`G`（无单位按 M），根据目标机总内存换算本次部署百分比。
- 状态：`FIXED`
- 修复版本：`0.3.1`。

## YINSTALL-005 — 整数百分比存在绝对内存粒度限制

- 发现：2026-08-10
- 错误信息：`1G` 在 `515250M` 主机上向上取整为 `1%`，实际约 `5152M`。
- 状态：`FIXED`
- 修复：直接修改 `hosts.toml` 和集群 TOML 中的 `memory_limit`，不再换算百分比。

## YINSTALL-006 — 重部署 force 未传递给 yasboot

- 发现：2026-08-10
- 错误信息：`file /home/yashan/.yasboot/ys1903.env is already exist`、`yasdb path ... should be empty`。
- 原因：yinstall 的 `--force` 没有传给 `yasboot package se gen`。
- 状态：`FIXED`
- 修复版本：`0.3.2`
- 修复：force 重部署时向 yasboot 生成命令传递 `--force`。

## YINSTALL-007 — 默认推荐内存并缺少列存缓冲配置

- 发现：2026-08-10
- 错误信息：`node 1-1 memory_limit 1024M is less than 5152MB`。
- 原因：配置生成命令无条件传入 `--recommend-param`，且生成后未设置 `COLUMNAR_BUFFER_SIZE`。
- 需求：默认不启用推荐内存；显式选项才启用推荐；绝对内存覆盖 TOML；节点配置写入 `COLUMNAR_BUFFER_SIZE = "256M"`。
- 状态：`FIXED`
- 修复版本：`0.3.2`
- 补充错误：默认非推荐模式生成的 TOML 无 `memory_limit`，报 `missing memory_limit in [[host]]`。
- 最终修复版本：`0.3.3`，改为字段存在时更新、缺失时插入。

## YINSTALL-008 — 安装器缺少 MySQL 模式和端口配置

- 发现：2026-08-10
- 错误信息：CLI 无 MySQL 模式参数，无法向 yasboot 传递 `-m mysql` 或设置 `mysql_addr`。
- 需求：增加 MySQL 模式、端口校验、预检查和 TOML 修改。
- 状态：`IN PROGRESS`
- 补充错误：`YAS-00021 failed to get parameter item by name, parameter "MYSQL_ADDR" does not exist`。
- 原因：`mysql_addr` 被插入错误 section；应更新 yasboot 在 `[[group.node]]` 生成的字段。

## YINSTALL-009 — 删除推荐内存与百分比参数

- 发现：2026-08-10
- 问题：安装器仍暴露 `--recommend-memory` 和 `--memory-limit`。
- 需求：删除两个参数和对应生成逻辑，仅保留绝对内存 `--memory-size`。
- 状态：`IN PROGRESS`
