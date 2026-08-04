# Usage vivado -mode batch -source vivado/impl.tcl -tclargs <clkdiv>

set clkdiv [lindex $argv 0]
if {$clkdiv eq ""} { set clkdiv 3 }
set part   xc7a35tcpg236-1
set root   [file normalize [file join [file dirname [info script]] ..]]
set outdir [file join $root vivado build]
file mkdir $outdir

set src [file join $root rtl board_top.sv]
set dst [file join $outdir board_top_div${clkdiv}.sv]
set fh [open $src r]; set txt [read $fh]; close $fh
regsub {parameter int ClkDiv = [0-9]+} $txt "parameter int ClkDiv = $clkdiv" txt
set fh [open $dst w]; puts $fh $txt; close $fh

set pkgs {}
set rest {}
foreach f [lsort [glob [file join $root rtl *.sv]]] {
  set b [file rootname [file tail $f]]
  if {$b eq "board_top"} { continue }
  if {[string match *_pkg $b]} { lappend pkgs $f } else { lappend rest $f }
}
read_verilog -sv $pkgs
read_verilog -sv $rest
read_verilog -sv $dst
read_xdc [file join $root constraints basys3.xdc]

synth_design -top board_top -part $part
opt_design

set seq  [get_cells -hier -quiet -filter {IS_SEQUENTIAL}]
set tick [get_cells -hier -quiet -filter {NAME =~ *core_en_inst*cnt_reg*}]
set gated {}
foreach c $seq { if {[lsearch -exact $tick $c] < 0} { lappend gated $c } }

# Not in basys3.xdc
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
