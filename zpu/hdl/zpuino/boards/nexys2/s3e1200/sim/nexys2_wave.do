onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /tb_zpuino/clk_in
add wave -noupdate -format Logic /tb_zpuino/rst_in
add wave -noupdate -format Logic /tb_zpuino/top/clkgen_inst/rstin
add wave -noupdate -format Logic /tb_zpuino/top/clkgen_inst/rstout
add wave -noupdate -format Logic /tb_zpuino/top/clkgen_inst/dcmclock
add wave -noupdate -format Logic /tb_zpuino/top/clkgen_inst/dcmclock_b
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
add wave -noupdate -format Literal /tb_zpuino/gpio
add wave -noupdate -format Literal /tb_zpuino/gpio_i
add wave -noupdate -format Literal /tb_zpuino/gpio_t
add wave -noupdate -format Literal /tb_zpuino/gpio_o
add wave -noupdate -format Logic /tb_zpuino/rxsim
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/clk
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/gpio_i
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/gpio_o
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/gpio_t
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/interrupt
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io_ack
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io_address
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io_cyc
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io_read
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io_stb
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io_we
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io_write
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/poppc_inst
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/rst
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/rx
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/spp_cap_in
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/spp_cap_out
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/tx
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/clk
add wave -noupdate -format Literal /tb_zpuino/serial_sim_i1/clk_frequency_g
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/clk_in
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/rst
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/rst_in
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/tx_begin
add wave -noupdate -format Literal /tb_zpuino/serial_sim_i1/tx_par
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/rx_new
add wave -noupdate -format Literal /tb_zpuino/serial_sim_i1/rx_par
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/uart_rx_i
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/uart_rx
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/uart_tx_i
add wave -noupdate -format Logic /tb_zpuino/serial_sim_i1/uart_tx
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/data_ready
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/data_ready_dly_q
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/divider_rx_q
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/divider_tx
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/dready_q
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/enabled
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/enabled_q
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/fifo_data
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/fifo_empty
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/fifo_rd
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/received_data
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/rx
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/rx_br
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/rx_en
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/tx
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/tx_br
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/uart_busy
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/uart_read
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/uart_write
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_ack_o
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/wb_adr_i
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_clk_i
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_cyc_i
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/wb_dat_i
add wave -noupdate -format Literal /tb_zpuino/top/zpuino/io/uart_inst/wb_dat_o
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_inta_o
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_rst_i
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_stb_i
add wave -noupdate -format Logic /tb_zpuino/top/zpuino/io/uart_inst/wb_we_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {109974174 ps} 0} {{Cursor 2} {986840962 ps} 0}
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
WaveRestoreZoom {506250 ns} {3131250 ns}
