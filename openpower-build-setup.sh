#!/bin/bash

# This build script is for running the Jenkins builds using docker.
#
# It expects a few variables which are part of Jenkins build job matrix:
#   target = palmetto|qemu|habanero|firestone|garrison
#   WORKSPACE =

# Trace bash processing
set -xeo pipefail

# Default variables
target=${target:-palmetto}
WORKSPACE=${WORKSPACE:-${HOME}/${RANDOM}${RANDOM}}
http_proxy=${http_proxy:-}

# Timestamp for job
echo "Build started, $(date)"

# Configure docker build

Dockerfile=$(cat << EOF
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -yy \
	bc \
	bison \
	build-essential \
	cscope \
       	cpio \
	ctags \
	flex \
	g++ \
	git \
	libssl-dev \
	libexpat-dev \
	libz-dev \
	libxml-sax-perl \
	libxml-simple-perl \
	libxml2-dev \
	libxml2-utils \
	language-pack-en \
	python \
	texinfo \
	unzip \
	vim-common \
	rsync \
	wget\
	xsltproc

RUN grep -q ${GROUPS} /etc/group || groupadd -g ${GROUPS} ${USER}
RUN grep -q ${UID} /etc/passwd || useradd -d ${HOME} -m -u ${UID} -g ${GROUPS} ${USER}

USER ${USER}
ENV HOME ${HOME}
RUN /bin/bash
EOF
)

# Build the docker container
docker build -t op-build/ubuntu - <<< "${Dockerfile}"
if [[ "$?" -ne 0 ]]; then
  echo "Failed to build docker container."
  exit 1
fi

mkdir -p ${WORKSPACE}

cat > "${WORKSPACE}"/build.sh << EOF_SCRIPT
#!/bin/bash

set -x

# This ensures that the alias set in op-build-env is
# avalaible in this script
shopt -s expand_aliases

cd ${WORKSPACE}/op-build

# Source our build env
. op-build-env

# Configure
op-build ${target}_defconfig

# Kick off a build
op-build

EOF_SCRIPT

chmod a+x ${WORKSPACE}/build.sh

# Run the docker container, execute the build script we just built
docker run --net=host --rm=true -e WORKSPACE=${WORKSPACE} --user="${USER}" \
  -w "${HOME}" -v "${HOME}":"${HOME}" -t op-build/ubuntu ${WORKSPACE}/build.sh

# Create link to images for archiving
ln -sf ${WORKSPACE}/op-build/output/images ${WORKSPACE}/images

# Timestamp for build
echo "Build completed, $(date)"
