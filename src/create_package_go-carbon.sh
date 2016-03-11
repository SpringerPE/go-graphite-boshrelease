#!/bin/bash

TAG=0.7
ARCHIVE_DIR="$(pwd)"

git clone https://github.com/lomik/go-carbon.git  go-carbon-${TAG}
git checkout tags/v${TAG}

pushd go-carbon-${TAG}
  make submodules
popd
tar --exclude-vcs --exclude .git --exclude .gitmodules --exclude .gitignore  -cvf - go-carbon-${TAG} | gzip > ${ARCHIVE_DIR}/go-carbon-${TAG}.tar.gz
