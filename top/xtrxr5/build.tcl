open_project xtrxr5/xtrxr5.xpr

#reset_run synth_1
#reset_run blk_mem_gen_nrx_synth_1
#reset_run blk_mem_gen_ntx_synth_1
#reset_run pcie_7x_0_synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

report_property [get_runs synth_1]


