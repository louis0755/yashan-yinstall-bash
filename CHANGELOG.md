# 变更记录

## 0.4.14 - 2026-10-13

### 文档

- `--help` 的 `--legacy` 说明补上字符集限制：只支持 `ASCII`、`ISO88591`、`GBK`、`UTF8`，
  22.2 系列没有 `GB18030`。与 0.4.13 的校验行为一致，仅帮助文本补齐。

### 测试

- `tests/test_ports.sh` 的 legacy 用例改为断言 C-006 传给 yasboot 的 `-i` 参数是目标主机上的
  上传路径（`/data/yashan/soft/yashandb.tar.gz`），而不只是断言出现过 `-i`。

## 0.4.13 - 2026-10-13

### 修复

- `--legacy` 现在拒绝 `--character-set GB18030`：22.2 系列的建库字符集只有
  `ASCII`、`ISO88591`、`GBK`、`UTF8`（见 22.2.16.101 包内 `conf/database_options.json`
  与 22.2 文档的配置参数、CREATE DATABASE、yasboot 建库参数三处），`GB18030` 是 23.x 才
  有的取值。此前该组合会一路走到 `cluster deploy` 才由 yasdb 报错，现在在参数校验阶段
  直接给出原因。
- `tests/test_cli.sh` 增加对应用例。

## 0.4.12 - 2026-10-13

### 新增

- 新增 `--legacy`：安装 22.2 这类老版本的安装包。老包是"平铺"布局（`admin/`、`bin/`、
  `conf/`、`lib/`、`scripts/` 等直接在包根，没有 23.x 的内层 `database-*.tar.gz`），
  且 yasboot 没有 `package se gen`。该模式改用：
  - C-003 以 `bin/yasboot` + `bin/yasdb` 判定包完整性，不再要求内层 `database-*.tar.gz`；
  - C-004 改用 `yasboot package config gen --cluster ... --yas-type SE`（老版 yasboot 由
    `--begin-port` 直接推导数据库监听端口，因此这里传数据库端口而不是 Yasom 端口）；
  - C-005 不再写入 `COLUMNAR_BUFFER_SIZE`（22.2 无此参数，写入会在部署时被拒）；
  - C-006 改用 `yasboot package install -i <安装包> -t hosts.toml`，并跳过 23.x 的
    `<install-path>/<version>` 路径重写（老版 yasboot 自行落成
    `<install-path>/yashandb/<version>`）。
- `--legacy` 仅支持单机：与 `--standbys`、`--mode mysql`、`--use-native-type`、
  `--memory-size` 组合会被明确拒绝；`--log-path` 在该模式下不生效（老版 yasboot 把日志
  放在安装目录下），因此 myas 登记里的 log_path 对老版本只是记录值。

## 0.4.11 - 2026-10-12

### 新增

- 新增 `--db-version VERSION`：软件按 `<install-path>/<version>` 安装。yasboot 的 `package se gen`
  只写"发布版本"（`27.1.1.2-356-gd953d3665a9` 被写成 `27.1.1.2`），而 `package install` 实际按
  `hosts.toml` 里每个 host 的 `path` 落地，因此 C-006 在安装前用新增的 `steps/host-path.awk`
  重写该字段（YINSTALL-014）。带构建后缀的内部构建包因此可以获得与版本号一致的 `YASDB_HOME`
  目录名；不带 `--db-version` 时行为不变（不做任何重写）。
- `tests/test_ports.sh` 增加三组断言：C-006 的重写发生在 `package install` 之前；未传
  `--db-version` 时不重写；`host-path.awk` 保留缩进并替换全部 `path` 行。

## 0.4.10 - 2026-10-12

### 修复

- C-001/C-000 的端口占用检查修正为"精确端口匹配"：嵌套脚本里 `grep -Eq` 的模式引号没有转义，外层双引号
  把 `"[:.]${port}$"` 拆开后 `$` 锚点丢失，检查退化成"任意位置包含 `:端口`"。五位数监听端口会误报，
  例如邻居集群的 `:19205`/`:19206` 让 `1920` 显示为已占用，`--db-port 1919` 的预检因此失败
  （YINSTALL-013）。
- `tests/test_ports.sh` 增加回归用例：五位数监听端口不得判为冲突；真正精确监听受管端口时仍必须失败。

## 0.4.9 - 2026-09-18

### 修复

- TOML 的 `memory_limit` 改为写"覆盖请求值的最小 1% 边界值"：部署时 yasom 会按 `memory_limit/主机内存` 反算整数百分比，写精确绝对值可能刚好落在边界之下（例如 `10240M` 在 514599M 主机上是 1.99%），被截断成 1% 后推荐参数按 1% 计算，数据库内存被显著压低（YINSTALL-012）。
- C-005 现在接收请求的 MB 数并在目标机上换算：`percent = ceil(size*100/total)`，写入 `ceil(percent*total/100)M`，并打印 `memory_limit ... (N% of ...M, requested ...M)`。
- `tests/test_ports.sh` 的 C-005 用例改为按目标机内存动态计算期望值。

## 0.4.8 - 2026-09-18

### 修复

- `--memory-size` 现在真正下发到数据库参数：配置生成改为按目标主机内存把绝对大小换算成百分比，并传递 `--recommend-param --memory-limit <百分比>`，由 yasboot 计算内存池大小；此前只写 TOML 的 `memory_limit`，数据库实际仍是默认池子（合计约 2.78G）。`COLUMNAR_BUFFER_SIZE` 等既有处理不变（YINSTALL-011）。
- 未指定 `--memory-size` 时不启用推荐参数，保持原有默认行为。
- `tests/test_ports.sh` 增加两条断言：无内存参数时生成命令不得出现 `--recommend-param`；`--memory-size 10G` 时必须出现 `--recommend-param --memory-limit ${memory_percent}` 且百分比按 `10240M` 计算。

## 0.4.7 - 2026-09-18

### 修复

- 主备部署时按每个 `[[host]]` 的 `ip` 重写 `hosts.toml` 中该节点自己的 `[host.yasagent.config] LISTEN_ADDR`；此前 `yasboot package se gen` 会把第一个 host 的 IP 写进所有 host 块，导致备机 yasagent 绑定不属于自己的地址而失败（YINSTALL-010）。
- 新增 `steps/host-addrs.awk` 与对应 CLI 测试：双节点夹具断言两台主机各自使用自己的地址，缺失 `ip` 时明确失败而不是保留错误地址。
- 默认日志目录改为安装器目录下的 `logs/`（可用 `--log-dir` 覆盖），避免从其他工作目录调用 `yinstall` 时在调用目录生成日志。

## 0.4.6 - 2026-08-27

### 新增

- 支持 `db install --standbys` 在一次 yasboot 配置生成中创建主备节点。
- 无密码模式下检查执行主机到备机的免密 SSH 连接。
- 主备预检检查备机所需端口。

### 修复

- 单机配置生成时由远端 shell 正确展开目标主机 IP，避免将变量文本传给 yasboot。

### 安全

- 数据库管理员密码通过环境变量传入，不再要求出现在命令行参数中。
- 增加自动化发布门禁和密码传递回归测试。

## 0.4.5 - 2026-08-27

### 修复

- 兼容不支持 `StrictHostKeyChecking=accept-new` 的旧版 OpenSSH，自动降级为兼容模式。

## 0.4.4 - 2026-08-27

### 修复

- 远程备库上传使用 `scp -P` 传递 SSH 端口。
- 备库流程任一步骤失败时立即停止，避免继续使用不完整的安装目录。

## 0.4.3 - 2026-08-26

### 新增

- 支持 `--host-ip`/`--ip`，在 yasboot 生成 TOML 时指定节点 IP。

## 0.4.2 - 2026-08-26

### 新增

- 支持 `--character-set CHARSET` 修改生成的数据库集群配置。

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
