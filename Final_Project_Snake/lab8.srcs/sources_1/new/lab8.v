`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Yang Ming Chiao Tung University
// Engineer: Cheng-Han Chung, 
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: 
// Module Name: snake
// Project Name: Final_Project
// Target Devices: FPGA
// Tool Versions:
// Description: This is snake Verilog, aim to play snake game by FPGA
//              1. Control directions by bottom
//              2. Showing snake and background on VGA
// 
// Dependencies: clk_divider, LCD_module, debounce, VGA, 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,       // switches
  output [3:0] usr_led,

  // LCD
  // output LCD_RS,
  // output LCD_RW,
  // output LCD_E,
  // output [3:0] LCD_D, 

  // VGA 
  output VGA_HSYNC,
  output VGA_VSYNC,
  output [3:0] VGA_RED,
  output [3:0] VGA_GREEN,
  output [3:0] VGA_BLUE
);

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_START = 1, S_MAIN_MOVE = 2, S_MAIN_WAIT = 3,
                 S_MAIN_CHECK = 4, S_MAIN_RE = 5, S_MAIN_PAUSE = 6, S_MAIN_END = 7;


// Declare system variables
wire [3:0] btn_level, btn_pressed;
reg  [3:0] prev_btn_level;
reg  [2:0] P, P_next;
reg  [3:0] switch;
wire move_end;
reg pause;
reg ending;

wire state; // state 
assign state = P;


wire checking;
assign checking = (P == S_MAIN_CHECK);

reg starting;

reg [399:0] snk_pos = 0;
wire [399:0] snk_posw;
assign snk_posw = snk_pos;

reg [23:0] apple_pos;
wire [23:0] apple_posw;
assign apple_posw = apple_pos;

reg [79:0] wall_pos = 0;
wire [79:0] wall_posw;
assign wall_posw = wall_pos;

reg [3:0] choice;
reg [3:0] prev_ch;
wire [3:0] choicew;
assign choicew = choice;

wire [399:0] new_position;
wire snake_dead;
wire [2:0] apple_eat;

wire [39:0] new_apple_pos;

reg init_finished;
reg re_done;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign usr_led = P;

debounce btn_db0(.clk(clk),.btn_input(usr_btn[0]),.btn_output(btn_level[0]));
debounce btn_db1(.clk(clk),.btn_input(usr_btn[1]),.btn_output(btn_level[1]));
debounce btn_db2(.clk(clk),.btn_input(usr_btn[2]),.btn_output(btn_level[2]));
debounce btn_db3(.clk(clk),.btn_input(usr_btn[3]),.btn_output(btn_level[3]));

Screen screen(.clk(clk),.reset_n(reset_n),.usr_btn(usr_btn),.usr_sw(usr_sw),.state(state),.choice(choicew),.snk_pos(snk_posw),.apple_pos(apple_posw),.wall_pos(wall_posw),.move_end(move_end),.VGA_HSYNC(VGA_HSYNC),.VGA_VSYNC(VGA_VSYNC),.VGA_RED(VGA_RED),.VGA_GREEN(VGA_GREEN),.VGA_BLUE(VGA_BLUE));

Check check(
  .clk(clk),
  .reset_n(reset_n),
  .snk_pos(snk_posw),
  .apl_pos(apple_posw),  
  .wall_pos(wall_posw),
  .dir_sig(choicew),
  .snake_dead(snake_dead),
  .apple_eat(apple_eat),
  .new_position(new_position)
);

apple_generator appgen(
    .clk(clk),               // 時脈訊號
    .reset(reset_n),             // 重置訊號
    .apple_eat_pos(apple_eat),         // 蘋果是否被吃掉
    .snake_pos(snk_posw),  // 蛇的位置，每個節點 [7:0]
    .obstacle_pos(wall_posw), // 障礙物的位置，每個障礙物 [7:0]
    .apple_pos(new_apple_pos)   // 蘋果的位置，每個蘋果 [7:0]
);

// sram ram0(.clk(clk),.we(sram_we),.en(sram_en),.addr(sram_addr),.data_i(data_in),.data_o(data_out));

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

// -----------------------------------------------------------------
// FSM next-state logic
always @(*) begin 
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_START;
      else P_next = S_MAIN_INIT;
    S_MAIN_START: // assume that all the usr_sw(s) were originally 0
      if (starting) P_next = S_MAIN_MOVE; // go into S_MAIN_MOVE before S_MAIN_CHECK to make "snake" on screen
      else P_next = S_MAIN_START;
    S_MAIN_MOVE: // VGA start changing the snake on the screen
      if(move_end) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_MOVE;
    S_MAIN_WAIT: // user signals the choice
      if(|choice && ~pause && ~ending)  P_next = S_MAIN_CHECK;
      else if(pause) P_next = S_MAIN_PAUSE;
      else if(ending) P_next = S_MAIN_END;
      else P_next = S_MAIN_WAIT;
    S_MAIN_CHECK: // check the choice
      if(ending) P_next = S_MAIN_END;
      else if(snake_dead) P_next = S_MAIN_END;
      else if(apple_eat) P_next = S_MAIN_RE;
      else P_next = S_MAIN_MOVE;
    S_MAIN_PAUSE:
      if(~pause) P_next = S_MAIN_MOVE;
      else P_next = S_MAIN_PAUSE;
    S_MAIN_RE:
      if(re_done) P_next = S_MAIN_MOVE;
      else P_next = S_MAIN_RE;
    S_MAIN_END:
      P_next = S_MAIN_END;
    
    default: P_next = S_MAIN_INIT; // ???
  endcase
end
// END of FSM
// -----------------------------------------------------------------

// -----------------------------------------------------------------
// Main Block

integer i;
reg [$clog2(100000000):0] wait_clk;
reg test;

always @(posedge clk)begin 
  if(~reset_n)begin 
    P <= S_MAIN_INIT;
    switch <= usr_sw;
    starting <= 0;
    snk_pos <= {8'd65, 8'd64, 8'd63, 8'd62, 8'd61, 360'b0};
    apple_pos <= {8'd1, 8'd15, 8'd70, 8'd80, 8'd120};
  end else begin 
    P <= P_next;
    if(P == S_MAIN_INIT)begin 
      // Initial all the things, include LCD, uart, LED, VGA??
      switch <= usr_sw;
      starting <= 0;
      snk_pos <= {8'd65, 8'd64, 8'd63, 8'd62, 8'd61, 360'b0};
      apple_pos <= {8'd1, 8'd15, 8'd70, 8'd80, 8'd120};
      init_finished <= 1;
    end else if(P == S_MAIN_START)begin 
      // when user switch any way for switch[0], start the game.
      init_finished <= 0;
      if(usr_sw[0] != switch[0])begin 
        starting <= 1;
        switch <= usr_sw;
      end else begin 
        switch <= usr_sw;
        starting <= 0;
      end

    end else if(P == S_MAIN_MOVE)begin 
      // VGA start changing the snake on the screen
      //when changing over, go to state: S_MAIN_WAIT
      wait_clk <= 0; // bzero(wait_clk)
      switch <= usr_sw; // update switches
      choice <= 4'b0000; // clear choice
    end else if(P == S_MAIN_WAIT)begin 
      // getting choice from user, upon getting the choice or wait for a second, go to state:S_MAIN_CHECK
      if(wait_clk == 50000000)begin 
        if(~(|choice))begin 
          choice <= prev_ch;
        end
      end else begin 
        wait_clk <= wait_clk + 1;
      end
      // check if the user input some choice before choice has made
      if(~(|choice) && |btn_pressed)begin 
          choice[3:0] <= btn_pressed[3:0];
      end
      pause <= (switch[1] != usr_sw[1]);
      ending <= (switch[2] != usr_sw[2]);
    end else if(P == S_MAIN_CHECK) begin 
      prev_ch <= choice;
      if(new_position != snk_pos)begin  // check.v is done
        snk_pos <= new_position;
        if(apple_eat)begin 
          // find the eaten apple position
          apple_pos[apple_eat*8 +: 8] <= 8'b0;
        end
      end
      re_done <= 0;
    end else if(P == S_MAIN_RE)begin 
      if(~re_done)begin 
        for(i = 0; i < 5; i = i + 1)begin 
          if(new_apple_pos[i*8 +: 8] == 8'b0)begin 
            test <= 1;
          end
        end
        if(~test)begin 
          apple_pos <= new_apple_pos;
          re_done <= 1;
        end
      end
    end
  end
  
  
end

// End of Main Block
// -----------------------------------------------------------------




endmodule
