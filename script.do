
vlib work
vcom ps2_driver.vhd
vcom tb_ps2_driver.vhd
vsim -wlf /sim/tb_ps2_driver -voptargs="+acc" -wlfdeleteonquit tb_ps2_driver
add wave sim:/tb_ps2_driver/*
add wave sim:/tb_ps2_driver/UUT/*
run 602965 ns
