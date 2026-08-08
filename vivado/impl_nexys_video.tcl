# Usage vivado -mode batch -source vivado/impl_nexys_video.tcl -tclargs <clkdiv>

set clkdiv [lindex $argv 0]
if {$clkdiv eq ""} { set clkdiv 2 }
set part   xc7a200tsbg484-1
set root   [file normalize [file join [file dirname [info script]] ..]]
set outdir [file join $root vivado build nv]
set ipdir  [file join $outdir ip]
file delete -force $ipdir
file mkdir $ipdir

set src [file join $root rtl boards nexys_video board_top.sv]
set dst [file join $outdir board_top_div${clkdiv}.sv]
set fh [open $src r]; set txt [read $fh]; close $fh
regsub {parameter int ClkDiv = [0-9]+} $txt "parameter int ClkDiv = $clkdiv" txt
set fh [open $dst w]; puts $fh $txt; close $fh

create_project -in_memory -part $part

# Memory controller
create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 \
          -module_name mig_7series_0 -dir $ipdir
set_property CONFIG.XML_INPUT_FILE [file join $root vivado mig nexys_video_mig.prj] \
             [get_ips mig_7series_0]
generate_target {instantiation_template synthesis} [get_ips mig_7series_0]
synth_ip [get_ips mig_7series_0]

set pkgs {}
set rest {}
foreach f [lsort [glob [file join $root rtl *.sv]]] {
  set b [file rootname [file tail $f]]
  if {$b eq "mem_delay"} { continue }
  if {[string match *_pkg $b]} { lappend pkgs $f } else { lappend rest $f }
}
read_verilog -sv $pkgs
read_verilog -sv $rest
read_verilog -sv $dst
read_xdc [file join $root constraints nexys_video.xdc]

synth_design -top board_top -part $part
opt_design

# Gated cells only
set seq   [get_cells -hier -quiet -filter {IS_SEQUENTIAL}]
set free  [get_cells -hier -quiet -filter \
             {NAME =~ *mig_inst* || NAME =~ *mem_arb_inst* || NAME =~ *core_en_inst*}]
set gated {}
foreach c $seq { if {[lsearch -exact $free $c] < 0} { lappend gated $c } }

set_multicycle_path $clkdiv            -setup -from $gated -to $gated
set_multicycle_path [expr {$clkdiv-1}] -hold  -from $gated -to $gated

place_design
phys_opt_design
route_design

write_checkpoint -force  [file join $outdir board_top_routed.dcp]
report_utilization -file [file join $outdir utilization.rpt]
report_timing_summary -file [file join $outdir timing_summary.rpt]

report_timing -delay_type max -max_paths 1 -file [file join $outdir worst_path.rpt]
report_timing -from $gated -to $gated -delay_type max -max_paths 1 \
              -file [file join $outdir worst_multicycle_path.rpt]

puts [format "RESULT wns_ns %.3f" [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]]
puts [format "RESULT whs_ns %.3f" [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]]
puts [format "RESULT multicycle_slack_ns %.3f" \
        [get_property SLACK [get_timing_paths -from $gated -to $gated -delay_type max -max_paths 1]]]
report_utilization -hierarchical -hierarchical_depth 3 -hierarchical_min_primitive_count 1 \
                   -file [file join $outdir hier_util.rpt]
write_bitstream -force [file join $outdir board_top.bit]
