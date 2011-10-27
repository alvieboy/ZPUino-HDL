onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /tb_zpuino/w_clk
add wave -noupdate -format Logic /tb_zpuino/w_rst
add wave -noupdate -format Literal /tb_zpuino/top/core/opcode
add wave -noupdate -format Literal /tb_zpuino/top/core/trace_opcode
add wave -noupdate -format Logic /tb_zpuino/top/core/begin_inst
add wave -noupdate -format Literal /tb_zpuino/top/core/trace_pc
add wave -noupdate -format Literal /tb_zpuino/top/core/trace_sp
add wave -noupdate -format Literal /tb_zpuino/top/core/trace_topofstack
add wave -noupdate -format Literal /tb_zpuino/top/core/trace_topofstackb
add wave -noupdate -format Logic /tb_zpuino/spi_pf_miso
add wave -noupdate -format Logic /tb_zpuino/spi_pf_miso_dly
add wave -noupdate -format Logic /tb_zpuino/spi_pf_mosi
add wave -noupdate -format Logic /tb_zpuino/spi_pf_mosi_dly
add wave -noupdate -format Logic /tb_zpuino/spi_pf_sck_dly
add wave -noupdate -format Logic /tb_zpuino/spi_pf_sck
add wave -noupdate -format Logic /tb_zpuino/spi_pf_nsel
add wave -noupdate -format Literal /tb_zpuino/vcc
add wave -noupdate -format Logic /tb_zpuino/uart_tx
add wave -noupdate -format Logic /tb_zpuino/uart_rx
add wave -noupdate -format Literal /tb_zpuino/gpio_i
add wave -noupdate -format Literal /tb_zpuino/gpio_t
add wave -noupdate -format Literal /tb_zpuino/gpio_o
add wave -noupdate -format Logic /tb_zpuino/rxsim
add wave -noupdate -format Logic /tb_zpuino/top/clk
add wave -noupdate -format Literal /tb_zpuino/top/gpio_i
add wave -noupdate -format Literal /tb_zpuino/top/gpio_o
add wave -noupdate -format Literal /tb_zpuino/top/gpio_t
add wave -noupdate -format Logic /tb_zpuino/top/interrupt
add wave -noupdate -format Logic /tb_zpuino/top/io_ack
add wave -noupdate -format Literal /tb_zpuino/top/io_address
add wave -noupdate -format Logic /tb_zpuino/top/io_cyc
add wave -noupdate -format Literal /tb_zpuino/top/io_read
add wave -noupdate -format Logic /tb_zpuino/top/io_stb
add wave -noupdate -format Logic /tb_zpuino/top/io_we
add wave -noupdate -format Literal /tb_zpuino/top/io_write
add wave -noupdate -format Logic /tb_zpuino/top/poppc_inst
add wave -noupdate -format Logic /tb_zpuino/top/rst
add wave -noupdate -format Logic /tb_zpuino/top/rx
add wave -noupdate -format Literal /tb_zpuino/top/spp_cap_in
add wave -noupdate -format Literal /tb_zpuino/top/spp_cap_out
add wave -noupdate -format Logic /tb_zpuino/top/tx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {999050 ps} {1000050 ps}
