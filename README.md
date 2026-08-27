# yinstall

`yinstall` 是 Linux 上的 YashanDB 安装工具，负责操作系统准备、软件包安装、
yasboot 配置生成和 `hosts.toml` 端口写入。它可独立维护，也可由 `myas` 调用。

## 本地单机

本地模式使用 `--local`，不使用 SSH 或 SCP。sys 密码由 `myas` 的 `SYS_PASSWORD`
传入，直接调用时必须指定 `--db-admin-password`。yasboot 生成配置使用 `-N`；部署
使用 `-p` 传入 sys 密码。执行账户仍须拥有免交互 `sudo -n`，以完成系统参数、用户、
目录和防火墙准备。

```bash
./yinstall.sh db install --local \
  --package /data/software/yashandb-23.4.14.100-linux-x86_64.tar.gz \
  --db-admin-password '替换为实际 sys 密码' \
  --cluster ys1703 --db-port 1703 \
  --install-path /data/yashan/ys1703/yasdb-home \
  --data-path /data/yashan/ys1703/yasdb-data \
  --log-path /data/yashan/ys1703/yasdb-log \
  --stage-dir /data/yashan/ys1703/install
```

## 远程部署

远程模式需要 `--target`、SSH 认证和数据库管理员密码：

```bash
./yinstall.sh db install --target 192.168.23.4 --ssh-user yashan \
  --package ./YashanDB.tar.gz --db-port 1703 \
  --db-admin-password '替换为实际密码'
```

一主一备可在一次生成中指定：

```bash
./yinstall.sh db install --target 192.168.23.4 --host-ip 192.168.23.4 \
  --standbys 192.168.23.13 --package ./YashanDB.tar.gz \
  --db-admin-password '替换为实际密码' --cluster ys18003 --db-port 18003
```

执行主机必须能以 `SSH_USER` 免密连接每台备机。安装器会先检查该连接，然后使用
`yasboot package se gen --no-password --ip 192.168.23.4,192.168.23.13 --node 2
--standby-node 1` 一次生成主备 TOML；不会执行后置 `cluster join`。

`--db-port P` 管理连续端口：Yasom=`P-2`、Yasagent=`P-1`、YashanDB=`P`、
Replicat=`P+1`，并会更新生成的 `hosts.toml`。先使用 `--precheck` 或
`--dry-run` 进行验证。运行 `tests/test_cli.sh` 和 `tests/test_ports.sh` 执行
自动化测试。

安装时可使用无值开关 `--use-native-type`，在数据库节点配置中写入
`USE_NATIVE_TYPE = true`；不指定时保留 yasboot 生成的默认值。

可通过 `--character-set CHARSET` 指定字符集，支持 `ASCII`、`ISO88591`、`GBK`、
`UTF8` 和 `GB18030`；未指定时保留 yasboot 生成的默认值。
