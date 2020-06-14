#!/bin/sh

origin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

vivado -mode batch -nojournal -nolog -source ${origin_dir}/xtrxr4_top.tcl
