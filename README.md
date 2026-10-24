# libzbar APK for Alpine 3.8（pyzbar 可用）

[![build-apk](https://github.com/dainan13/libzbar-alpine/actions/workflows/build.yml/badge.svg)](https://github.com/dainan13/libzbar-alpine/actions/workflows/build.yml)

在 **Alpine 3.8**（x86_64 / musl）上从源码编译
[zbar 0.23.93](https://github.com/mchehab/zbar)，打包成 Alpine apk，并用
`python3 + pyzbar` 做端到端验证。

交付的是 pyzbar 所依赖的 **C 共享库 libzbar**，不是 pyzbar 本身
（pyzbar 是纯 Python 包，用 `pip3 install pyzbar` 安装，运行时通过
`ctypes.util.find_library('zbar')` 动态加载 `libzbar.so.0`）。

构建和测试由 GitHub Actions 自动完成：普通 push 产出构建 artifact，
推送 `v*` tag 时自动创建 GitHub Release 并附上 apk。

## 仓库结构

```
.
├── .github/workflows/build.yml   # GitHub Actions：构建、测试、发布
├── APKBUILD                      # Alpine 打包脚本
├── ci/
│   └── build-in-alpine38.sh      # 在 Alpine 3.8 中构建 + 测试（CI/本地共用）
├── test/
│   ├── test_pyzbar_qr.py         # pyzbar 加载与 QR 解码验证
│   └── qr_matrix.txt             # 测试用二维码矩阵
└── README.md
```

`dist/` 是构建输出目录（apk + 本次签名的公钥），已加入 `.gitignore`，
不会提交到仓库。

## 版本与 tag 约定

- `pkgver`：跟随上游 zbar，当前为 `0.23.93`。
- `pkgrel`：构建日期 `YYYYMMDD`，当前为 `20261024`。
  apk 中的完整版本因此是 **`0.23.93-r20261024`**。
- Git tag：`v0.23.93`（对应上游版本）。

需要重新打包（同一上游版本）时，只需把 `APKBUILD` 里的 `pkgrel` 改成
当天日期，例如 `pkgrel=20261024` → `pkgrel=20261101`。

## GitHub Actions

workflow 文件：[.github/workflows/build.yml](.github/workflows/build.yml)

触发条件：

- push 到 `main` / `master`：在 `alpine:3.8` 容器中构建并跑测试，上传
  `libzbar-apk-alpine38-x86_64` artifact；
- push `v*` tag（如 `v0.23.93`）：额外创建 GitHub Release，附上 apk 和
  本次构建的签名公钥；
- pull request / 手动 `workflow_dispatch`：只构建和测试，不发布。

发布 tag：

```sh
git tag -a v0.23.93 -m "libzbar 0.23.93 for Alpine 3.8"
git push origin main --tags
```

Release 中会包含：

```
libzbar-0.23.93-r20261024.apk
libzbar-dev-0.23.93-r20261024.apk
libzbar-doc-0.23.93-r20261024.apk
libzbar-ci.rsa.pub
```

## 安装（从 Release）

```sh
# 1. 信任本次构建的签名公钥
cp libzbar-ci.rsa.pub /etc/apk/keys/

# 2. 安装运行时包（pyzbar 只需要这个）
apk add ./libzbar-0.23.93-r20261024.apk
```

不想安装公钥时，可以一次性跳过签名校验：

```sh
apk add --allow-untrusted ./libzbar-0.23.93-r20261024.apk
```

需要头文件 / `pkg-config` 时再装 `-dev`（会自动依赖 `libzbar`）：

```sh
apk add ./libzbar-dev-0.23.93-r20261024.apk
pkg-config --modversion zbar   # 0.23.93
```

运行时包只依赖 musl libc，SONAME 为 `libzbar.so.0`：

```
depends on:  so:libc.musl-x86_64.so.1
provides:    so:libzbar.so.0=0.3.0
```

## 验证 pyzbar

```sh
apk add python3
pip3 install pyzbar

python3 -c "from pyzbar.pyzbar import decode; from ctypes.util import find_library; print('libzbar =', find_library('zbar'))"
```

仓库里的完整功能测试不依赖 Pillow/numpy：它把 `test/qr_matrix.txt` 中的
二维码矩阵渲染成 8 位灰度图，再用 pyzbar 解码。

```sh
python3 test/test_pyzbar_qr.py
```

实测输出：

```
find_library("zbar") = 'libzbar.so.0'
pyzbar loaded libzbar from: libzbar.so.0
test image: 232x232, 53824 bytes
decoded: type=QRCODE data=b'PYZBAR-ALPINE38-OK'
RESULT: PASS
```

## 本地构建

在 Alpine 3.8 主机上（root）：

```sh
sh ci/build-in-alpine38.sh
```

或者任意有 Docker 的机器上：

```sh
docker run --rm \
  -v "$PWD:/src" -w /src \
  alpine:3.8 \
  /bin/sh /src/ci/build-in-alpine38.sh
```

脚本会安装构建依赖、生成签名密钥、调用 `abuild`，安装产物并运行
`test/test_pyzbar_qr.py`。成功后 apk 位于 `dist/`。

构建依赖：`build-base autoconf automake libtool pkgconf gettext-dev
abuild openssl ca-certificates python3`。

> abuild 3.2.0 以 root 运行时，`-F` 只对父进程生效；打包子进程仍会报
> "Do not run abuild as root"。脚本通过导出 `forceroot=1` 传递给子进程。
> 标准做法是使用非 root 用户 + fakeroot。

## 签名密钥

默认每次构建生成一次性密钥 `libzbar-ci.rsa`，并把公钥
`libzbar-ci.rsa.pub` 放进 `dist/` 和 Release。因此每个 Release 都带有
配套公钥，按上面的安装步骤即可。

如果需要跨 Release 使用稳定签名，可在仓库 Secrets 中配置
`ABUILD_PRIVKEY`（PEM 格式的 RSA 私钥，无 passphrase）：

```sh
openssl genrsa -out libzbar-ci.rsa 2048
openssl rsa -in libzbar-ci.rsa -pubout -out libzbar-ci.rsa.pub
# 把 libzbar-ci.rsa 的内容保存为 GitHub Actions secret: ABUILD_PRIVKEY
```

workflow 会把它传入容器，`ci/build-in-alpine38.sh` 会用它签名并导出对应
公钥。未配置时自动回退到一次性密钥。fork PR 拿不到 secret，同样回退。

## 兼容性（实测）

| Alpine | apk-tools | musl | Python / pyzbar | 结果 |
| --- | --- | --- | --- | --- |
| 3.8.0 | 2.10.6 | 1.1.19 | 3.6.9 / 0.1.9 | 安装、加载 `libzbar.so.0`、QR 解码 PASS |
| 3.24.2（latest-stable） | 3.0.8 | 1.2.6 | 3.14.8 / 0.1.9 | `apk verify` OK、干净 root 安装 OK、QR 解码 PASS |

结论：**Alpine 3.8 及以上（x86_64 / musl）可用，实测到当前 latest-stable
3.24.2**。3.9–3.24 之间没有逐版本测试，但两端已验证，ABI 层面连续兼容。

- 二进制只依赖 `so:libc.musl-x86_64.so.1`，未使用新 musl 专有符号；
- apk 为 v2 包格式、RSA-SHA1 签名，apk-tools 3.0.8 仍能校验并安装；
- 仅适用于 x86_64；其他架构请用本 `APKBUILD` 在对应架构重建；
- 仅适用于 Alpine/musl，不能用于 Debian/Ubuntu 等 glibc 系统；
- 3.8 以下未验证（理论上可能可用，但不作保证）。

## 说明与限制

- 包名 `libzbar` 与 Alpine 官方 aports 中 `zbar` 的库子包命名一致，
  `apk add libzbar` 即可满足 pyzbar；没有提供 `zbar`/`zbarimg` 命令行工具。
- `zbarimg`/`zbarcam` 未构建（分别依赖 ImageMagick 和摄像头/V4L），
  不影响 pyzbar。
- 仅启用核心解码功能：未启用 JPEG/PNG 图片转换、GTK/Qt、Python bindings
  等可选功能。
- 源码为上游 zbar 0.23.93 原版 tarball（Debian `orig` 源），sha256：
  `212dfab527894b8bcbcc7cd1d43d63f5604a07473d31a5f02889e372614ebe28`。
- 版本 0.23.93 已包含 CVE-2023-40889、CVE-2023-40890 的修复。
