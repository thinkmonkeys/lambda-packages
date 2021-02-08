#!/bin/bash
#
# Script to build cryptography and/or related python packages for lambda.
#
# Requires two arguments: package and version.
#
# You can use it to build inside an Amazon Linux AMI (default) or with docker
# with --docker (you need docker installed and network access to reach lambci's
# docker-lambda image).
#
# Defaults to building both python2.7 and python3.6 packages. If you only want
# one of them use either --py2-only or --py3-only.
#
set -e

DOCKER=0
SUDO=sudo

while [[ $# -gt 2 ]]
do
key="$1"

case $key in
    --docker)
        DOCKER=1
        SUDO=""
        shift
        ;;
    *)
        shift
        ;;
esac
done

PACKAGE=${1}
VERSION=${2}

echo DOCKER          = "${DOCKER}"
echo PACKAGE         = "${PACKAGE}"
echo VERSION         = "${VERSION}"

function build_package {
    PACKAGE=${1}
    VERSION=${2}
    PYTHON=${3}
    PIP=${4}
    VIRTUALENV=${5}

    ENV="env-${PYTHON}-${PACKAGE}-${VERSION}"
    TARGET_DIR=${ENV}/packaged
    TMP_DIR="${PYTHON}_${PACKAGE}_${VERSION}"

    if [ -d "${TARGET_DIR}" ]; then rm -Rf ${TARGET_DIR}; fi
    if [ -d "${TMP_DIR}" ]; then rm -Rf ${TMP_DIR}; fi
    mkdir ${TMP_DIR}
    cd  ${TMP_DIR}

    echo "install dependencies"
    ${SUDO} yum install -y yum-plugin-ovl
    ${SUDO} yum update -y
    ${SUDO} yum groupinstall -y "Development Tools"
    ${SUDO} yum install -y libffi libffi-devel openssl openssl-devel gcc python-devel redhat-rpm-config
    if [ "${VIRTUALENV}" == "virtualenv" ]; then
        ${SUDO} ${PIP} install virtualenv
    fi

    echo "make virtualenv"
    echo ${VIRTUALENV} "${ENV}"
    ${VIRTUALENV} "${ENV}"

    echo "activate env in `pwd`"
    echo source "${ENV}/bin/activate"
    source "${ENV}/bin/activate"

    echo "update pip in virtualenv"
    ${PIP} install -U pip

    # https://github.com/pypa/pip/issues/3056
    echo '[install]' > ./setup.cfg
    echo 'install-purelib=$base/lib64/python' >> ./setup.cfg

    echo "install rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env

    echo "install pips"
    echo ${PIP} install --verbose --no-dependencies --target ${TARGET_DIR} "${PACKAGE}==${VERSION}"
    ${PIP} install --verbose --no-dependencies --target ${TARGET_DIR} "${PACKAGE}==${VERSION}"
    deactivate

    cd ${TARGET_DIR} && tar -zcvf ../../../${PYTHON}-${PACKAGE}-${VERSION}.tar.gz * && cd ../../..
    rm -r ${TMP_DIR}
}

build_package ${PACKAGE} ${VERSION} python3.6 pip3.6 "python3.6 -m venv "
