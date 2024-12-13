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

    input  [2:0] state,  // main state machine state
    input  [3:0] choice,  // 
    input  [399:0] snk_pos,
    input  [23:0] apple_pos,
    input  [79:0] wall_pos,
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
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H+FISH_W*FISH_H*16))
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
reg first_input;
reg [6:0] length;
reg [6:0] index;
reg [399:0] snake;
reg [23:0] apple;
reg [79:0] wall;
reg [503:0] now;
reg [4:0] mark[119:0];
reg [9:0] Vertical_pos[0:11], Horizontal_pos[0:11];
wire [119:0] now_region;

// assign now_region =
//            pixel_y >= (Vertical_pos<<1) && pixel_y < (Vertical_pos+FISH_H)<<1 &&
//            (pixel_x + FISH_W*2 - 1) >= pos && pixel_x < pos + 1;

genvar k, j;
generate
    for (k = 0; k < 10; k = k + 1) begin : outer_loop
        for (j = 0; j < 12; j = j + 1) begin : inner_loop
            localparam int idd = k * 12 + j;
            assign now_region[idd] = 
                (pixel_y >= (Vertical_pos[k] << 1)) && 
                (pixel_y < ((Vertical_pos[k] + FISH_H) << 1)) &&
                (pixel_x + (FISH_W * 2) - 1 >= Horizontal_pos[j]) && 
                (pixel_x < Horizontal_pos[j] + 1);
        end
    end
endgenerate



integer idx;
integer i;
reg [1:0] change;

always @(posedge clk) begin
    if (~reset_n) begin
        index <= 0;
        is_finished <= 0;
        first_input <= 0;
        snake <= 0;
        apple <= 0;
        wall <= 0;
        now <= 0;
        length <= 0;
        change <= 0;
        pixel_addr <= 0;
        snkreg_addr <= 0;
        for (idx = 0; idx < 12; idx = idx + 1) begin
            Vertical_pos[idx] <= idx * 24;
            Horizontal_pos[idx] <= idx * 48;
        end
        for (i = 0; i < 120; i = i + 1) begin
            mark[i] <= 16;
        end
    end else if (state == 2 && first_input == 0) begin
        index <= 0;
        is_finished <= 0;
        first_input <= 1;
        snake <= snk_pos;
        apple <= apple_pos;
        wall <= wall_pos;
        length <= 0;
        now <= 0;
        change <= 0;
    end else if (state == 2 && is_finished == 0) begin
        if (change == 0) begin
            change <= 1;
            now <= {snake, apple, wall};
        end else if (change == 1) begin 
            snake <= snake << 8;
            if (snake[399:392] != 0) begin
                length <= length + 1;
                if (length == 0) begin
                    if (now[503:496] == now[495:488] + 1) begin // head right
                        mark[0] <= 0;
                    end else if (now[503:496] == now[495:488] - 1) begin // head left
                        mark[0] <= 1;
                    end else if (now[503:496] == now[495:488] + 24) begin // head up
                        mark[0] <= 2;
                    end else if (now[503:496] == now[495:488] - 24) begin // head down
                        mark[0] <= 3;
                    end
                end else begin
                    if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 1) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 1) ) // left-right
                        mark[length] <= 4;
                    else if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 12) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 12)) // up-down 
                        mark[length] <= 5;
                    else if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 12) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 1)) // right-up / down-left
                        mark[length] <= 10;
                    else if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 12) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 1)) // right-down / up-left
                        mark[length] <= 11;
                    else if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 12) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 1)) // left-down / up-right
                        mark[length] <= 12;
                    else if ((now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] + 1 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 12) || (now[503-(length*8) -: 8] == now[503-(length+1)*8 -: 8] - 12 && now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 1)) // left-up / down-right
                        mark[length] <= 13;
                end
            end else if (snake == 0) begin
                change <= 2;
                if (now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 1) // tail right
                    mark[length] <= 6;
                else if (now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 1) // tail left
                    mark[length] <= 7;
                else if (now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] + 24) // tail up
                    mark[length] <= 8;
                else if (now[503-(length*8) -: 8] == now[503-(length-1)*8 -: 8] - 24) // tail down
                    mark[length] <= 9;
            end
        end else if (change == 2) begin
            apple <= apple << 8;
            if (apple[23:16] != 0) begin
                mark[apple[23:16]] <= 14;
            end else if (apple == 0) begin
                change <= 3;
            end
        end else if (change == 3) begin
            wall <= wall << 8;
            if (wall[79:72] != 0) begin
                mark[wall[79:72]] <= 15;
            end else if (wall == 0) begin
                is_fininshed <= 1;
            end
        end
        
    end else if (state == 3) begin
        is_finished <= 0;
        first_input <= 0;
        change <= 0;
    end

end

assign move_end = is_finished;
integer m,n;

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
    snkreg_addr <= 0;
//   else if (fish_region)
//     pixel_addr <= fish_addr[fish_clock[23]] +
//                   ((pixel_y>>1)-FISH_VPOS)*FISH_W +
//                   ((pixel_x +(FISH_W*2-1)-pos)>>1);
  end else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    for (m = 0; m < 10; m = m + 1) begin
        for (n = 0; n < 12; n = n + 1) begin
            if (now_region[m*12+n] && mark[m*12+n] != 16) begin
                snake_addr <= fish_addr[mark[m*12+n]] + ((pixel_y >> 1) - Vertical_pos[m]) * FISH_W + ((pixel_x + (FISH_W * 2 - 1) - Horizontal_pos[n]) >> 1);
            end
        end
    end
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
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
    rgb_next = (now_region && data_snk_o != 12'h0f0) ? data_snk_o : data_out;
  end
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
