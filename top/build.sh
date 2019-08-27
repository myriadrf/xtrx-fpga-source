#!/bin/sh
if [ ! -f xtrxr5/xtrxr5.xpr ]; then
    . ./gen_project_r5.sh
fi

vivado -mode batch -nojournal -nolog -source ./build.tcl
