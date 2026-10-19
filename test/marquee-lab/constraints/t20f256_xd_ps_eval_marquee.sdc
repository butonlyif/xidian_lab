# t20f256_xd_ps_marquee minimal timing
# Pins: clk_50m_i@H13, arst_n_i@A4, led_o[9:0]
create_clock -name clk_50m -period 20.000 [get_ports clk_50m_i]
