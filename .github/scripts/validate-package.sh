#!/bin/sh
# 校验 .plasmoid 能否被 KPackage 真正安装，全部在一次性容器里完成
# Checks that the .plasmoid really installs under KPackage, inside throwaway containers only
#
# 首选镜像自带 Plasma 6 与 kpackagetool6，无需装包，耗时最短
# 首选镜像不可用或缺 kpackagetool6 时，回退到 Arch 官方镜像并安装 kpackage 与 libplasma
# The preferred image ships Plasma 6 and kpackagetool6, so nothing is installed
# If it is unavailable or lacks kpackagetool6, we fall back to Arch + kpackage + libplasma
#
# 本脚本在 runner 上运行（宿主机不动），只调用 docker

set -eu

workdir=${GITHUB_WORKSPACE:-$(pwd)}
cd "$workdir"

set -- ./*.plasmoid
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    echo "::error::仓库根目录应恰有一个 .plasmoid（未找到或存在多个）"
    exit 1
fi
package=$1

fast_image=kdeneon/plasma:latest
fallback_image=archlinux:latest

echo "首选 $fast_image（自带 Plasma 6 与 kpackagetool6）"
if docker pull --quiet "$fast_image"; then
    set +e
    docker run --rm --entrypoint kpackagetool6 \
        -v "$workdir:/src:ro" -w /src "$fast_image" \
        --type Plasma/Applet --packageroot /tmp/pkgcheck --install "/src/$package"
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
        echo "安装校验通过（$fast_image）"
        exit 0
    fi
    if [ "$status" -ne 127 ]; then
        echo "::error::kpackagetool6 校验失败（退出码 $status），不回退"
        exit "$status"
    fi
    echo "::warning::$fast_image 中没有 kpackagetool6，回退"
else
    echo "::warning::无法获取 $fast_image，回退"
fi

echo "回退 $fallback_image + kpackage + libplasma"
docker run --rm --entrypoint sh \
    -v "$workdir:/src:ro" -w /src "$fallback_image" -c '
    set -eu
    pacman -Syu --noconfirm --needed --quiet kpackage libplasma >/dev/null
    kpackagetool6 --type Plasma/Applet --packageroot /tmp/pkgcheck --install /src/*.plasmoid
'
echo "安装校验通过（$fallback_image）"
