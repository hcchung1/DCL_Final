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
    input [1:0] mode,

    output snake_dead,
    output [2:0] apple_eat, // 0 是沒有 1是第一個被吃 etc.
    output [399:0] new_position,
    output [7:0] check_done,
    output [3:0] wall_collision,
    output [5:0] score,
    output [5:0] highest_score
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
    reg [399:0] stone_snk;
    reg [2:0] apl_num = 0;
    reg [3:0] wall_num = 0;
    reg [5:0] snk_len = 0; 
    reg len_check = 0;  
    reg [5:0] count = 50;  
    reg [5:0] apl_score = 0;
    reg [5:0] high_score = 0;

    // S_dead indexs
    reg [399:0] zero;
    reg [7:0] next_pos = 0;
    reg is_dead = 0;
    reg dead_check = 0;
    reg have_dir = 0;
    reg [3:0] wall_colsn;
    reg mod_0_hit;
    reg [7:0] nb_next;

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

    assign score = apl_score;
    assign highest_score = high_score;
    assign snake_dead = is_dead;
    assign apple_eat = apl_eat;
    assign new_position = new_snkpos;
    assign check_done = score;
    assign wall_collision = wall_colsn;

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
            apl_num    <= 0;
            wall_num   <= 0; 
            snk_len    <= 0;
            len_check  <= 0;
            apl_score  <= 0;
            high_score <= 0;

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

                if (apl_score >= high_score) begin
                    high_score <= apl_score;
                end

                // S_pre initialize
                apl_num   <= 0;
                wall_num  <= 0;
                len_check <= 0;
                count     <= 50;

                // S_dead initialize
                next_pos <= snk_pos[399:392];
                dead_check <= 0;

                // S_apl initialize                
                apl_eaten_pos <= 0;
                apl_check     <= 0;

                // S_pos initialize
                new_snkpos  <= snk_pos;
                pos_check   <= 0;

                // end_game initialize
                edgm_check <= 0;
                
                if (state == 4) begin
                    initialized <= 1;
                    snk_len   <= 0;
                end
            end
            // end of refresh          
        
            // prepare the indexs needed begin
            if (s_check == S_pre) begin

                is_dead     <= 0;
                apl_eat     <= 0;
                wall_colsn  <= 0;
                ori_snk     <= snk_pos;
                stone_snk   <= snk_pos;
                mod_0_hit   <= 0;
                nb_next     <= 0;

                // calulate len snake
                if (count != 0) begin
                    if (snk_pos[(count * 8 - 1) -:8] != 0)
                        snk_len <= snk_len + 1;
                    
                    if (count <= 10 && (wall_pos[(count * 8 - 1) -:8] != 0)) begin
                        wall_num <= wall_num + 1;
                    end

                    if (count <= 3 && (apl_pos[(count * 8 - 1) -:8] != 0)) begin 
                        apl_num <= apl_num + 1;
                    end

                    count <= count - 1;
                end     

                if (count == 0) len_check <= 1;
            end    
            //end of prepare          
            
            // check if snake is dead begin
            if (s_check == S_dead) begin

                // calculate the tail position
                ori_snk[399 - (snk_len - 1) * 8 -:8] <= 0;
                if(snk_len >= 5) begin
                    stone_snk[399 - (snk_len - 1) * 8 -:8] <= 0;
                    stone_snk[399 - (snk_len - 2) * 8 -:8] <= 0;
                end
                // end of tail 
                // if the snake hit itself begin

                if (dir_sig[3] == 1) begin
                    for (i = 49; i > 0; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] - 12 == snk_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 12) != 0 && snk_pos[399:392] - 12 != snk_pos[((51-snk_len)*8)-1 -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (mode != 0) begin
                        if(snk_pos[399:392] == 1 || snk_pos[399:392] == 2 || snk_pos[399:392] == 3 || snk_pos[399:392] == 4 || snk_pos[399:392] == 5 || snk_pos[399:392] == 6 || snk_pos[399:392] == 7 || snk_pos[399:392] == 8 || snk_pos[399:392] == 9 || snk_pos[399:392] == 10 || snk_pos[399:392] == 11 || snk_pos[399:392] == 12) begin 
                            is_dead <= 1;
                        end
                    end else begin
                        if (snk_pos[399:392] == 1 || snk_pos[399:392] == 2 || snk_pos[399:392] == 3 || snk_pos[399:392] == 4 || snk_pos[399:392] == 5 || snk_pos[399:392] == 6 || snk_pos[399:392] == 7 || snk_pos[399:392] == 8 || snk_pos[399:392] == 9 || snk_pos[399:392] == 10 || snk_pos[399:392] == 11 || snk_pos[399:392] == 12) begin
                            nb_next <= snk_pos[399:392] + 108;
                            for (i = 10; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] + 108) == wall_pos[(i * 8 - 1) -:8]) begin 
                                    if(snk_len >= 5) begin
                                        wall_colsn <= 11 - i;                                        
                                    end else begin
                                        is_dead <= 1;
                                    end    
                                end
                            end

                            for (i = 3; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] + 108) == apl_pos[(i * 8 - 1) -:8]) begin 
                                    apl_eat <= 4 - i;    
                                end
                            end

                            mod_0_hit <= 1;
                        end
                    end

                    for (i = 10; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == wall_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 12) != 0) begin 
                            if(snk_len >= 5) begin
                                wall_colsn <= 11 - i;                                
                            end else begin
                                is_dead <= 1;
                            end    
                        end
                    end   

                    next_pos <= snk_pos[399:392] - 12;
                    have_dir <= 1;
                end

                else if (dir_sig[2] == 1) begin
                    for (i = 49; i > 0; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] + 12 == snk_pos[(i * 8 - 1) -:8] && snk_pos[399:392] + 12 != snk_pos[((51-snk_len)*8)-1 -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (mode != 0) begin
                        if(snk_pos[399:392] + 12 > b_tall) begin 
                            is_dead <= 1;
                        end
                    end else begin 
                        if(snk_pos[399:392] + 12 > b_tall) begin
                            nb_next <= snk_pos[399:392] - 108;
                            for (i = 10; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] - 108) == wall_pos[(i * 8 - 1) -:8]) begin 
                                    if(snk_len >= 5) begin
                                        wall_colsn <= 11 - i;                                        
                                    end else begin
                                        is_dead <= 1;
                                    end        
                                end
                            end

                            for (i = 3; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] - 108) == apl_pos[(i * 8 - 1) -:8]) begin 
                                    apl_eat <= 4 - i;    
                                end
                            end

                            mod_0_hit <= 1;
                        end
                    end

                    for (i = 10; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == wall_pos[(i * 8 - 1) -:8]) begin 
                            if(snk_len >= 5) begin
                                wall_colsn <= 11 - i;                                
                            end else begin
                                is_dead <= 1;
                            end    
                        end
                    end   

                    next_pos <= snk_pos[399:392] + 12;
                    have_dir <= 1;
                end

                else if (dir_sig[1] == 1) begin
                    for (i = 49; i > 0; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] - 1 == snk_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 1) != 0 && snk_pos[399:392] - 1 != snk_pos[((51-snk_len)*8)-1 -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (mode != 0) begin
                        if(snk_pos[399:392]  == 1 || snk_pos[399:392]  == 13 || snk_pos[399:392]  == 25 || snk_pos[399:392]  == 37 || snk_pos[399:392]  == 49 || snk_pos[399:392]  == 61 || snk_pos[399:392]  == 73 || snk_pos[399:392]  == 85 || snk_pos[399:392]  == 97 || snk_pos[399:392]  == 109) begin 
                            is_dead <= 1;
                        end
                    end else begin 
                        if(snk_pos[399:392]  == 1 || snk_pos[399:392]  == 13 || snk_pos[399:392]  == 25 || snk_pos[399:392]  == 37 || snk_pos[399:392]  == 49 || snk_pos[399:392]  == 61 || snk_pos[399:392]  == 73 || snk_pos[399:392]  == 85 || snk_pos[399:392]  == 97 || snk_pos[399:392]  == 109) begin
                            nb_next <= snk_pos[399:392] + 11;
                            for (i = 10; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] + 11) == wall_pos[(i * 8 - 1) -:8]) begin 
                                    if(snk_len >= 5) begin
                                        wall_colsn <= 11 - i;                                        
                                    end else begin
                                        is_dead <= 1;
                                    end    
                                end
                            end

                            for (i = 3; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] + 11) == apl_pos[(i * 8 - 1) -:8]) begin 
                                    apl_eat <= 4 - i;    
                                end
                            end

                            mod_0_hit <= 1;
                        end
                    end

                    for (i = 10; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == wall_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 1) != 0) begin 
                            if(snk_len >= 5) begin
                                wall_colsn <= 11 - i;                                
                            end else begin
                                is_dead <= 1;
                            end    
                        end
                    end   

                    next_pos <= snk_pos[399:392] - 1;
                    have_dir <= 1;
                end

                else if (dir_sig[0] == 1) begin
                    for (i = 49; i > 0; i = i - 1) begin 
                        // snk_pos[399:392] is the position of snake
                        if (snk_pos[399:392] + 1 == snk_pos[(i * 8 - 1) -:8] && snk_pos[399:392] + 1 != snk_pos[((51-snk_len)*8)-1 -:8]) begin 
                            is_dead <= 1;
                        end
                    end

                    if (mode != 0) begin
                        if(snk_pos[399:392]  == 12 || snk_pos[399:392]  == 24 || snk_pos[399:392]  == 36 || snk_pos[399:392]  == 48 || snk_pos[399:392]  == 60 || snk_pos[399:392]  == 72 || snk_pos[399:392]  == 84 || snk_pos[399:392]  == 96 || snk_pos[399:392]  == 108 || snk_pos[399:392]  == 120) begin 
                            is_dead <= 1;
                        end
                    end else begin 
                        if(snk_pos[399:392]  == 12 || snk_pos[399:392]  == 24 || snk_pos[399:392]  == 36 || snk_pos[399:392]  == 48 || snk_pos[399:392]  == 60 || snk_pos[399:392]  == 72 || snk_pos[399:392]  == 84 || snk_pos[399:392]  == 96 || snk_pos[399:392]  == 108 || snk_pos[399:392]  == 120) begin
                            nb_next <= snk_pos[399:392] - 11;
                            for (i = 10; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] - 11) == wall_pos[(i * 8 - 1) -:8]) begin 
                                    if(snk_len >= 5) begin
                                        wall_colsn <= 11 - i;                                        
                                    end else begin
                                        is_dead <= 1;
                                    end    
                                end
                            end

                            for (i = 3; i > 0; i = i - 1) begin
                                if ((snk_pos[399:392] - 11) == apl_pos[(i * 8 - 1) -:8]) begin 
                                    apl_eat <= 4 - i;    
                                end
                            end

                            mod_0_hit <= 1;
                        end
                    end

                    for (i = 10; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] + 1 == wall_pos[(i * 8 - 1) -:8]) begin 
                            if(snk_len >= 5) begin
                                wall_colsn <= 11 - i;                                
                            end else begin
                                is_dead <= 1;
                            end
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
                    for (i = 3; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == apl_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 12) != 0) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[2] == 1) begin
                    for (i = 3; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[1] == 1) begin
                    for (i = 3; i > 0; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == apl_pos[(i * 8 - 1) -:8] && (snk_pos[399:392] - 1) != 0) begin 
                            apl_eat <= 4 - i;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                        end
                    end          
                end

                else if (dir_sig[0] == 1) begin
                    for (i = 3; i > 0; i = i - 1) begin 
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
                    if(apl_eat != 0) begin
                        new_snkpos <= {apl_eaten_pos, snk_pos[399:8]};
                        apl_score <= snk_len - 4; 
                    end else if (wall_colsn != 0)begin
                        new_snkpos <= {next_pos, stone_snk[399:8]};
                        apl_score <= snk_len - 5;
                    end else if(mod_0_hit == 1) begin
                        new_snkpos <= {nb_next, ori_snk[399:8]};
                    end else begin 
                        new_snkpos <= {next_pos, ori_snk[399:8]};
                    end                                                    
                end else begin 
                    initialized <= 0; 
                    pos_check <= 1;
                end
            end

            if (s_check == S_endgame) begin
                new_snkpos <= 400'b0;   
                if (state == 0) begin
                    edgm_check <= 1;
                end
            end
            //end of position check                          
        end
    end
    ///////////////////////////////////////////////////////////////////////////////

endmodule
