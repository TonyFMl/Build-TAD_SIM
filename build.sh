#!/bin/bash
set -e 
IMAGE_NAME="tadsim/desktop:v2.0"
GO_VERSION="go1.17.8.linux-amd64.tar.gz"
GRPC_VERSION="1.32.0"

# 新增：如果目标目录已存在，处理三种情况：
# 1) 含 .git -> 执行 git pull 更新
# 2) 非空但非 git -> 备份移动为 dirname_backup_<timestamp>
# 3) 存在且为空 -> 继续使用
ensure_dir_clean_or_backup() {
	_target="$1"
	if [ -d "$_target" ]; then
		if [ -d "$_target/.git" ]; then
			echo "目录 '$_target' 已存在且为 git 仓库，尝试 git pull..."
			if ! git -C "$_target" pull --rebase --autostash; then
				echo "git pull 失败，尝试 fetch..."
				git -C "$_target" fetch --all || echo "git fetch 也失败"
			fi
			return 0
		elif [ "$(ls -A "$_target" 2>/dev/null)" ]; then
			ts=$(date +%s)
			backup="${_target}_backup_${ts}"
			echo "目录 '$_target' 已存在且非空，移动到 '$backup' 以继续自动化流程"
			mv "$_target" "$backup" || { echo "无法移动目录 '$_target'，请手动处理"; exit 1; }
		else
			echo "目录 '$_target' 存在但为空，继续操作"
		fi
	fi
}

# 新增：下载带重试机制（使用 curl/wget），支持指数退避
download_with_retries() {
	url="$1"
	out="$2"
	max_tries="${3:-5}"
	delay="${4:-5}"
	attempt=1
	while [ $attempt -le "$max_tries" ]; do
		echo "尝试下载：$url （$attempt/$max_tries）"
		if command -v curl >/dev/null 2>&1; then
			if curl -fSL --retry 3 --retry-delay 5 -o "$out" "$url"; then
				echo "下载成功: $out"
				return 0
			fi
		elif command -v wget >/dev/null 2>&1; then
			if wget -T 30 -O "$out" "$url"; then
				echo "下载成功: $out"
				return 0
			fi
		else
			echo "系统未安装 curl 或 wget，无法下载"
			return 2
		fi
		echo "下载失败，等待 $delay 秒后重试..."
		sleep "$delay"
		attempt=$((attempt+1))
		# 指数退避
		delay=$((delay * 2))
	done

	echo "多次尝试下载失败：$url"
	return 1
}

# clone TAD_SIM 
TAD_DIR="TAD_Sim"
ensure_dir_clean_or_backup "$TAD_DIR"
if [ ! -d "$TAD_DIR" ]; then
	# 这里仍保留原仓库地址（若与你的仓库地址不同请替换）
	if ! git clone https://github.com/TonyFMl/TAD_Sim.git "$TAD_DIR"; then
		echo "git clone 失败，请检查网络或仓库地址"
		exit 1
	fi
fi
echo "======================== clone TAD_Sim complete ========================"


# download depends
## grpc
# 新增：在克隆前处理已存在目录（如果是 git 仓库则 pull，否则备份或继续）
ensure_dir_clean_or_backup "grpc"
if [ ! -d "grpc" ]; then
	# 指定目标目录为 grpc，避免默认行为带来的冲突
	if ! git clone --recurse-submodules -b v${GRPC_VERSION} https://github.com/grpc/grpc grpc; then
		echo "git clone grpc 失败，请检查网络或手动处理"
		exit 1
	fi
else
	echo "目录 'grpc' 已存在，已处理或更新，跳过 clone"
fi

## go
GO_URL="https://go.dev/dl/${GO_VERSION}"
GO_TMP=${GO_VERSION}
if [ ! -f "$GO_TMP" ]; then
	if ! download_with_retries "$GO_URL" "$GO_TMP" 5 5; then
		echo "无法下载 Go ($GO_URL)。请检查网络或使用国内镜像手动下载后放到 $GO_TMP，然后重试。"
		exit 1
	fi
else
	echo "已存在本地 Go 安装包：$GO_TMP，跳过下载"
fi
echo "======================== download depends complete ========================"

# build docker 
docker build . -t $IMAGE_NAME --build-arg BASE_MIRROR=ccr.ccs.tencentyun.com/library/
echo "======================== build docker complete ========================"

# build 
cd TAD_Sim
echo "now start build ..."
docker run -it --rm -v .:/build -w /build $IMAGE_NAME /bin/bash -c "./build.sh > log.txt 2>&1"
echo "======================== build TAD_Sim complete ========================"

