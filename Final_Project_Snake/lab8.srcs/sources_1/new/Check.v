`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/10 21:42:44
// Design Name: 
// Module Name: Check
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


module Check(
    input clk,
    input reset_n,
    input btn,
    input sw,
    input [399:0] snk_pos,  // 位置編碼 0就是結束
    input [23:0] apl_pos,  
    input [39:0] wall_pos,
    input [3:0] dir_sig,
    //
    output 

    );
    // boundary indexs
    localparam b_wide = 12, b_tall = 10;
    // fsm state
    localparam S_len = 0, S_dead = 1, S_apl = 2;
    reg state;

    // S_len indexs
    reg apl_num;
    reg wall_num;
    reg [$clog(160):0] snk_len;

    // S_dead indexs
    reg isdead = 0;
    reg can_eat = 0;
    reg cant_eat = 0;

    integer  i;

    always @(posedge clk) begin

        // check the length of snake
        if(state == S_len) begin

            // calulate len snake
            for(i = 0; i < 50; i = i + 1) begin
                if(snk_pos[((50-i)*8 - 1) -:8] != 0)
                    snk_len <= snk_len + 1; 
                else i <= 50;
            end     

            // calculate num wall
            for(i = 0; i < 3; i = i + 1) begin
                if(apl_pos[((3-i)*8 - 1) -:8] != 0)
                    apl_num <= apl_num + 1; 
                else i <= 3;
            end 

            // calculate num apple
            for(i = 0; i < 5; i = i + 1) begin
                if(wall_pos[((5-i)*8 - 1) -:8] != 0)
                    wall_num <= wall_num + 1; 
                else i <= 5;
            end    

        end       

        // check if snake is dead
        if(state == S_dead) begin

            // if the snake hit itself begin
            for(i = 1; i < snk_len; i= i + 1) begin 

                // if diraction is top
                if(dir_sig) begin 
                    if(snk_pos[0] - 12 == snk_pos[i]) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is down
                if(dir_sig) begin 
                    if(snk_pos[0] + 12 == snk_pos[i]) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is left
                if(dir_sig) begin 
                    if(snk_pos[0] - 1 == snk_pos[i]) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is right
                if(dir_sig) begin 
                    if(snk_pos[0] + 1 == snk_pos[i]) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

            end
            // end

            // if the snake hit the boundary begin
            // if diraction is top
            for(i = 1; i < snk_len; i= i + 1) begin 
                if(snk_pos[0] - 12 < 0) begin 
                    isdead <= 1;
                    i <= snk_len;
                end
            end

            // if diraction is down
            for(i = 1; i < snk_len; i= i + 1) begin 
                if(snk_pos[0] + 12 > 120) begin 
                    isdead <= 1;
                    i <= snk_len;
                end
            end

            // if diraction is left
            for(i = 1; i < snk_len; i= i + 1) begin 
                if((snk_pos[0] == 1 || snk_pos[0] == 1 || snk_pos[0] == 1 || snk_pos[0] == 1 ||
                    snk_pos[0] == 1 || snk_pos[0] == 1 || snk_pos[0] == 1 || snk_pos[0] == 1 ||
                    snk_pos[0] == 1 || snk_pos[0] == 1) && ) begin 
                    isdead <= 1;
                    i <= snk_len;
                end
            end

            // if diraction is right
            for(i = 1; i < snk_len; i= i + 1) begin 
                if(snk_pos[0] + 1 > b_wide) begin 
                    isdead <= 1;
                    i <= snk_len;
                end
            end

            // if the snake hit the wall 

            //end
            for(i = 1; i < wall_num; i= i + 1) begin 
                if(snk_pos[0] == wall_pos[i]) begin 
                    isdead <= 1;
                    i <= snk_len;
                end
            end

            // change fsm if dead goto end else goto apl check
            if(!isdead)
                can_eat <= 1;
            else 
                cant_eat <= 1;
        end

        // check if apl be eaten


    end


endmodule
