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
- 状态：`FIXED`
- 修复版本：`0.4.1`
- 补充错误：`YAS-00021 failed to get parameter item by name, parameter "MYSQL_ADDR" does not exist`。
- 原因：`mysql_addr` 被插入错误 section；应更新 yasboot 在 `[[group.node]]` 生成的字段。

## YINSTALL-009 — 删除推荐内存与百分比参数

- 发现：2026-08-10
- 问题：安装器仍暴露 `--recommend-memory` 和 `--memory-limit`。
- 需求：删除两个参数和对应生成逻辑，仅保留绝对内存 `--memory-size`。
- 状态：`FIXED`
- 修复版本：`0.4.0`

## YINSTALL-010 — 主备生成的 hosts.toml 中备机 yasagent LISTEN_ADDR 使用主库 IP

- 发现：2026-09-17
- GitHub：[louis0755/yashan-yinstall-bash#10](https://github.com/louis0755/yashan-yinstall-bash/issues/10)
- 错误信息：`listen tcp 192.168.23.4:19208: bind: cannot assign requested address`、`YAS-00415 failed to create listener, host: 192.168.23.13:19210`、`task completed, status: CANCELED`。
- 现象：`myas create reltest-ha 23.4.14.105 --target 192.168.23.4 --host-ip 192.168.23.4 --standbys 192.168.23.13 --db-port 19209` 时，备机 `192.168.23.13` 的 yasagent 尝试绑定主库地址 `192.168.23.4:19208` 而失败，主备部署任务被取消。
- 原因：`yasboot package se gen --ip 192.168.23.4,192.168.23.13 --node 2 --standby-node 1` 生成的 `hosts.toml` 中，`host0002` 的 `[host.yasagent.config] LISTEN_ADDR` 被写成主库 IP；同目录 `ys19209.toml` 的两个节点地址是正确的。
- 影响：一主一备一次性部署无法成功；失败后主备两侧残留进程、目录和 yasboot 环境，且远程目标登记无法用 `myas delete` 清理（yashan-myas#22）。
- 状态：`FIXED`
- 排期：`0.4.7`
- 修复版本：`0.4.7`
- 修复：生成或后处理 `hosts.toml` 时按每个 `[[host]]` 的 `ip` 写入该节点自己的 yasagent `LISTEN_ADDR`；补 CLI 测试断言双节点各自 IP；在 `.4 → .13` 复测完整主备部署与角色/复制验证。
- 验证：`steps/host-addrs.awk` + `tests/test_cli.sh` 双节点夹具通过，缺失 `ip` 时失败；真实主机 `.4 → .13` 的主备复测待 0.4.7 组合包部署后执行。

## YINSTALL-011 — `--memory-size` 未生效：数据库仍是默认内存池

- 发现：2026-09-18
- GitHub：[louis0755/yashan-yinstall-bash#11](https://github.com/louis0755/yashan-yinstall-bash/issues/11)
- 现象：`myas create test-2356100 23.5.6.100 --db-port 1907 --memory-size 10G` 创建成功后，数据库内
  `select dbms_param.show_memory_limit() from dual` 显示 `memory limit 2.78372G`（默认池子之和），
  同机 `--memory-size 100G` 的实例同样是 `2.78187G`。
- 原因：0.3.x/0.4.x 只把绝对值写入 `hosts.toml` 和集群 TOML 的 `memory_limit`，生成命令不再传
  `--recommend-param`；yasboot 只在启用推荐参数时才计算数据库内存池，因此参数保持默认值。
- 影响：`MEMORY_SIZE` / `--memory-size` 对数据库实际可用内存没有作用，只影响节点级 `memory_limit`。
- 状态：`FIXED`
- 修复版本：`0.4.8`
- 修复：配置生成时按目标主机内存把绝对大小换算成百分比（向上取整，夹在 1–100），生成命令传
  `--recommend-param --memory-limit <百分比>`；仍保留 TOML 的绝对 `memory_limit`。未指定内存尺寸时不启用推荐参数。
- 注意：yasboot 对每节点内存有最小值限制（约主机内存的 1%），请求值小于该下限时会被抬到下限。
- 验证：`tests/test_ports.sh` 断言两条路径；真实主机 `192.168.23.13` 重建 10G/100G 实例后 `show_memory_limit()` 复核。

## YINSTALL-012 — 绝对内存落在百分比边界下方，部署端份额被截断

- 发现：2026-09-18
- GitHub：[louis0755/yashan-yinstall-bash#12](https://github.com/louis0755/yashan-yinstall-bash/issues/12)
- 现象：`--memory-size 10G` 的实例（`192.168.23.13`，主机 514599M）数据库内 `show_memory_limit()` 只有 3.18328G，
  而同一个包在 100G 档给出 92.29G。
- 原因：生成阶段按 2% 生成了 `memory_limit = "10291M"`，随后 C-005 把它覆写成精确的 `10240M`（=主机的 1.99%）；
  部署阶段 yasom 反算份额时按整数截断 → `percent of memory_limit: 1%(10240M)`，推荐参数按 1% 计算，
  `optimize parameter DATA_BUFFER_SIZE to 1141359529`（约 1.06G），池子合计 3.18G。
- 影响：请求值与数据库实际内存之间出现"掉一档"的偏差，且偏差在小内存档最明显。
- 状态：`FIXED`
- 修复版本：`0.4.9`
- 修复：C-005 写 TOML 时使用"覆盖请求值的最小 1% 边界值"（`percent=ceil(size*100/total)`，写入 `ceil(percent*total/100)M`），
  使部署端反算出的份额与生成阶段一致。
- 验证：`tests/test_ports.sh` 按目标机内存动态断言；真实主机重建后核对部署日志的 `percent of memory_limit` 与 `show_memory_limit()`。
