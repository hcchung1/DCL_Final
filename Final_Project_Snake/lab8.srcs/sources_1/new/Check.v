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
    input [2:0] state,
    input [399:0] snk_pos,  // 位置編碼 0就是結束
    input [23:0] apl_pos,  
    input [79:0] wall_pos,
    input [3:0] dir_sig,

    output snake_dead,
    output [2:0] apple_eat, // 0 是沒有 1是第一個被吃 etc.
    output [399:0] new_position,
    output [7:0] check_done
    );
    // boundary indexs
    localparam b_tall = 120; 

    // fsm s_check
    localparam S_init = 0, S_pre = 1, S_dead = 2, S_apl = 3, S_pos = 4, S_endgame = 5;
    reg [2:0] s_check = 0, s_check_next = 0;    

    // S_init index
    reg initialized;
    reg has_done = 0;

    // S_pre indexs
    reg [399:0] ori_snk;
    reg [2:0] apl_num = 0;
    reg [3:0] wall_num = 0;
    reg [5:0] snk_len = 0; 
    reg len_check = 0;
    

    // S_dead indexs
    reg [399:0] zero;
    reg [7:0] next_pos = 0;
    reg is_dead = 0;
    reg dead_check = 0;
    reg have_dir = 0;

    // S_apl indexs
    reg [2:0] apl_eat = 0;
    reg [7:0] apl_eaten_pos = 0;
    reg apl_check = 0;

    // S_pos indexs
    reg [399:0] new_snkpos = 0;
    reg [399:0] temp_snkpos;
    reg pos_check = 0;

    // endgame index
    reg edgm_check;

    integer  i;

    assign snake_length = snk_len;
    assign snake_dead = is_dead;
    assign apple_eat = apl_eat;
    assign new_position = new_snkpos;
    assign check_done = have_dir;

    ///////////////////////////////////////////////////////////////////////////////
    // s_check fsm begin
    always @(posedge clk) begin 
        if (~reset_n)
            s_check <= S_init;    
        else
            s_check <= s_check_next;
    end

    always @(*) begin 
        case(s_check) 
            S_init: if (initialized == 1) s_check_next = S_pre;
                    else s_check_next = S_init;

            S_pre:  if (len_check == 1) s_check_next = S_dead;
                    else s_check_next = S_pre;

            S_dead: if (dead_check == 1 && is_dead == 1) s_check_next = S_endgame;
                    else if (dead_check == 1 && is_dead == 0) s_check_next = S_apl;
                    else s_check_next = S_dead;

            S_apl:  if (apl_check == 1) s_check_next = S_pos;
                    else s_check_next = S_apl;

            S_pos:  if (pos_check == 1) s_check_next = S_init;
                    else s_check_next = S_pos;

            S_endgame: if (edgm_check == 1) s_check_next = S_init;
                    else s_check_next = S_endgame;
        endcase
    end
    //end
    ///////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////
    // collision check begin
    always @(posedge clk) begin

        if (~reset_n) begin 
            // S_pre initialize
            apl_num  <= 0;
            wall_num <= 0; 
            snk_len  <= 0;
            len_check <= 0;

            // S_dead initialize
            next_pos   <= 0;
            is_dead    <= 0;
            dead_check <= 0;

            // S_apl initialize
            apl_eat       <= 0;
            apl_eaten_pos <= 0;
            apl_check     <= 0;

            // S_pos initialize
            pos_check  <= 0;
            new_snkpos <= snk_pos;
        end else begin
      
            // refresh all indexs begin
            if (s_check == S_init) begin

                // S_pre initialize
                apl_num   <= 0;
                wall_num  <= 0; 
                snk_len   <= 0;
                len_check <= 0;

                // S_dead initialize
                next_pos <= snk_pos[399:392];
                dead_check <= 0;

                // S_apl initialize                
                apl_eaten_pos <= 0;
                apl_check     <= 0;

                // S_pos initialize
                new_snkpos  <= snk_pos;
                pos_check   <= 0;
                
                if (state == 4) begin
                    initialized <= 1;
                    is_dead     <= 0;
                    apl_eat     <= 0;
                end
            end
            // end of refresh          
        
            // prepare the indexs needed begin
            if (s_check == S_pre) begin

                ori_snk <= snk_pos;

                // calulate len snake
                for (i = 50; i > 0; i = i - 1) begin
                    if (snk_pos[(i * 8 - 1) -:8] != 0)
                        snk_len <= ((snk_len + 1) <= 50)? snk_len + 1: 50;
                end     

                // calculate num wall
                for (i = 3; i > 0; i = i - 1) begin
                    if (apl_pos[(i * 8 - 1) -:8] != 0)
                        apl_num <= ((apl_num + 1) <= 3)? apl_num + 1: 3;
                end 

                // calculate num apple
                for (i = 10; i > 0; i = i - 1) begin
                    if (wall_pos[(i * 8 - 1) -:8] != 0)
                        wall_num <= ((wall_num + 1) <= 10)? wall_num + 1: 10;
                end    

                len_check <= 1;
            end    
            //end of prepare          
            
            // check if snake is dead begin
            if (s_check == S_dead) begin

                // calculate the tail position
                for(i = 0; i <= 399; i = i + 1) begin
                    if (i <= (399 - (snk_len - 1) * 8))
                        ori_snk[i] <= 0; 
                end
                // end of tail 
                
                // if the snake hit itself begin
                if (dir_sig[3] == 1) begin
                    for (i = 49; i > 50 - snk_len; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] - 12 == snk_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if(snk_pos[399:392] - 12 < 0) begin 
                        is_dead <= 1;
                    end

                    for (i = 10; i > 10 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == wall_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end   

                    next_pos <= snk_pos[399:392] - 12;
                    have_dir <= 1;
                end

                else if (dir_sig[2] == 1) begin
                    for (i = 49; i > 50 - snk_len; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] + 12 == snk_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if(snk_pos[399:392] + 12 > b_tall) begin 
                        is_dead <= 1;
                    end

                    for (i = 10; i > 10 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == wall_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end   

                    next_pos <= snk_pos[399:392] + 12;
                    have_dir <= 1;
                end

                else if (dir_sig[1] == 1) begin
                    for (i = 49; i > 50 - snk_len; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] - 1 == snk_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (snk_pos[399:392]  == 1 || snk_pos[399:392]  == 13 || snk_pos[399:392]  == 25 || snk_pos[399:392]  == 37 || snk_pos[399:392]  == 49 || snk_pos[399:392]  == 61 || snk_pos[399:392]  == 73 || snk_pos[399:392]  == 85 || snk_pos[399:392]  == 97 || snk_pos[399:392]  == 109) begin 
                        is_dead <= 1;
                    end

                    for (i = 10; i > 10 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == wall_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end   

                    next_pos <= snk_pos[399:392] - 1;
                    have_dir <= 1;
                end

                else if (dir_sig[0] == 1) begin
                    for (i = 49; i > 50 - snk_len; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] + 1 == snk_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (snk_pos[399:392]  == 12 || snk_pos[399:392]  == 24 || snk_pos[399:392]  == 36 || snk_pos[399:392]  == 48 || snk_pos[399:392]  == 60 || snk_pos[399:392]  == 72 || snk_pos[399:392]  == 84 || snk_pos[399:392]  == 96 || snk_pos[399:392]  == 108 || snk_pos[399:392]  == 120) begin 
                        is_dead <= 1;
                    end

                    for (i = 10; i > 10 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 1 == wall_pos[(i * 8 - 1) -:8]) begin 
                            is_dead <= 1;
                        end
                    end  

                    next_pos <= snk_pos[399:392] + 1;
                    have_dir <= 1;
                end

                dead_check <= 1;

            end
            // end of dead check
            
            // check if apple be eaten 
            if (s_check == S_apl) begin
            
                if (dir_sig[3] == 1) begin
                    for (i = 3; i > 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[2] == 1) begin
                    for (i = 3; i > 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[1] == 1) begin
                    for (i = 3; i > 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[0] == 1) begin
                    for (i = 3; i > 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 1 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                apl_check <= 1;

            end
            //end of apple check           
            
            // check the next position of the snake begin
            if (s_check == S_pos) begin 
                if (state == 4) begin                     
                    if(apl_eat != 0)
                        new_snkpos <= {apl_eaten_pos, snk_pos[399:8]};
                    else begin
                        new_snkpos <= {next_pos, ori_snk[399:8]};
                    end                                     
                end else begin 
                    initialized <= 0; 
                    pos_check <= 1;
                end
            end

            if (s_check == S_endgame) begin
               new_snkpos <= 400'b0;   
            end
            //end of position check                          
        end
    end
    ///////////////////////////////////////////////////////////////////////////////

endmodule
