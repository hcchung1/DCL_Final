`timescale 1ns / 1ps
// ------------------------------------------------------------
// Company: Dept. of Computer Science, National Yang Ming Chiao Tung University
// Engineer: Cheng-Han Chung
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: Main Module
// Module Name: lab8
// Project Name: Final_Project
// Target Devices: FPGA
// Tool Versions:
// Description: This is snake Verilog, aim to play snake game by FPGA
//              1. Control directions by bottom
//              2. Showing snake and background on VGA
// 
// Dependencies: clk_divider, LCD_module, debounce, VGA, LED, SRAM, memory
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: This is the main module of the snake game, it will control the whole game!
// 
// ------------------------------------------------------------

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,       // switches
  output [3:0] usr_led,

  // LCD
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D, 

  // VGA 
  output VGA_HSYNC,
  output VGA_VSYNC,
  output [3:0] VGA_RED,
  output [3:0] VGA_GREEN,
  output [3:0] VGA_BLUE
);

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_START = 1, S_MAIN_MOVE = 2, S_MAIN_WAIT = 3,
                 S_MAIN_CHECK = 4, S_MAIN_RE = 5, S_MAIN_PAUSE = 6, S_MAIN_END = 7;
                 
// INIT:  0000
// START: 0001
// MOVE:  0010
// WAIT:  0011
// CHECK: 0100
// RE:    0101
// PAUSE: 0110
// END:   0111

// LCDs
reg  [127:0] row_A = "switch sw0 start";
reg  [127:0] row_B = "   Snake Game   ";

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

// Declare system variables
wire [3:0] btn_level, btn_pressed;
reg  [3:0] prev_btn_level;
reg  [2:0] P, P_next;
reg  [3:0] switch;
wire [3:0] unused = switch[3:0];
wire move_end;
wire [7:0] check_done;
reg pause;
reg ending;

reg starting;
reg wait_end = 0;

reg [399:0] snk_pos = 0; // at most 50 nodes
reg [23:0] apple_pos = 0; // at most 3 apples
reg [79:0] wall_pos = 0; // at most 10 walls
wire [79:0] new_wall_pos; // at most 10 walls

reg [3:0] choice;
reg [3:0] prev_ch;


wire [399:0] new_position;
reg checkover;
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

integer i;
reg [26:0] wait_clk;
reg test;

wire [3:0] wall_collision;

assign usr_led = P[2:0];
reg [1:0] mode = 2'b00;
wire [5:0] score;
wire [5:0] highest_score;
reg hurt = 0;

reg [30:0] counter;
reg [30:0] init_clock;
reg [1:0] init_showB;
reg [15:0] lfsr; // 用於隨機數生成的 LFSR
reg [2:0] apple_decide = 0;
reg [3:0] wall_decide = 0;
reg [7:0] temp_pos;
reg [30:0] hurt_clk = 0;
reg hurt_palse = 0;
reg [30:0] hurt_palse_clk = 0;

debounce btn_db0(.clk(clk),.btn_input(usr_btn[0]),.btn_output(btn_level[0]));
debounce btn_db1(.clk(clk),.btn_input(usr_btn[1]),.btn_output(btn_level[1]));
debounce btn_db2(.clk(clk),.btn_input(usr_btn[2]),.btn_output(btn_level[2]));
debounce btn_db3(.clk(clk),.btn_input(usr_btn[3]),.btn_output(btn_level[3]));

Screen screen(.clk(clk),.reset_n(reset_n),.usr_led(usr_led),.usr_btn(usr_btn),.usr_sw(usr_sw),.hurt(hurt_palse),.state(P),.mode(mode),.choice(choice),.snk_pos(snk_pos),.apple_pos(apple_pos),.wall_pos(wall_pos),.score(score),.highest_score(highest_score),.move_end(move_end),.VGA_HSYNC(VGA_HSYNC),.VGA_VSYNC(VGA_VSYNC),.VGA_RED(VGA_RED),.VGA_GREEN(VGA_GREEN),.VGA_BLUE(VGA_BLUE));

Check check(
  .clk(clk),
  .reset_n(reset_n),
  .state(P),
  .snk_pos(snk_pos),
  .apl_pos(apple_pos),  
  .wall_pos(wall_pos),
  .dir_sig(choice),
  .mode(mode),
  .snake_dead(snake_dead),
  .apple_eat(apple_eat),
  .new_position(new_position),
  .check_done(check_done), 
  .wall_collision(wall_collision),
  .score(score),
  .highest_score(highest_score)
);

apple_generator appgen(
    .clk(clk),               // 時脈訊號
    .reset(reset_n),             // 重置訊號
    .state(P),.mode(mode),
    .main_apple_pos(apple_pos), // 蘋果位置
    .apple_eat_pos(apple_eat),         // 蘋果被吃掉的位置
    .snake_pos(snk_pos),  // 蛇的位置，每個節點 [7:0]
    .obstacle_pos(wall_pos), // 障礙物的位置，每個障礙物 [7:0]
    .obstacle_hit_pos(wall_collision), // 障礙物被撞到的位置
    .apple_pos(new_apple_pos),   // 蘋果的位置，每個蘋果 [7:0]
    .obstacle_new_pos(new_wall_pos) // 新的障礙物位置
);

// sram ram0(.clk(clk),.we(sram_we),.en(sram_en),.addr(sram_addr),.data_i(data_in),.data_o(data_out));

// -----------------------------------------------------------------
// Button pressed detection
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

// END of Button pressed detection
// -----------------------------------------------------------------


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
      // if((wait_clk == 50000000) && ~pause)  P_next = S_MAIN_CHECK;
      // else if(pause) P_next = S_MAIN_PAUSE;
      // else P_next = S_MAIN_WAIT;
      if(pause) P_next = S_MAIN_PAUSE;
      else if(wait_end) P_next = S_MAIN_CHECK;
      else P_next = S_MAIN_WAIT;
    S_MAIN_CHECK: // check the choice
      if((checkover))P_next = S_MAIN_RE;
      else P_next = S_MAIN_CHECK;
    S_MAIN_PAUSE: // [x] switch to leave PAUSE
      if(~pause) P_next = S_MAIN_MOVE;
      else if(snake_dead) P_next = S_MAIN_END;
      else P_next = S_MAIN_PAUSE;
    S_MAIN_RE:
      if(snake_dead) P_next = S_MAIN_END;
      else if(re_done) P_next = S_MAIN_MOVE;
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



function is_overlap( input [7:0] pos, input [399:0] entity_pos);
    integer i;
    begin
        is_overlap = 0;
        for (i = 0; i < 50; i = i + 1) begin
            if (pos == entity_pos[i*8 +: 8]) begin
                is_overlap = 1;
            end
        end
    end
endfunction

always @(posedge clk)begin 
  if(~reset_n)begin 

    P <= S_MAIN_INIT;
    switch <= usr_sw;
    starting <= 0;
    snk_pos <= {8'd65, 8'd64, 8'd63, 8'd62, 8'd61, 360'b0};
    apple_pos <= 0;
    wall_pos <= 0;
    init_finished <= 0;
    counter <= 0;
    wait_end <= 0;
    mode <= 0;
    init_clock <= 0;
    init_showB <= 0;
    lfsr <= 16'hACEF; // 初始化 LFSR
    apple_decide <= 0;
    wall_decide <= 0;
    hurt_clk <= 0;
    hurt <= 0;
    hurt_palse <= 0;
    hurt_palse_clk <= 0;

  end else begin 

    P <= P_next;

    if(P == S_MAIN_INIT)begin 

      // Initial all the things, include LCD, uart, LED, VGA??
      // [x] let user decide which mode to play
      switch <= usr_sw;
      starting <= 0;
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      temp_pos <= lfsr[6:0];
      snk_pos <= {8'd66, 8'd65, 8'd64, 8'd63, 8'd62, 360'b0}; // initialize snake position
      if(apple_decide < 3)begin 
        if(temp_pos <= 120 && temp_pos > 0)begin 
          if (!is_overlap(temp_pos, snk_pos) && !is_overlap(temp_pos, wall_pos) && !is_overlap(temp_pos, apple_pos)) begin
            apple_pos <= {temp_pos, apple_pos[23:16], apple_pos[15:8]};
            apple_decide <= apple_decide + 1;
          end
        end
      end else if(wall_decide < 10)begin 
        if(temp_pos <= 120 && temp_pos > 0)begin 
          if (!is_overlap(temp_pos, snk_pos) && !is_overlap(temp_pos, wall_pos) && !is_overlap(temp_pos, apple_pos)) begin
            wall_pos <= {temp_pos, wall_pos[79:8]};
            wall_decide <= wall_decide + 1;
          end
        end
      end
      
      if(btn_pressed[0])begin 
        // no border
        mode <= 0;
        init_finished <= 1;
        wall_pos <= wall_pos;
      end else if(btn_pressed[1])begin 
        // 3 stones with border
        mode <= 1;
        init_finished <= 1;
        wall_pos[55:0] <= 0;
      end else if(btn_pressed[2])begin 
        // 5 stones with border
        mode <= 2;
        init_finished <= 1;
        wall_pos[39:0] <= 0;
      end else if(btn_pressed[3])begin 
        // 10 stones with border
        mode <= 3;
        init_finished <= 1;
        wall_pos <= wall_pos;
      end
      init_clock <= init_clock + 1;
      row_A = " Press for mode ";

      if(init_clock == 200000000)begin 
        init_showB <= init_showB + 1;
        init_clock <= 0;
      end
      case(init_showB)
        0: row_B = "btn0: no border ";
        1: row_B = "btn1: 3  stones ";
        2: row_B = "btn2: 5  stones ";
        3: row_B = "btn3: 10 stones ";
        default: row_B = "btn0: no border ";
      endcase
      hurt_clk <= 0;
      hurt <= 0;
      hurt_palse <= 0;
      hurt_palse_clk <= 0;
      counter <= 0;
      wait_end <= 0;

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
      choice <= 4'b0001;
      prev_ch <= 4'b0001;
      row_A = {"  S_MAIN_START", (((choice > 9)?"7":"0") + choice), (((prev_ch > 9)?"7":"0") + prev_ch)};
      row_B = "switch sw0 start";

    end else if(P == S_MAIN_MOVE)begin 

      // VGA start changing the snake on the screen
      // [x] when changing over, go to state: S_MAIN_WAIT
      wait_clk <= 0; // bzero(wait_clk)
      switch <= usr_sw; // update switches
      choice <= 4'b0000; // clear choice
      
      row_A = "  S_MAIN_MOVE   ";
      row_B = "   Snake Game   ";
      wait_end <= 0;

    end else if(P == S_MAIN_WAIT)begin 

      // [x] getting choice from user, upon getting the choice or wait for a second, go to state:S_MAIN_CHECK
      if(wait_clk >= 50000000)begin // dec'50000000 -> hex'2FAF080
        if(choice == 0)begin 
          choice <= prev_ch;
        end
        wait_end <= 1;
        checkover <= 0;
      end else if(wait_clk < 50000000)begin 
        wait_clk <= wait_clk + 1;
        if(choice == 0)begin // when no choice has been made, and user press the button

            if(btn_pressed[0] && prev_ch != 4'b0010)begin // if user press up when down is chosen
              choice <= 4'b0001;
            end else if(btn_pressed[1] && prev_ch != 4'b0001)begin // if user press down when up is chosen
              choice <= 4'b0010;
            end else if(btn_pressed[2] && prev_ch != 4'b1000)begin // if user press right when left is chosen
              choice <= 4'b0100;
            end else if(btn_pressed[3] && prev_ch != 4'b0100)begin // if user press left when right is chosen
              choice <= 4'b1000;
            end
        end
      end

      // check if the user input some choice before choice has made
      // [x] if user input up when down is chosen, then change the choice to up; if user input left when right is chosen, then change the choice to left; and so on.

      // [x] check if user want to pause at any moment when playing the game
      if(switch[1] != usr_sw[1])begin 
        pause <= 1;
        switch <= usr_sw;
      end

      row_A = {apple_eat + "0", check_done + "0" ,"S_MAIN_WAIT ", (((snk_pos[399:396] > 9)?"7":"0") + snk_pos[399:396]), (((snk_pos[395:392] > 9)?"7":"0") + snk_pos[395:392])};
      row_B = {(((wait_clk[26:24] > 9)?"7":"0") + wait_clk[26:24]), (((wait_clk[23:20] > 9)?"7":"0") + wait_clk[23:20]), (((wait_clk[19:16] > 9)?"7":"0") + wait_clk[19:16]), (((wait_clk[15:12] > 9)?"7":"0") + wait_clk[15:12]), (((wait_clk[11:8] > 9)?"7":"0") + wait_clk[11:8]), (((wait_clk[7:4] > 9)?"7":"0") + wait_clk[7:4]) ,(((wait_clk[3:0] > 9)?"7":"0") + wait_clk[3:0]), " ", ((choice[3])?"U":" "), ((choice[2])?"D":" "), ((choice[1])?"L":" "), ((choice[0])?"R":" "), " ", ((pause)?"P":" "), " ", (((choice > 9)?"7":"0") + choice)};

    end else if(P == S_MAIN_CHECK) begin 

      // [x] maybe have signal to know if check is ended
      if(snk_pos != new_position)begin 
        checkover <= 1;
      end
      
      re_done <= 0;

      row_A <= {(((snk_pos[399:396] > 9)?"7":"0") + snk_pos[399:396]), (((snk_pos[395:392] > 9)?"7":"0") + snk_pos[395:392]), "S_MAIN_CHE",(snake_dead + "0") ,(((choice[3:0] > 9)?"7":"0") + choice[3:0]) , " ",(((counter[3:0] > 9)?"7":"0") + counter[3:0])};
      row_B <= {"   Snake Game ", (((new_position[399:396] > 9)?"7":"0") + new_position[399:396]), (((new_position[395:392] > 9)?"7":"0") + new_position[395:392])};


    end else if(P == S_MAIN_RE)begin 

      // [x] check for signals used for the ending of recovery (re_done)
      if(apple_eat || wall_collision)begin 
        if(wall_collision)begin 
          hurt <= 1;
        end
        if(~re_done)begin 
          if(new_apple_pos != apple_pos)begin 
            apple_pos <= new_apple_pos; // update apple position
            re_done <= 1;
          end else if(new_wall_pos != wall_pos)begin 
            wall_pos <= new_wall_pos; // update wall position
            re_done <= 1;
          end
        end
      end else if(snake_dead)begin
        ending <= 1;
        re_done <= 1;
      end else begin // no apple been eaten -> directly leave after update snk_pos
        re_done <= 1;
      end

      prev_ch <= choice; // update the previous choice
      snk_pos <= new_position; // update the snake position
      

      row_A <= "   S_MAIN_RE    ";
      row_B <= "   Snake Game   ";

    end else if(P == S_MAIN_PAUSE)begin 

      // [x] switch to leave PAUSE
      if(switch[1] != usr_sw[1])begin 
        pause <= 0;
        switch <= usr_sw;
      end
      wait_clk <= 0; // when going back to S_MAIN_MOVE, reset the wait_clk
      row_A <= "  S_MAIN_PAUSE  ";
      row_B <= "switch sw1 leave";

    end else if(P == S_MAIN_END)begin 
      row_A <= "   S_MAIN_END   ";
      row_B <= "   Snake Game   ";
      if(switch[0] != usr_sw[0])begin 

        // [] if user switch any way for switch[0], restart the game, with remebering the highest score
        // [] check.v needs to handles this.
        P <= S_MAIN_INIT;
        switch <= usr_sw;
        ending <= 0;
      end
      apple_pos <= 0;
      wall_pos <= 0;
      apple_decide <= 0;
      wall_decide <= 0;
      snk_pos <= {8'd64, 8'd63, 8'd62, 8'd61, 8'd60, 360'b0};
    end

    if(hurt)begin 
      hurt_clk <= hurt_clk + 1;
      if(hurt_clk == 200000000)begin 
        hurt <= 0;
        hurt_clk <= 0;
      end else if(hurt_clk < 200000000)begin 
        hurt_palse_clk <= hurt_palse_clk + 1;
        if(hurt_palse_clk == 20000000)begin 
          hurt_palse <= ~hurt_palse;
          hurt_palse_clk <= 0;
        end
      end
    end else begin 
      hurt_palse_clk <= 0;
      hurt_palse <= 0;
      hurt_clk <= 0;
    end

    if(P != P_next)begin 
      switch <= usr_sw;
    end
  end
  
  
end

// End of Main Block
// -----------------------------------------------------------------




endmodule
