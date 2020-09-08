# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2018, 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************
#!/bin/bash

set -ex

# remove files in setuptools that have spaces, these cause issues with bazel
rm -rf "${SP_DIR}/setuptools/command/launcher manifest.xml"
rm -rf "${SP_DIR}/setuptools/script (dev).tmpl"

# build using bazel
mkdir -p ./bazel_output_base
BAZEL_OPTS="--batch"
bazel ${BAZEL_OPTS} build \
    --host_javabase=@bazel_tools//tools/jdk:remote_jdk11 \
    --extra_toolchains=@bazel_tools//tools/python:autodetecting_toolchain_nonstrict \
    //tensorboard/pip_package:build_pip_package

# Adapted from: https://github.com/tensorflow/tensorboard/blob/1.9.0/tensorboard/pip_package/build_pip_package.sh
sedi="sed -i"

TMPDIR=tmp_pip_dir
mkdir -p ${TMPDIR}
RUNFILES=$(pwd)/bazel-bin/tensorboard/pip_package/build_pip_package.runfiles

pushd ${TMPDIR}

cp -LR "${RUNFILES}/org_tensorflow_tensorboard/tensorboard" .
mv -f "tensorboard/pip_package/LICENSE" .
mv -f "tensorboard/pip_package/MANIFEST.in" .
mv -f "tensorboard/pip_package/README.rst" .
mv -f "tensorboard/pip_package/setup.cfg" .
mv -f "tensorboard/pip_package/setup.py" .
mv -f "tensorboard/pip_package/requirements.txt" .
rm -rf tensorboard/pip_package

rm -f tensorboard/tensorboard              # bazel py_binary sh wrapper
chmod -x LICENSE                           # bazel symlinks confuse cp
find . -name __init__.py | xargs chmod -x  # which goes for all genfiles

mkdir -p tensorboard/_vendor
touch tensorboard/_vendor/__init__.py
cp -LR "${RUNFILES}/org_mozilla_bleach/bleach" tensorboard/_vendor
cp -LR "${RUNFILES}/org_pythonhosted_webencodings/webencodings" tensorboard/_vendor

chmod -R u+w,go+r .

find tensorboard -name \*.py |
  xargs $sedi -e '
    s/^import html5lib$/from tensorboard._vendor.bleach._vendor import html5lib/
    s/^from html5lib/from tensorboard._vendor.bleach._vendor.html5lib/
    s/^import bleach$/from tensorboard._vendor import bleach/
    s/^from bleach/from tensorboard._vendor.bleach/
    s/^import webencodings$/from tensorboard._vendor import webencodings/
    s/^from webencodings/from tensorboard._vendor.webencodings/
  '
# install the package
python -m pip install . --no-deps --ignore-installed -vvv

# Remove bin/tensorboard since the entry_point takes care of creating this.
rm $PREFIX/bin/tensorboard
