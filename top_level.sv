// Top level module
// TODO: figure out what inputs to use, uncomment appropriately in xdc
module top_level(
  input clk_100mhz,
  input [15:0] sw,
  input btnc, btnu, btnd, btnr, btnl,
  input vauxp3,
  input vauxn3,
  input vn_in,
  input vp_in,
  output logic [15:0] led,
  output logic aud_pwm,
  output logic aud_sd
);

endmodule
