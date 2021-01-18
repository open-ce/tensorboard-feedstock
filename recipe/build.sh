#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2018, 2021. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************
set -ex

# remove files in setuptools that have spaces, these cause issues with bazel
rm -rf "${SP_DIR}/setuptools/command/launcher manifest.xml"
rm -rf "${SP_DIR}/setuptools/script (dev).tmpl"

# Pick up additional variables defined from the conda build environment
SCRIPT_DIR=$RECIPE_DIR/../buildscripts
$SCRIPT_DIR/set_python_path_for_bazelrc.sh $SRC_DIR

# build using bazel
mkdir -p ./bazel_output_base
bazel --bazelrc=${SRC_DIR}/python_configure.bazelrc build \
    --host_javabase=@bazel_tools//tools/jdk:remote_jdk11 \
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

bazel clean --expunge
bazel shutdown
