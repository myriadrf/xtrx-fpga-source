set origin_dir [file dirname [info script]]
set root_dir [file normalize "$origin_dir/../.."]
puts "origin_dir = $origin_dir"
puts "repo root = $root_dir"

create_project xtrxr5 $origin_dir/xtrxr5

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
add_files -norecurse -fileset $obj $root_dir/lib/ram/
add_files -norecurse -fileset $obj $root_dir/lib/fifo/
add_files -norecurse -fileset $obj $root_dir/lib/i2c/
add_files -norecurse -fileset $obj $root_dir/lib/spi/
add_files -norecurse -fileset $obj $root_dir/lib/qspi/
add_files -norecurse -fileset $obj $root_dir/lib/uart/
add_files -norecurse -fileset $obj $root_dir/lib/lms7/
add_files -norecurse -fileset $obj $root_dir/lib/pcie/
add_files -norecurse  -fileset $obj $root_dir/lib/xtrx/
set_property include_dirs $root_dir/lib/xtrx/ $obj

#top level sources
add_files -norecurse -fileset $obj $origin_dir/

#add ip cores
import_ip $origin_dir/ip/blk_mem_gen_nrx/blk_mem_gen_nrx.xci -quiet
import_ip $origin_dir/ip/blk_mem_gen_ntx/blk_mem_gen_ntx.xci -quiet
import_ip $origin_dir/ip/pcie_7x_0/pcie_7x_0.xci -quiet

#upgrade IPs if vivado version is newer
upgrade_ip [get_ips blk_mem_gen_nrx]
upgrade_ip [get_ips blk_mem_gen_ntx]
upgrade_ip [get_ips pcie_7x_0]

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
