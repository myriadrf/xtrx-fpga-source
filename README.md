# XTRX SDR FPGA image source code
This repository contains the source code of the XTRX SDR FPGA image.

# How to build

You will need a copy of Vivado, which can be freely downloaded on the Xilinx website.

Start by `source`ing the `settings64.sh` file from the Vivado install. For example:
```
source /opt/Xilinx/Vivado/2019.1/settings64.sh
```

To build the bitstream, ensure you are in the `fpga-source` directory and the same shell run:
```
cd top/xtrxr5
./build.sh
```

If successful, the output bitstream will be available in the following path:
```
top/xtrxr5/xtrxr5/xtrxr5.runs/impl_1/xtrxr4_top.bit
```

# License
RTL IP sources are released under the CERN Open Hardware Licence Version 2 - Weakly Reciprocal
Please refer to the LICENSE file of the source code for the full text of the license.
