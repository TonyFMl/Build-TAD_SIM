#！/bin/bash
set -e 
IMAGE_NAME="tadsim/desktop:v2.0"
GO_VERSION="1.17.8"
GRPC_VERSION="1.32.0"

# clone TAD_SIM 
git clone https://github.com/Tencent/TAD_Sim.git
echo "======================== clone TAD_Sim complete ========================"


# download depends
## grpc
git config --global url."https://github.com/".insteadOf git://github.com/ 
git clone --recurse-submodules -b v${GRPC_VERSION} https://github.com/grpc/grpc 
## go
wget -t 10 --retry-connrefused -O go${GO_VERSION}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
echo "======================== download depends complete ========================"

# build docker 
docker build . -t $IMAGE_NAME --build-arg BASE_MIRROR=ccr.ccs.tencentyun.com/library/
echo "======================== build docker complete ========================"

# build 
cd TAD_Sim
echo "now start build ..."
docker run -it --rm -v .:/build -w /build $IMAGE_NAME /bin/bash -c "./build.sh > log.txt 2>&1"
echo "======================== build TAD_Sim complete ========================"

