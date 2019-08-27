set origin_dir "."

set orig_proj_dir "[file normalize "$origin_dir/orig-project"]"

create_project xtrxr5 ./xtrxr5

set proj_dir [get_property directory [current_project]]

set obj [get_projects xtrxr5]
set_property "part" "xc7a50tcpg236-2" $obj
set_property "simulator_language" "Mixed" $obj
set_property "source_mgmt_mode" "DisplayOnly" $obj
set_property "target_language" "Verilog" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files_common [list \
 "[file normalize "$origin_dir/../cross_counter.v"]"\
 "[file normalize "$origin_dir/../ram32xsdp.v"]"\
 "[file normalize "$origin_dir/../ram32xsp.v"]"\
 "[file normalize "$origin_dir/../ram64xsdp.v"]"\
 "[file normalize "$origin_dir/../sync_reg.v"]"\
 "[file normalize "$origin_dir/../bsswap.v"]"\
 "[file normalize "$origin_dir/../clz.v"]"\
 "[file normalize "$origin_dir/../axis_spi.v"]"\
 "[file normalize "$origin_dir/../ul_go_base.v"]"\
 "[file normalize "$origin_dir/../ul_router4_wr.v"]"\
 "[file normalize "$origin_dir/../ul_read_axis.v"]"\
 "[file normalize "$origin_dir/../pcie_to_ul.v"]"\
 "[file normalize "$origin_dir/../pcie_req_to_ram.v"]"\
 "[file normalize "$origin_dir/../pcie_ram_to_wr.v"]"\
 "[file normalize "$origin_dir/../xtrx_peripherals.v"]"\
 "[file normalize "$origin_dir/../qspi_mem_buf.v"]"\
 "[file normalize "$origin_dir/../clk_estimator.v"]"\
 "[file normalize "$origin_dir/../axis_mux4.v"]"\
 "[file normalize "$origin_dir/../axis_fifo32.v"]"\
 "[file normalize "$origin_dir/../axis_async_fifo32.v"]"\
 "[file normalize "$origin_dir/../axis_cc_flow_ctrl.v"]"\
 "[file normalize "$origin_dir/../lms7_rx_frm_brst.v"]"\
 "[file normalize "$origin_dir/../lms7_tx_frm_brst_ex.v"]"\
 "[file normalize "$origin_dir/../dma_config.v"]"\
 "[file normalize "$origin_dir/../dma_rx_sm.v"]"\
 "[file normalize "$origin_dir/../dma_tx_sm.v"]"\
 "[file normalize "$origin_dir/../fe_rx_chain_brst.v"]"\
 "[file normalize "$origin_dir/../fe_tx_chain_brst.v"]"\
 "[file normalize "$origin_dir/../uart_rx.v"]"\
 "[file normalize "$origin_dir/../ul_uart_rx.v"]"\
 "[file normalize "$origin_dir/../uart_tx.v"]"\
 "[file normalize "$origin_dir/../ul_uart_tx.v"]"\
 "[file normalize "$origin_dir/../ll_i2c_dmastere.v"]"\
 "[file normalize "$origin_dir/../ul_drp_cfg.v"]"\
 "[file normalize "$origin_dir/../ul_i2c_dme.v"]"\
 "[file normalize "$origin_dir/../ul_uart_smartcard.v"]"\
 "[file normalize "$origin_dir/../uart_smartcard.v"]"\
 "[file normalize "$origin_dir/../axis_atomic_fo.v"]"\
 "[file normalize "$origin_dir/../tx_fill_parts.v"]"\
 "[file normalize "$origin_dir/../int_router.v"]"\
 "[file normalize "$origin_dir/../cmd_queue.v"]"\
 "[file normalize "$origin_dir/../ul_qspi_mem.v"]"\
 "[file normalize "$origin_dir/../ul_qspi_mem_async.v"]"\
 "[file normalize "$origin_dir/../ul_read_demux_axis.v"]"\
 "[file normalize "$origin_dir/../qspi_flash.v"]"\
 "[file normalize "$origin_dir/../xtrx_gpio_ctrl.v"]"\
 "[file normalize "$origin_dir/../rxdsp_none.v"]"\
 "[file normalize "$origin_dir/../v3_pcie_app.v"]"\
 "[file normalize "$origin_dir/ip/blk_mem_gen_nrx/blk_mem_gen_nrx.xci"]"\
 "[file normalize "$origin_dir/ip/blk_mem_gen_ntx/blk_mem_gen_ntx.xci"]"\
 "[file normalize "$origin_dir/ip/pcie_7x_0/pcie_7x_0.xci"]"\
 "[file normalize "$origin_dir/xtrxr4_top.v"]"\
 "[file normalize "$origin_dir/xlnx_lms7_lml_phy.v"]"\
 "[file normalize "$origin_dir/xlnx_pcie_clocking.v"]"\
]
add_files -norecurse -fileset $obj $files_common


set_property "top" "xtrxr4_top" $obj
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-generic NO_PPS=1 -generic NO_GTIME=1} -objects [get_runs synth_1]


if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/xtrxr5_ucf.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "$origin_dir/xtrxr5_ucf.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj


report_ip_status
