#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 0 ] ; then
    echo "usage: $0"
    exit 1
fi

mkdir -p output/drivers

cd $ZEST_PATH/drivers
make || exit $?
cp extmod.prg $ZEST_SETUP/output/drivers
cd $ZEST_SETUP/output/drivers

# keyboard driver
if [ ! -d zkbd ] ; then
    git clone https://github.com/zerkman/zkbd.git || exit $?
fi
cd zkbd
git pull
make
