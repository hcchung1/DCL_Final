`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions:
// Description: The sample top module of lab 6: sd card reader. The behavior of
//              this module is as follows
//              1. When the SD card is initialized, display a message on the LCD.
//                 If the initialization fails, an error message will be shown.
//              2. The user can then press usr_btn[2] to trigger the sd card
//                 controller to read the super block of the sd card (located at
//                 block # 8192) into the SRAM memory.
//              3. During SD card reading time, the four LED lights will be turned on.
//                 They will be turned off when the reading is done.
//              4. The LCD will then displayer the sector just been read, and the
//                 first byte of the sector.
//              5. Everytime you press usr_btn[2], the next byte will be displayed.
// 
// Dependencies: clk_divider, LCD_module, debounce, sd_card
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tetris(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,       // switches
  output [3:0] usr_led,

  // SD card specific I/O ports
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  // tri-state LED
  output [3:0] rgb_led_r,
  output [3:0] rgb_led_g,
  output [3:0] rgb_led_b
);

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_START = 1, S_MAIN_MOVE = 2, S_MAIN_WAIT = 3,
                 S_MAIN_CHECK = 4, S_MAIN_PAUSE = 5, S_MAIN_END = 6;


// Declare system variables
wire [3:0] btn_level, btn_pressed;
reg  [3:0] prev_btn_level;
reg  [2:0] P, P_next;

reg  [127:0] row_A = "SD card cannot  ";
reg  [127:0] row_B = "be initialized! ";

wire init_finished;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign usr_led = 4'h00;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);

debounce btn_db3(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level[3])
);

LCD_module lcd0( 
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(rd_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed[0] = (btn_level[0] == 1 && prev_btn_level[0] == 0)? 1 : 0;
assign btn_pressed[1] = (btn_level[1] == 1 && prev_btn_level[1] == 0)? 1 : 0;
assign btn_pressed[2] = (btn_level[2] == 1 && prev_btn_level[2] == 0)? 1 : 0;
assign btn_pressed[3] = (btn_level[3] == 1 && prev_btn_level[3] == 0)? 1 : 0;

reg move_end;
reg pause;
reg ending;
reg [3:0] choice;

// -----------------------------------------------------------------
// FSM next-state logic
always @(*) begin 
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_START;
      else P_next = S_MAIN_INIT;
    S_MAIN_START: // assume that all the usr_sw(s) were originally 0
      if (usr_sw[0]) P_next = S_MAIN_MOVE;
      else P_next = S_MAIN_START;
    S_MAIN_MOVE:
      if(~move_end) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_MOVE;
    S_MAIN_WAIT:
      if(|choice && ~pause && ~ending)  P_next = S_MAIN_CHECK;
      else if(pause) P_next = S_MAIN_PAUSE;
      else if(ending) P_next = S_MAIN_END;
      else P_next = S_MAIN_WAIT;
    S_MAIN_CHECK:
      if(ending) P_next = S_MAIN_END;
      else P_next = S_MAIN_MOVE;
    S_MAIN_PAUSE:
      if(~pause) P_next = S_MAIN_MOVE;
      else P_next = S_MAIN_PAUSE;
    S_MAIN_END:
      P_next = S_MAIN_END;
    
    default: P_next = S_MAIN_INIT; // ???
  endcase
end
// end of FSM
// -----------------------------------------------------------------






endmodule
