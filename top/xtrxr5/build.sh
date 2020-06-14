#!/bin/sh

origin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f ${origin_dir}/xtrxr5/xtrxr5.xpr ]; then
    . ${origin_dir}/gen_project_r5.sh
fi

vivado -mode batch -nojournal -nolog -source ${origin_dir}/build.tcl
