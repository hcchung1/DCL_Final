`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/10 21:42:44
// Design Name: 
// Module Name: Screen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Screen(
    input  clk,
    input  reset_n,
    input  [3:0] usr_led,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    input  hurt,
    input  [2:0] state,  // main state machine state
    input  [1:0] mode,   // game mode
    input  [3:0] choice,  // 
    input  [399:0] snk_pos,
    input  [23:0] apple_pos,
    input  [79:0] wall_pos,
    input  [5:0] score,
    input  [5:0] highest_score,
    output move_end,



    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish_clock;
wire [9:0]  pos;
wire        fish_region;

// declare SRAM control signals
wire [16:0] sram_addr;
wire [11:0] data_in;
wire [11:0] data_out;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH_HPOS   = 64; 
localparam FISH_W      = 24; // Width of the fish.
localparam FISH_H      = 24; // Height of the fish.
reg [17:0] fish_addr[0:15]; 
reg [17:0] gameover_addr;
reg [17:0] number_addr[0:9];
// [0] head right
// [1] head left
// [2] head up
// [3] head down
// [4] body-left/right
// [5] body-up/down
// [6] tail right
// [7] tail left
// [8] tail up
// [9] tail down
// [10] right-up / down-left (4)
// [11] right-down / up-left (1)
// [12] left-down / up-right (2)
// [13] left-up / down-right (3)
// [14] apple
// [15] wall

// 
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
    fish_addr[0] = VBUF_W*VBUF_H + 18'd0;        
    fish_addr[1] = VBUF_W*VBUF_H + FISH_W*FISH_H;
    fish_addr[2] = VBUF_W*VBUF_H + FISH_W*FISH_H*2;
    fish_addr[3] = VBUF_W*VBUF_H + FISH_W*FISH_H*3;
    fish_addr[4] = VBUF_W*VBUF_H + FISH_W*FISH_H*4;
    fish_addr[5] = VBUF_W*VBUF_H + FISH_W*FISH_H*5;
    fish_addr[6] = VBUF_W*VBUF_H + FISH_W*FISH_H*6;
    fish_addr[7] = VBUF_W*VBUF_H + FISH_W*FISH_H*7;
    fish_addr[8] = VBUF_W*VBUF_H + FISH_W*FISH_H*8;
    fish_addr[9] = VBUF_W*VBUF_H + FISH_W*FISH_H*9;
    fish_addr[10] = VBUF_W*VBUF_H + FISH_W*FISH_H*10;
    fish_addr[11] = VBUF_W*VBUF_H + FISH_W*FISH_H*11;
    fish_addr[12] = VBUF_W*VBUF_H + FISH_W*FISH_H*12;
    fish_addr[13] = VBUF_W*VBUF_H + FISH_W*FISH_H*13;
    fish_addr[14] = VBUF_W*VBUF_H + FISH_W*FISH_H*14;
    fish_addr[15] = VBUF_W*VBUF_H + FISH_W*FISH_H*15;
    gameover_addr = VBUF_W*VBUF_H + FISH_W*FISH_H*16;
    number_addr[0] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31;
    number_addr[1] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750;
    number_addr[2] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*2;
    number_addr[3] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*3;
    number_addr[4] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*4;
    number_addr[5] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*5;
    number_addr[6] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*6;
    number_addr[7] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*7;
    number_addr[8] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*8;
    number_addr[9] = VBUF_W*VBUF_H + FISH_W*FISH_H*16 + 120*31 + 750*9;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

wire [16:0] snake_addr;
wire [11:0] data_snk_o;
reg  [17:0] snkreg_addr;

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H+FISH_W*FISH_H*16+120*31+750*10), .FILE("background.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .addr_snk(snake_addr),  .data_i(data_in), .data_o(data_out), .data_snk_o(data_snk_o));

assign sram_we = usr_sw[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign snake_addr = snkreg_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
// assign pos = fish_clock[31:20]; // the x position of the right edge of the fish image
//                                 // in the 640x480 VGA screen
// always @(posedge clk) begin
//   if (~reset_n || fish_clock[31:21] > VBUF_W + FISH_W)
//     fish_clock <= 0;
//   else
//     fish_clock <= fish_clock + 1;
// end
// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.

reg is_finished;
reg [6:0] length;
reg [399:0] snake;
reg [23:0] apple;
reg [79:0] wall;
reg [4:0] mark[0:119];
reg [9:0] Vertical_pos[0:9], Horizontal_pos[0:11];
integer idx;
integer i;
reg [1:0] change;
reg [7:0] prev_snake;

initial begin
    change = 0;
    Vertical_pos[0] = 0;
    Vertical_pos[1] = 24;
    Vertical_pos[2] = 48;
    Vertical_pos[3] = 72;
    Vertical_pos[4] = 96;
    Vertical_pos[5] = 120;
    Vertical_pos[6] = 144;
    Vertical_pos[7] = 168;
    Vertical_pos[8] = 192;
    Vertical_pos[9] = 216;
    Horizontal_pos[0] = 48;
    Horizontal_pos[1] = 96;
    Horizontal_pos[2] = 144;
    Horizontal_pos[3] = 192;
    Horizontal_pos[4] = 240;
    Horizontal_pos[5] = 288;
    Horizontal_pos[6] = 336;
    Horizontal_pos[7] = 384;
    Horizontal_pos[8] = 432;
    Horizontal_pos[9] = 480;
    Horizontal_pos[10] = 528;
    Horizontal_pos[11] = 576;
end
localparam GAMEOVER_H = 31;
localparam GAMEOVER_W = 120;
localparam GAMEOVER_VPOS = 100;
localparam GAMEOVER_HPOS = 400;
localparam NUMBER_H = 30;
localparam NUMBER_W = 25;
localparam NUMBER1_VPOS = 200;
localparam NUMBER2_VPOS = 200;
localparam NUMBER1_HPOS = 613;
localparam NUMBER2_HPOS = 639;
wire [119:0] now_region;
// assign now_region =
//            pixel_y >= (Vertical_pos<<1) && pixel_y < (Vertical_pos+FISH_H)<<1 &&
//            (pixel_x + FISH_W*2 - 1) >= pos && pixel_x < pos + 1;
wire stop_region1, stop_region2;
assign stop_region1 = (pixel_y >= (12 << 1)) && (pixel_y < ((12 + 24) << 1)) &&
                     (pixel_x + (10 * 2) - 1 >= 602) && (pixel_x < 602 + 1);

assign stop_region2 = (pixel_y >= (12 << 1)) && (pixel_y < ((12 + 24) << 1)) &&
                        (pixel_x + (10 * 2) - 1 >= 625) && (pixel_x < 625 + 1);

wire gameover_region;
assign gameover_region = (pixel_y >= (GAMEOVER_VPOS << 1)) && (pixel_y < ((GAMEOVER_VPOS + GAMEOVER_H) << 1)) &&
                        (pixel_x + (GAMEOVER_W * 2) - 1 >= GAMEOVER_HPOS) && (pixel_x < GAMEOVER_HPOS + 1);
wire number_region1, number_region2;
assign number_region1 = (pixel_y >= (NUMBER1_VPOS << 1)) && (pixel_y < ((NUMBER1_VPOS + NUMBER_H) << 1)) &&
                        (pixel_x + (NUMBER_W * 2) - 1 >= NUMBER1_HPOS) && (pixel_x < NUMBER1_HPOS + 1);
assign number_region2 = (pixel_y >= (NUMBER2_VPOS << 1)) && (pixel_y < ((NUMBER2_VPOS + NUMBER_H) << 1)) &&
                        (pixel_x + (NUMBER_W * 2) - 1 >= NUMBER2_HPOS) && (pixel_x < NUMBER2_HPOS + 1);


                
genvar k, j;
generate
    for (k = 0; k < 10; k = k + 1) begin : outer_loop
        for (j = 0; j < 12; j = j + 1) begin : inner_loop
            assign now_region[k * 12 + j] = 
                (pixel_y >= (Vertical_pos[k] << 1)) && 
                (pixel_y < ((Vertical_pos[k] + FISH_H) << 1)) &&
                (pixel_x + (FISH_W * 2) - 1 >= Horizontal_pos[j]) && 
                (pixel_x < Horizontal_pos[j] + 1);
        end
    end
endgenerate

always @(posedge clk) begin
    if (~reset_n || state == 0) begin
        is_finished <= 0;
        snake <= snk_pos;
        apple <= 0;
        wall <= 0;
        length <= 0;
        change <= 0;
        prev_snake <= 0;
        for (i = 0; i < 120; i = i + 1) begin
            mark[i] <= 16;
        end
    end else if (state == 1 && snake != 0) begin
        snake <= snake << 8;
        prev_snake <= snake[399:392];
        if (snake[399:392] != 0) begin
            length <= length + 1;
            if (length == 0) begin
                if (snake[399:392] == snake[391:384] + 1) begin // head right
                    mark[snake[399:392]-1] <= 0;
                end else if (snake[399:392] == snake[391:384] - 1) begin // head left
                    mark[snake[399:392]-1] <= 1;
                end else if (snake[399:392] == snake[391:384] - 12) begin // head up
                    mark[snake[399:392]-1] <= 2;
                end else if (snake[399:392] == snake[391:384] + 12) begin // head down
                    mark[snake[399:392]-1] <= 3;
                end
            end else if (snake[391:384] != 0) begin
                if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake + 1) || (snake[399:392] == prev_snake - 11 && snake[399:392] == snake[391:384] - 1) || (snake[399:392] == snake[391:384] - 11 && snake[399:392] == prev_snake - 1)) // left-right
                    mark[snake[399:392]-1] <= 5;
                else if ((snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 12) || (snake[399:392] == prev_snake + 108 && snake[399:392] == snake[391:384] - 12) || (snake[399:392] == prev_snake - 12 && snake[399:392] == snake[391:384] + 108)) // up-down 
                    mark[snake[399:392]-1] <= 4;
                else if ((snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake - 1)) // right-up / down-left
                    mark[snake[399:392]-1] <= 12;
                else if ((snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 1)) // right-down / up-left
                    mark[snake[399:392]-1] <= 13;
                else if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake + 1)) // left-down / up-right
                    mark[snake[399:392]-1] <= 10;
                else if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 1)) // left-up / down-right
                    mark[snake[399:392]-1] <= 11;
            end else if (snake[391:384] == 0) begin
                if (snake[399:392] == prev_snake + 1) // tail right
                    mark[snake[399:392]-1] <= 6;
                else if (snake[399:392] == prev_snake - 1) // tail left
                    mark[snake[399:392]-1] <= 7;
                else if (snake[399:392] == prev_snake - 12) // tail up
                    mark[snake[399:392]-1] <= 8;
                else if (snake[399:392] == prev_snake + 12) // tail down
                    mark[snake[399:392]-1] <= 9;
            end
        end    
    end else if (state == 2 && is_finished == 0) begin
        if (change == 0) begin
            for (i = 0; i < 120; i = i + 1) begin
                mark[i] <= 16;
            end
            change <= 1;
            is_finished <= 0;
            prev_snake <= 0;
            snake <= snk_pos;
            apple <= apple_pos;
            wall <= wall_pos;
            length <= 0;
        end else if (change == 1) begin 
            snake <= snake << 8;
            prev_snake <= snake[399:392];
            if (snake[399:392] != 0) begin
                length <= length + 1;
                if (length == 0) begin
                    if ((snake[399:392] == snake[391:384] + 1) || snake[399:392] == snake[391:384] + 11) begin // head right
                        mark[snake[399:392]-1] <= 0;
                    end else if ((snake[399:392] == snake[391:384] - 1) || snake[399:392] == snake[391:384] - 11) begin // head left
                        mark[snake[399:392]-1] <= 1;
                    end else if ((snake[399:392] == snake[391:384] - 12) || snake[399:392] == snake[391:384] - 108) begin // head up
                        mark[snake[399:392]-1] <= 2;
                    end else if ((snake[399:392] == snake[391:384] + 12) || snake[399:392] == snake[391:384] + 108) begin // head down
                        mark[snake[399:392]-1] <= 3;
                    end
                end else if (snake[391:384] != 0) begin
                    if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake + 1) || (snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake + 11) || (snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 11 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake - 11)) // left-right
                        mark[snake[399:392]-1] <= 5;
                    else if ((snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 108) || (snake[399:392] == snake[391:384] - 108 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 108) || (snake[399:392] == snake[391:384] + 108 && snake[399:392] == prev_snake - 12)) // up-down 
                        mark[snake[399:392]-1] <= 4;
                    else if ((snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake + 108) || (snake[399:392] == snake[391:384] + 108 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 11) || (snake[399:392] == snake[391:384] + 11 && snake[399:392] == prev_snake - 12)) // left-down / up-right (2)
                        mark[snake[399:392]-1] <= 12;
                    else if ((snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 1) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake + 11) || (snake[399:392] == snake[391:384] + 11 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] - 1 && snake[399:392] == prev_snake - 108) || (snake[399:392] == snake[391:384] - 108 && snake[399:392] == prev_snake - 1)) // left-up / down-right (3)
                        mark[snake[399:392]-1] <= 13;
                    else if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake + 1) || (snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 108) || (snake[399:392] == snake[391:384] - 108 && snake[399:392] == prev_snake + 1) || (snake[399:392] == snake[391:384] - 11 && snake[399:392] == prev_snake + 12) || (snake[399:392] == snake[391:384] + 12 && snake[399:392] == prev_snake - 11)) // right-up / down-left (4)
                        mark[snake[399:392]-1] <= 10;
                    else if ((snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake + 1) || (snake[399:392] == snake[391:384] - 11 && snake[399:392] == prev_snake - 12) || (snake[399:392] == snake[391:384] - 12 && snake[399:392] == prev_snake - 11) || (snake[399:392] == snake[391:384] + 1 && snake[399:392] == prev_snake + 108) || (snake[399:392] == snake[391:384] + 108 && snake[399:392] == prev_snake + 1)) // right-down / up-left (1)
                        mark[snake[399:392]-1] <= 11;
                end else if (snake[391:384] == 0) begin
                    change <= 2;
                    if ((snake[399:392] == snake[391:384] + 1) || snake[399:392] == snake[391:384] + 11) begin // tail right
                        mark[snake[399:392]-1] <= 6;
                    end else if ((snake[399:392] == snake[391:384] - 1) || snake[399:392] == snake[391:384] - 11) begin // tail left
                        mark[snake[399:392]-1] <= 7;
                    end else if ((snake[399:392] == snake[391:384] - 12) || snake[399:392] == snake[391:384] - 108) begin // tail up
                        mark[snake[399:392]-1] <= 8;
                    end else if ((snake[399:392] == snake[391:384] + 12) || snake[399:392] == snake[391:384] + 108) begin // tail down
                        mark[snake[399:392]-1] <= 9;
                    end
                end
            end
        end else if (change == 2) begin
            apple <= apple << 8;
            if (apple[23:16] != 0) begin
                mark[apple[23:16]-1] <= 14;
            end else if (apple == 0) begin
                change <= 3;
            end
        end else if (change == 3) begin
            wall <= wall << 8;
            if (wall[79:72] != 0) begin
                mark[wall[79:72]-1] <= 15;
            end else if (wall == 0) begin
                is_finished <= 1;
            end
        end
        
    end else if (state == 3) begin
        is_finished <= 0;
        change <= 0;
    end else if (state == 7) begin
        for (idx = 0; idx < 120; idx = idx + 1) begin
            mark[idx] <= 16;
        end
    end

end

assign move_end = is_finished;
integer m,n;
reg [4:0] disp;
reg [5:0] sc;

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
    snkreg_addr <= 0;
    disp <= 1;
//   else if (fish_region)
//     pixel_addr <= fish_addr[fish_clock[23]] +
//                   ((pixel_y>>1)-FISH_VPOS)*FISH_W +
//                   ((pixel_x +(FISH_W*2-1)-pos)>>1);
  end else begin
    
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    if (now_region[0] && mark[0] != 16) begin
        snkreg_addr <= fish_addr[mark[0]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[0]+1;
    end else if (now_region[1] && mark[1] != 16) begin
        snkreg_addr <= fish_addr[mark[1]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[1]+1;
    end else if (now_region[2] && mark[2] != 16) begin
        snkreg_addr <= fish_addr[mark[2]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[2]+1;
    end else if (now_region[3] && mark[3] != 16) begin
        snkreg_addr <= fish_addr[mark[3]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[3]+1;
    end else if (now_region[4] && mark[4] != 16) begin
        snkreg_addr <= fish_addr[mark[4]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[4]+1;
    end else if (now_region[5] && mark[5] != 16) begin
        snkreg_addr <= fish_addr[mark[5]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[5]+1;
    end else if (now_region[6] && mark[6] != 16) begin
        snkreg_addr <= fish_addr[mark[6]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[6]+1;
    end else if (now_region[7] && mark[7] != 16) begin
        snkreg_addr <= fish_addr[mark[7]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[7]+1;
    end else if (now_region[8] && mark[8] != 16) begin
        snkreg_addr <= fish_addr[mark[8]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[8]+1;
    end else if (now_region[9] && mark[9] != 16) begin
        snkreg_addr <= fish_addr[mark[9]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[9]+1;
    end else if (now_region[10] && mark[10] != 16) begin
        snkreg_addr <= fish_addr[mark[10]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[10]+1;
    end else if (now_region[11] && mark[11] != 16) begin
        snkreg_addr <= fish_addr[mark[11]] + ((pixel_y >> 1) - Vertical_pos[0]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[11]+1;
    end else if (now_region[12] && mark[12] != 16) begin
        snkreg_addr <= fish_addr[mark[12]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[12]+1;
    end else if (now_region[13] && mark[13] != 16) begin
        snkreg_addr <= fish_addr[mark[13]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[13]+1;
    end else if (now_region[14] && mark[14] != 16) begin
        snkreg_addr <= fish_addr[mark[14]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[14]+1;
    end else if (now_region[15] && mark[15] != 16) begin
        snkreg_addr <= fish_addr[mark[15]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[15]+1;
    end else if (now_region[16] && mark[16] != 16) begin
        snkreg_addr <= fish_addr[mark[16]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[16]+1;
    end else if (now_region[17] && mark[17] != 16) begin
        snkreg_addr <= fish_addr[mark[17]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[17]+1;
    end else if (now_region[18] && mark[18] != 16) begin
        snkreg_addr <= fish_addr[mark[18]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[18]+1;
    end else if (now_region[19] && mark[19] != 16) begin
        snkreg_addr <= fish_addr[mark[19]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[19]+1;
    end else if (now_region[20] && mark[20] != 16) begin
        snkreg_addr <= fish_addr[mark[20]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[20]+1;
    end else if (now_region[21] && mark[21] != 16) begin
        snkreg_addr <= fish_addr[mark[21]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[21]+1;
    end else if (now_region[22] && mark[22] != 16) begin
        snkreg_addr <= fish_addr[mark[22]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[22]+1;
    end else if (now_region[23] && mark[23] != 16) begin
        snkreg_addr <= fish_addr[mark[23]] + ((pixel_y >> 1) - Vertical_pos[1]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[23]+1;
    end else if (now_region[24] && mark[24] != 16) begin
        snkreg_addr <= fish_addr[mark[24]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[24]+1;
    end else if (now_region[25] && mark[25] != 16) begin
        snkreg_addr <= fish_addr[mark[25]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[25]+1;
    end else if (now_region[26] && mark[26] != 16) begin
        snkreg_addr <= fish_addr[mark[26]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[26]+1;
    end else if (now_region[27] && mark[27] != 16) begin
        snkreg_addr <= fish_addr[mark[27]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[27]+1;
    end else if (now_region[28] && mark[28] != 16) begin
        snkreg_addr <= fish_addr[mark[28]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[28]+1;
    end else if (now_region[29] && mark[29] != 16) begin
        snkreg_addr <= fish_addr[mark[29]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[29]+1;
    end else if (now_region[30] && mark[30] != 16) begin
        snkreg_addr <= fish_addr[mark[30]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[30]+1;
    end else if (now_region[31] && mark[31] != 16) begin
        snkreg_addr <= fish_addr[mark[31]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[31]+1;
    end else if (now_region[32] && mark[32] != 16) begin
        snkreg_addr <= fish_addr[mark[32]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[32]+1;
    end else if (now_region[33] && mark[33] != 16) begin
        snkreg_addr <= fish_addr[mark[33]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[33]+1;
    end else if (now_region[34] && mark[34] != 16) begin
        snkreg_addr <= fish_addr[mark[34]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[34]+1;
    end else if (now_region[35] && mark[35] != 16) begin
        snkreg_addr <= fish_addr[mark[35]] + ((pixel_y >> 1) - Vertical_pos[2]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[35]+1;
    end else if (now_region[36] && mark[36] != 16) begin
        snkreg_addr <= fish_addr[mark[36]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[36]+1;
    end else if (now_region[37] && mark[37] != 16) begin
        snkreg_addr <= fish_addr[mark[37]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[37]+1;
    end else if (now_region[38] && mark[38] != 16) begin
        snkreg_addr <= fish_addr[mark[38]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[38]+1;
    end else if (now_region[39] && mark[39] != 16) begin
        snkreg_addr <= fish_addr[mark[39]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[39]+1;
    end else if (now_region[40] && mark[40] != 16) begin
        snkreg_addr <= fish_addr[mark[40]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[40]+1;
    end else if (now_region[41] && mark[41] != 16) begin
        snkreg_addr <= fish_addr[mark[41]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[41]+1;
    end else if (now_region[42] && mark[42] != 16) begin
        snkreg_addr <= fish_addr[mark[42]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[42]+1;
    end else if (now_region[43] && mark[43] != 16) begin
        snkreg_addr <= fish_addr[mark[43]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[43]+1;
    end else if (now_region[44] && mark[44] != 16) begin
        snkreg_addr <= fish_addr[mark[44]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[44]+1;
    end else if (now_region[45] && mark[45] != 16) begin
        snkreg_addr <= fish_addr[mark[45]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[45]+1;
    end else if (now_region[46] && mark[46] != 16) begin
        snkreg_addr <= fish_addr[mark[46]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[46]+1;
    end else if (now_region[47] && mark[47] != 16) begin
        snkreg_addr <= fish_addr[mark[47]] + ((pixel_y >> 1) - Vertical_pos[3]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[47]+1;
    end else if (now_region[48] && mark[48] != 16) begin
        snkreg_addr <= fish_addr[mark[48]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[48]+1;
    end else if (now_region[49] && mark[49] != 16) begin
        snkreg_addr <= fish_addr[mark[49]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[49]+1;
    end else if (now_region[50] && mark[50] != 16) begin
        snkreg_addr <= fish_addr[mark[50]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[50]+1;
    end else if (now_region[51] && mark[51] != 16) begin
        snkreg_addr <= fish_addr[mark[51]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[51]+1;
    end else if (now_region[52] && mark[52] != 16) begin
        snkreg_addr <= fish_addr[mark[52]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[52]+1;
    end else if (now_region[53] && mark[53] != 16) begin
        snkreg_addr <= fish_addr[mark[53]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[53]+1;
    end else if (now_region[54] && mark[54] != 16) begin
        snkreg_addr <= fish_addr[mark[54]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[54]+1;
    end else if (now_region[55] && mark[55] != 16) begin
        snkreg_addr <= fish_addr[mark[55]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[55]+1;
    end else if (now_region[56] && mark[56] != 16) begin
        snkreg_addr <= fish_addr[mark[56]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[56]+1;
    end else if (now_region[57] && mark[57] != 16) begin
        snkreg_addr <= fish_addr[mark[57]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[57]+1;
    end else if (now_region[58] && mark[58] != 16) begin
        snkreg_addr <= fish_addr[mark[58]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[58]+1;
    end else if (now_region[59] && mark[59] != 16) begin
        snkreg_addr <= fish_addr[mark[59]] + ((pixel_y >> 1) - Vertical_pos[4]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[59]+1;
    end else if (now_region[60] && mark[60] != 16) begin
        snkreg_addr <= fish_addr[mark[60]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[60]+1;
    end else if (now_region[61] && mark[61] != 16) begin
        snkreg_addr <= fish_addr[mark[61]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[61]+1;
    end else if (now_region[62] && mark[62] != 16) begin
        snkreg_addr <= fish_addr[mark[62]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[62]+1;
    end else if (now_region[63] && mark[63] != 16) begin
        snkreg_addr <= fish_addr[mark[63]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[63]+1;
    end else if (now_region[64] && mark[64] != 16) begin
        snkreg_addr <= fish_addr[mark[64]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[64]+1;
    end else if (now_region[65] && mark[65] != 16) begin
        snkreg_addr <= fish_addr[mark[65]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[65]+1;
    end else if (now_region[66] && mark[66] != 16) begin
        snkreg_addr <= fish_addr[mark[66]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[66]+1;
    end else if (now_region[67] && mark[67] != 16) begin
        snkreg_addr <= fish_addr[mark[67]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[67]+1;
    end else if (now_region[68] && mark[68] != 16) begin
        snkreg_addr <= fish_addr[mark[68]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[68]+1;
    end else if (now_region[69] && mark[69] != 16) begin
        snkreg_addr <= fish_addr[mark[69]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[69]+1;
    end else if (now_region[70] && mark[70] != 16) begin
        snkreg_addr <= fish_addr[mark[70]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[70]+1;
    end else if (now_region[71] && mark[71] != 16) begin
        snkreg_addr <= fish_addr[mark[71]] + ((pixel_y >> 1) - Vertical_pos[5]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[71]+1;
    end else if (now_region[72] && mark[72] != 16) begin
        snkreg_addr <= fish_addr[mark[72]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[72]+1;
    end else if (now_region[73] && mark[73] != 16) begin
        snkreg_addr <= fish_addr[mark[73]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[73]+1;
    end else if (now_region[74] && mark[74] != 16) begin
        snkreg_addr <= fish_addr[mark[74]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[74]+1;
    end else if (now_region[75] && mark[75] != 16) begin
        snkreg_addr <= fish_addr[mark[75]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[75]+1;
    end else if (now_region[76] && mark[76] != 16) begin
        snkreg_addr <= fish_addr[mark[76]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[76]+1;
    end else if (now_region[77] && mark[77] != 16) begin
        snkreg_addr <= fish_addr[mark[77]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[77]+1;
    end else if (now_region[78] && mark[78] != 16) begin
        snkreg_addr <= fish_addr[mark[78]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[78]+1;
    end else if (now_region[79] && mark[79] != 16) begin
        snkreg_addr <= fish_addr[mark[79]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[79]+1;
    end else if (now_region[80] && mark[80] != 16) begin
        snkreg_addr <= fish_addr[mark[80]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[80]+1;
    end else if (now_region[81] && mark[81] != 16) begin
        snkreg_addr <= fish_addr[mark[81]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[81]+1;
    end else if (now_region[82] && mark[82] != 16) begin
        snkreg_addr <= fish_addr[mark[82]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[82]+1;
    end else if (now_region[83] && mark[83] != 16) begin
        snkreg_addr <= fish_addr[mark[83]] + ((pixel_y >> 1) - Vertical_pos[6]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[83]+1;
    end else if (now_region[84] && mark[84] != 16) begin
        snkreg_addr <= fish_addr[mark[84]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[84]+1;
    end else if (now_region[85] && mark[85] != 16) begin
        snkreg_addr <= fish_addr[mark[85]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[85]+1;
    end else if (now_region[86] && mark[86] != 16) begin
        snkreg_addr <= fish_addr[mark[86]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[86]+1;
    end else if (now_region[87] && mark[87] != 16) begin
        snkreg_addr <= fish_addr[mark[87]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[87]+1;
    end else if (now_region[88] && mark[88] != 16) begin
        snkreg_addr <= fish_addr[mark[88]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[88]+1;
    end else if (now_region[89] && mark[89] != 16) begin
        snkreg_addr <= fish_addr[mark[89]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[89]+1;
    end else if (now_region[90] && mark[90] != 16) begin
        snkreg_addr <= fish_addr[mark[90]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[90]+1;
    end else if (now_region[91] && mark[91] != 16) begin
        snkreg_addr <= fish_addr[mark[91]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[91]+1;
    end else if (now_region[92] && mark[92] != 16) begin
        snkreg_addr <= fish_addr[mark[92]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[92]+1;
    end else if (now_region[93] && mark[93] != 16) begin
        snkreg_addr <= fish_addr[mark[93]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[93]+1;
    end else if (now_region[94] && mark[94] != 16) begin
        snkreg_addr <= fish_addr[mark[94]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[94]+1;
    end else if (now_region[95] && mark[95] != 16) begin
        snkreg_addr <= fish_addr[mark[95]] + ((pixel_y >> 1) - Vertical_pos[7]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[95]+1;
    end else if (now_region[96] && mark[96] != 16) begin
        snkreg_addr <= fish_addr[mark[96]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[96]+1;
    end else if (now_region[97] && mark[97] != 16) begin
        snkreg_addr <= fish_addr[mark[97]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[97]+1;
    end else if (now_region[98] && mark[98] != 16) begin
        snkreg_addr <= fish_addr[mark[98]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[98]+1;
    end else if (now_region[99] && mark[99] != 16) begin
        snkreg_addr <= fish_addr[mark[99]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[99]+1;
    end else if (now_region[100] && mark[100] != 16) begin
        snkreg_addr <= fish_addr[mark[100]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[100]+1;
    end else if (now_region[101] && mark[101] != 16) begin
        snkreg_addr <= fish_addr[mark[101]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[101]+1;
    end else if (now_region[102] && mark[102] != 16) begin
        snkreg_addr <= fish_addr[mark[102]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[102]+1;
    end else if (now_region[103] && mark[103] != 16) begin
        snkreg_addr <= fish_addr[mark[103]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[103]+1;
    end else if (now_region[104] && mark[104] != 16) begin
        snkreg_addr <= fish_addr[mark[104]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[104]+1;
    end else if (now_region[105] && mark[105] != 16) begin
        snkreg_addr <= fish_addr[mark[105]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[105]+1;
    end else if (now_region[106] && mark[106] != 16) begin
        snkreg_addr <= fish_addr[mark[106]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[106]+1;
    end else if (now_region[107] && mark[107] != 16) begin
        snkreg_addr <= fish_addr[mark[107]] + ((pixel_y >> 1) - Vertical_pos[8]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[107]+1;
    end else if (now_region[108] && mark[108] != 16) begin
        snkreg_addr <= fish_addr[mark[108]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[0]) >> 1);
        disp <= mark[108]+1;
    end else if (now_region[109] && mark[109] != 16) begin
        snkreg_addr <= fish_addr[mark[109]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[1]) >> 1);
        disp <= mark[109]+1;
    end else if (now_region[110] && mark[110] != 16) begin
        snkreg_addr <= fish_addr[mark[110]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[2]) >> 1);
        disp <= mark[110]+1;
    end else if (now_region[111] && mark[111] != 16) begin
        snkreg_addr <= fish_addr[mark[111]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[3]) >> 1);
        disp <= mark[111]+1;
    end else if (now_region[112] && mark[112] != 16) begin
        snkreg_addr <= fish_addr[mark[112]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[4]) >> 1);
        disp <= mark[112]+1;
    end else if (now_region[113] && mark[113] != 16) begin
        snkreg_addr <= fish_addr[mark[113]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[5]) >> 1);
        disp <= mark[113]+1;
    end else if (now_region[114] && mark[114] != 16) begin
        snkreg_addr <= fish_addr[mark[114]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[6]) >> 1);
        disp <= mark[114]+1;
    end else if (now_region[115] && mark[115] != 16) begin
        snkreg_addr <= fish_addr[mark[115]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[7]) >> 1);
        disp <= mark[115]+1;
    end else if (now_region[116] && mark[116] != 16) begin
        snkreg_addr <= fish_addr[mark[116]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[8]) >> 1);
        disp <= mark[116]+1;
    end else if (now_region[117] && mark[117] != 16) begin
        snkreg_addr <= fish_addr[mark[117]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[9]) >> 1);
        disp <= mark[117]+1;
    end else if (now_region[118] && mark[118] != 16) begin
        snkreg_addr <= fish_addr[mark[118]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[10]) >> 1);
        disp <= mark[118]+1;
    end else if (now_region[119] && mark[119] != 16) begin
        snkreg_addr <= fish_addr[mark[119]] + ((pixel_y >> 1) - Vertical_pos[9]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[11]) >> 1);
        disp <= mark[119]+1;
    end else if (state == 7 && gameover_region) begin
        disp <= 0;
        snkreg_addr <= gameover_addr + ((pixel_y >> 1) - GAMEOVER_VPOS) * GAMEOVER_W + ((pixel_x + (GAMEOVER_W * 2 - 1) - GAMEOVER_HPOS) >> 1);
    end else if (number_region1) begin
        disp <= 0;
        if (sc >= 50)
            snkreg_addr <= number_addr[5] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
        else if (sc >= 40)
            snkreg_addr <= number_addr[4] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
        else if (sc >= 30)
            snkreg_addr <= number_addr[3] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
        else if (sc >= 20)
            snkreg_addr <= number_addr[2] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
        else if (sc >= 10)
            snkreg_addr <= number_addr[1] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
        else
            snkreg_addr <= number_addr[0] + ((pixel_y >> 1) - NUMBER1_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER1_HPOS) >> 1);
    end else if (number_region2) begin
        disp <= 0;
        if (sc % 10 == 0) 
            snkreg_addr <= number_addr[0] + ((pixel_y >> 1) - NUMBER2_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER2_HPOS) >> 1);
        else
            snkreg_addr <= number_addr[sc % 10] + ((pixel_y >> 1) - NUMBER2_VPOS) * NUMBER_W + ((pixel_x + (NUMBER_W * 2 - 1) - NUMBER2_HPOS) >> 1);
    end else 
        disp <= 0;
   
        pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);   
        sc <= score;
    
  end
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------ 
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else begin
    if (state == 6 && (stop_region1 || stop_region2)) rgb_next = 12'h000;
    else if (now_region && data_snk_o != 12'h0f0 && disp > 0 && disp < 15 && hurt == 1) begin  
        rgb_next = {data_snk_o[7:4], 8'b0};
    end else if (now_region && data_snk_o != 12'h0f0 && disp) rgb_next = data_snk_o;
    else if (state == 7 && gameover_region && data_snk_o != 12'h0f0) rgb_next = data_snk_o;
    else if ((number_region1 || number_region2) && data_snk_o != 12'h0f0) rgb_next = data_snk_o;
            // else if (mode == 3 && data_out == 12'had8) rgb_next = 12'hC30; // dark_green to red
            // else if (mode == 3 && data_out == 12'hceb) rgb_next = 12'he78; 
            // else if (mode == 3 && data_out == 12'hefd) rgb_next = 12'hebd;
            // else if (mode == 2 && data_out == 12'had8) rgb_next = 12'h26f;
            // else if (mode == 2 && data_out == 12'hceb) rgb_next = 12'h46f;  
            // else if (mode == 2 && data_out == 12'hefd) rgb_next = 12'hfbf;
    else rgb_next = data_out;
        
  end
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
