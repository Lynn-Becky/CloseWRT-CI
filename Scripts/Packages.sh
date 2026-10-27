#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 将 OpenWrt 24.10 feeds 中的 Go 工具链升级至 Go 1.27.3。
# 最新版 xray-core 的 go.mod 要求 Go 1.27；整个 lang/golang feed 必须同步，
# 因为 Go 1.27 使用了版本化工具链和独立 bootstrap 包。
UPGRADE_GOLANG_TOOLCHAIN() {
	local GOLANG_DIR="../feeds/packages/lang/golang"
	local GOLANG_FEED_COMMIT="ac1e300d570a55fba0483559106c7b79876511c8"
	local GOLANG_ARCHIVE_URL="https://codeload.github.com/openwrt/packages/tar.gz/$GOLANG_FEED_COMMIT"
	local GOLANG_TMP_DIR
	local GOLANG_ARCHIVE

	if [ ! -d "$GOLANG_DIR" ]; then
		echo "Go package feed not found: $GOLANG_DIR" >&2
		return 1
	fi

	echo " "
	echo "Upgrading Go toolchain to 1.27.3..."

	GOLANG_TMP_DIR=$(mktemp -d) || return 1
	GOLANG_ARCHIVE="$GOLANG_TMP_DIR/packages.tar.gz"
	if ! curl --fail --location --retry 3 --retry-delay 2 \
		--output "$GOLANG_ARCHIVE" "$GOLANG_ARCHIVE_URL"; then
		rm -rf "$GOLANG_TMP_DIR"
		return 1
	fi

	if ! tar -xzf "$GOLANG_ARCHIVE" -C "$GOLANG_TMP_DIR"; then
		rm -rf "$GOLANG_TMP_DIR"
		return 1
	fi

	rm -rf "${GOLANG_DIR}.new"
	if ! mv "$GOLANG_TMP_DIR/packages-${GOLANG_FEED_COMMIT}/lang/golang" \
		"${GOLANG_DIR}.new"; then
		rm -rf "$GOLANG_TMP_DIR" "${GOLANG_DIR}.new"
		return 1
	fi
	rm -rf "$GOLANG_DIR"
	mv "${GOLANG_DIR}.new" "$GOLANG_DIR"
	rm -rf "$GOLANG_TMP_DIR"
}

# 使用 PassWall 官方仓库替换 OpenWrt feeds 中的旧版依赖和 LuCI 应用。
# 此脚本在 feeds install 完成后于 wrt/package 目录执行。
SYNC_PASSWALL() {
	local PASSWALL_CORE_PACKAGES=(
		xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria
		ipt2socks microsocks naiveproxy shadowsocks-rust shadowsocksr-libev
		simple-obfs tcping v2ray-plugin xray-plugin geoview shadow-tls
	)

	echo " "
	echo "Syncing latest PassWall packages..."

	# 删除 feeds/packages 中与 PassWall 官方仓库重复的旧核心库。
	local PKG
	for PKG in "${PASSWALL_CORE_PACKAGES[@]}"; do
		rm -rf "../feeds/packages/net/$PKG"
	done
	# 删除 feeds/luci 中可能存在的旧版 PassWall LuCI 应用。
	rm -rf ../feeds/luci/applications/luci-app-passwall

	# 使该步骤可重复执行，并始终从 main 分支获取最新源码。
	rm -rf ./passwall-packages ./passwall-luci
	git clone --depth=1 --single-branch --branch main \
		"https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git" \
		./passwall-packages || return 1
	git clone --depth=1 --single-branch --branch main \
		"https://github.com/Openwrt-Passwall/openwrt-passwall.git" \
		./passwall-luci || return 1
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"
UPDATE_PACKAGE "noobwrt" "nooblk-98/luci-theme-noobwrt" "master"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
UPDATE_PACKAGE "theme-fluent" "LazuliKao/luci-theme-fluent" "main"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPGRADE_GOLANG_TOOLCHAIN || exit 1
SYNC_PASSWALL || exit 1
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

#UPDATE_PACKAGE "athena-led" "unraveloop/JDC-AX6600-Athena-LED-Controller" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
