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

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H+FISH_W*FISH_H*16))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_sw[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
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
assign pos = fish_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
always @(posedge clk) begin
  if (~reset_n || fish_clock[31:21] > VBUF_W + FISH_W)
    fish_clock <= 0;
  else
    fish_clock <= fish_clock + 1;
end
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
reg [7:0] now;
reg [3:0] Vertical_pos[0:63], Horizontal_pos[0:63];
reg now_region[0:63];

// assign now_region =
//            pixel_y >= (Vertical_pos<<1) && pixel_y < (Vertical_pos+FISH_H)<<1 &&
//            (pixel_x + FISH_W*2 - 1) >= pos && pixel_x < pos + 1;

integer idx;
integer i;
always @(*) begin
    now_region[0] = 0;
    for (i = 1; i < 64; i = i + 1) begin
        now_region[i] = pixel_y >= (Vertical_pos[i]<<1) && pixel_y < (Vertical_pos[i]+FISH_H)<<1 &&
                (pixel_x + FISH_W*2 - 1) >= Horizontal_pos[i] && pixel_x < Horizontal_pos[i] + 1;
    end
end

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
        for (idx = 0; idx < 64; idx = idx + 1) begin
            Vertical_pos[idx] <= 0;
            Horizontal_pos[idx] <= 0;
            now_region[idx] <= 0;
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
    end else if (state == 2 && is_finished == 0) begin
        index <= index + 1;
        if (index <= 50) begin
            now <= snake[399:392];
            snake <= snake << 8;
        end else if (index <= 53) begin
            now <= apple[23:16];
            apple <= apple << 8;
        end else if (index <= 63) begin
            now <= wall_pos[79:72];
            wall <= wall << 8;
        end else if (index == 64) begin
            is_finished <= 1;
        end

        if (now == 0) begin
            if (index != 0 && length != 0) length <= index - 1; 
        end else if (now <= 12) begin
            Vertical_pos[index] <= 0;
            Horizontal_pos[index] <= now;
        end else if (now <= 24) begin
            Vertical_pos[index] <= 1;
            Horizontal_pos[index] <= now - 12;
        end else if (now <= 36) begin
            Vertical_pos[index] <= 2;
            Horizontal_pos[index] <= now - 24;
        end else if (now <= 48) begin
            Vertical_pos[index] <= 3;
            Horizontal_pos[index] <= now - 36;
        end else if (now <= 60) begin
            Vertical_pos[index] <= 4;
            Horizontal_pos[index] <= now - 48;
        end else if (now <= 72) begin
            Vertical_pos[index] <= 5;
            Horizontal_pos[index] <= now - 60;
        end else if (now <= 84) begin
            Vertical_pos[index] <= 6;
            Horizontal_pos[index] <= now - 72;
        end else if (now <= 96) begin
            Vertical_pos[index] <= 7;
            Horizontal_pos[index] <= now - 84;
        end else if (now <= 108) begin
            Vertical_pos[index] <= 8;
            Horizontal_pos[index] <= now - 96;
        end else if (now <= 120) begin
            Vertical_pos[index] <= 9;
            Horizontal_pos[index] <= now - 108;
        end



    end else if (state == 3) begin
        is_finished <= 0;
        first_input <= 0;
        
    end

end


always @ (posedge clk) begin
  if (~reset_n)
    pixel_addr <= 0;
//   else if (fish_region)
//     pixel_addr <= fish_addr[fish_clock[23]] +
//                   ((pixel_y>>1)-FISH_VPOS)*FISH_W +
//                   ((pixel_x +(FISH_W*2-1)-pos)>>1);
  else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    for (idx = 0; idx < 64; idx = idx + 1) begin
        if (now_region[idx]) begin
            if (idx >= 51 && idx <= 53)
                pixel_addr <= fish_addr[14] +
                    ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                    ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
            else if (idx >= 54 && idx <= 63)
                pixel_addr <= fish_addr[15] +
                    ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                    ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
            else if (idx == 1) // head
                if (Horizontal_pos[idx] == Horizontal_pos[idx+1] + 1) // toward right
                    pixel_addr <= fish_addr[0] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Horizontal_pos[idx] == Horizontal_pos[idx+1] - 1) // toward left
                    pixel_addr <= fish_addr[1] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Vertical_pos[idx] == Vertical_pos[idx+1] + 1) // toward up
                    pixel_addr <= fish_addr[2] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Vertical_pos[idx] == Vertical_pos[idx+1] - 1) // toward down
                    pixel_addr <= fish_addr[3] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
            else if (idx == length) // tail
                if (Horizontal_pos[idx] == Horizontal_pos[idx-1] + 1) // toward right
                    pixel_addr <= fish_addr[6] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Horizontal_pos[idx] == Horizontal_pos[idx-1] - 1) // toward left
                    pixel_addr <= fish_addr[7] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Vertical_pos[idx] == Vertical_pos[idx-1] + 1) // toward up
                    pixel_addr <= fish_addr[8] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if (Vertical_pos[idx] == Vertical_pos[idx-1] - 1) // toward down
                    pixel_addr <= fish_addr[9] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
            else // body
                if ((Horizontal_pos[idx] == Horizontal_pos[idx-1] + 1 && Horizontal_pos[idx] == Horizontal_pos[idx+1] - 1) || (Horizontal_pos[idx] == Horizontal_pos[idx+1] + 1 && Horizontal_pos[idx] == Horizontal_pos[idx-1] - 1)) // left-right
                    pixel_addr <= fish_addr[4] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if ((Vertical_pos[idx] == Vertical_pos[idx-1] + 1 && Vertical_pos[idx] == Vertical_pos[idx+1] - 1) || (Vertical_pos[idx] == Vertical_pos[idx+1] + 1 && Vertical_pos[idx] == Vertical_pos[idx-1] - 1)) // up-down
                    pixel_addr <= fish_addr[5] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if ((Horizontal_pos[idx] == Horizontal_pos[idx-1] + 1 && Vertical_pos[idx] == Vertical_pos[idx+1] - 1) || (Horizontal_pos[idx] == Horizontal_pos[idx+1] + 1 && Vertical_pos[idx] == Vertical_pos[idx-1] - 1)) // right-up / down-left
                    pixel_addr <= fish_addr[10] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if ((Horizontal_pos[idx] == Horizontal_pos[idx-1] - 1 && Vertical_pos[idx] == Vertical_pos[idx+1] + 1) || (Horizontal_pos[idx] == Horizontal_pos[idx+1] - 1 && Vertical_pos[idx] == Vertical_pos[idx-1] + 1)) // right-down / up-left
                    pixel_addr <= fish_addr[11] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if ((Horizontal_pos[idx] == Horizontal_pos[idx-1] - 1 && Vertical_pos[idx] == Vertical_pos[idx+1] - 1) || (Horizontal_pos[idx] == Horizontal_pos[idx+1] - 1 && Vertical_pos[idx] == Vertical_pos[idx-1] - 1)) // left-down / up-right
                    pixel_addr <= fish_addr[12] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                else if ((Horizontal_pos[idx] == Horizontal_pos[idx-1] + 1 && Vertical_pos[idx] == Vertical_pos[idx+1] + 1) || (Horizontal_pos[idx] == Horizontal_pos[idx+1] + 1 && Vertical_pos[idx] == Vertical_pos[idx-1] + 1)) // left-up / down-right
                    pixel_addr <= fish_addr[13] +
                        ((pixel_y>>1)-Vertical_pos[idx])*FISH_W +
                        ((pixel_x +(FISH_W*2-1)-Horizontal_pos[idx])>>1);
                
        end else pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
    end
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
  else
    rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
