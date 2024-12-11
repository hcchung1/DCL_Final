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
    input vaild_sig,

    output snake_length,
    output snake_dead,
    output apple_eat,
    output new_position;
    );
    // boundary indexs
    localparam b_wide = 12, b_tall = 10;

    // fsm state
    localparam S_init = 0, S_len = 1, S_dead = 2, S_apl = 3, S_pos = 4;
    reg [2:0] state = 0, state_next = 0;

    // S_init index
    reg initialized;

    // S_len indexs
    reg apl_num = 0;
    reg wall_num = 0;
    reg [$clog(50):0] snk_len = 0;

    // S_dead indexs
    reg [7:0] next_pos = 0;
    reg isdead = 0;
    reg dead_check = 0;

    // S_apl indexs
    reg apl_eat = 0;
    reg [7:0] apl_eaten_pos = 0;
    reg apl_check = 0;

    // S_pos indexs
    reg [399:0] new_snkpos = 0;
    reg pos_check = 0;

    integer  i;

    assign snake_length = snk_len;
    assign snake_dead = is_dead;
    assign apple_eat = apl_eat;
    assign new_position = new_snkpos;

    ///////////////////////////////////////////////////////////////////////////////
    // state fsm begin
    always @(posedge clk) begin 
        if (~reset_n)
            state <= S_init;    
        else
            state <= state_next;
    end

    always @(*) begin 
        case(state) 
            S_init: if (initialized == 1) state_next = S_len;
                    else state_next = S_init;

            S_len:  if (len_check == 1) state_next = S_dead;
                    else state_next = S_len;

            S_dead: if (dead_check == 1 && isdead == 1) state_next = S_pos;
                    else if (dead_check == 1 && isdead == 0) state_next = S_apl;
                    else state_next = S_dead;

            S_apl:  if (apl_check == 1) state_next = S_pos;
                    else state_next = S_apl;

            S_pos:  if (pos_check == 1) state_next = S_init;
                    else state_next = S_pos
        endcase
    end
    //end
    ///////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////
    // collision check begin
    always @(posedge clk) begin

        if (~reset_n) begin 
            // S_len initialize
            apl_num  = 0;
            wall_num = 0; 
            snk_len  = 0;

            // S_dead initialize
            next_pos   = 0;
            isdead     = 0;
            dead_check = 0;

            // S_apl initialize
            apl_eat       = 0;
            apl_eaten_pos = 0;
            apl_check     = 0;

            // S_pos initialize
            new_snkpos = 0;
            pos_check  = 0;
        end else begin
            
            ///////////////////////////////////////////////////////////////////
            // refresh all indexs begin
            if (state == S_init) begin
                // S_len initialize
                apl_num  = 0;
                wall_num = 0; 
                snk_len  = 0;

                // S_dead initialize
                next_pos   = 0;
                isdead     = 0;
                dead_check = 0;

                // S_apl initialize
                apl_eat       = 0;
                apl_eaten_pos = 0;
                apl_check     = 0;

                // S_pos initialize
                new_snkpos = 0;
                pos_check  = 0;

                if (vaild_sig) 
                    initialized = 1;
            end
            // end
            /////////////////////////////////////////////////////////////////////

            /////////////////////////////////////////////////////////////////////
            // check the length of snake begin
            if (state == S_len) begin

                // calulate len snake
                for (i = 50; i > 0; i = i - 1) begin
                    if (snk_pos[(i * 8 - 1) -:8] != 0)
                        snk_len <= snk_len + 1; 
                    else i <= 50;
                end     

                // calculate num wall
                for (i = 3; i > 0; i = i - 1) begin
                    if (apl_pos[(i * 8 - 1) -:8] != 0)
                        apl_num <= apl_num + 1; 
                    else i <= 3;
                end 

                // calculate num apple
                for (i = 5; i > 0; i = i - 1) begin
                    if (wall_pos[(i * 8 - 1) -:8] != 0)
                        wall_num <= wall_num + 1; 
                    else i <= 5;
                end    

                len_check = 1;
            end    
            //end 
            //////////////////////////////////////////////////////////////////////

            //////////////////////////////////////////////////////////////////////
            // check if snake is dead begin*
            if (state == S_dead) begin

                //////////////////////////////////////////////////
                // if the snake hit itself begin
                for (i = 49; i > 50 - snk_len; i = i - 1) begin 

                    // if diraction is top
                    // snk_pos[399:392] is the position of snake
                    if (dir_sig[3]) begin 
                        if (snk_pos[399:392] - 12 == snk_pos[(i * 8 - 1) -:8]) begin 
                            next_pos <= snk_pos[399:392] - 12;
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end

                    // if diraction is down
                    if (dir_sig[2]) begin 
                        if (snk_pos[399:392] + 12 == snk_pos[(i * 8 - 1) -:8]) begin 
                            next_pos <= snk_pos[399:392] + 12;
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end

                    // if diraction is left
                    if (dir_sig[1]) begin 
                        if (snk_pos[399:392] - 1  == snk_pos[(i * 8 - 1) -:8]) begin 
                            next_pos <= snk_pos[399:392] - 1;
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end

                    // if diraction is right
                    if (dir_sig[0]) begin 
                        if (snk_pos[399:392] + 1  == snk_pos[(i * 8 - 1) -:8]) begin 
                            next_pos <= snk_pos[399:392] + 1;
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end

                end
                // end
                //////////////////////////////////////////////////

                //////////////////////////////////////////////////
                // if the snake hit the boundary begin
                // if diraction is top
                if (dir_sig[3]) begin 
                    if(snk_pos[399:392] - 12 < 0) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is down
                if (dir_sig[2]) begin 
                    if(snk_pos[399:392] + 12 > b_tall) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is left
                if (dir_sig[1]) begin 
                    if (snk_pos[399:392] % 12 == 0) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end

                // if diraction is right
                if (dir_sig[0]) begin 
                    if (snk_pos[399:392] % 12 == 1) begin 
                        isdead <= 1;
                        i <= snk_len;
                    end
                end
                //end
                /////////////////////////////////////////////////// 

                ///////////////////////////////////////////////////
                // if the snake hit the wall begin
                // if diraction is top
                if (dir_sig[3]) begin 
                    for (i = 5; i > 5 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == wall_pos[(i * 8 - 1) -:8]) begin 
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end                
                end

                // if diraction is down
                if (dir_sig[2]) begin 
                    for (i = 5; i > 5 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == wall_pos[(i * 8 - 1) -:8]) begin 
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end  
                end

                // if diraction is left
                if (dir_sig[1]) begin 
                    for (i = 5; i > 5 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == wall_pos[(i * 8 - 1) -:8]) begin 
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end  
                end

                // if diraction is right
                if (dir_sig[0]) begin 
                    for (i = 5; i > 5 - wall_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 1 == wall_pos[(i * 8 - 1) -:8]) begin 
                            isdead <= 1;
                            i <= snk_len;
                        end
                    end  
                end
                //end 
                ///////////////////////////////////////////////////

                // change fsm if dead goto end else goto apl check
                dead_check = 1;
            end
            // end*
            /////////////////////////////////////////////////////////////////////

            /////////////////////////////////////////////////////////////////////
            // check if apl be eaten 
            if (state == S_apl) begin

                // if diraction is top 
                if (dir_sig[3]) begin 
                    for (i = 3; i < 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 12 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 1;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                            i = 3;
                        end
                    end
                end

                // if diraction is down
                if (dir_sig[2]) begin 
                    for (i = 3; i < 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 12 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 1;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                            i = 3;
                        end
                    end
                end

                // if diraction is left
                if (dir_sig[1]) begin 
                    for (i = 3; i < 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] - 1 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 1;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                            i = 3;
                        end
                    end
                end

                // if diraction is right
                if (dir_sig[0]) begin 
                    for (i = 3; i < 3 - apl_num; i = i - 1) begin 
                        if (snk_pos[399:392] + 1 == apl_pos[(i * 8 - 1) -:8]) begin 
                            apl_eat <= 1;
                            apl_eaten_pos <= apl_pos[(i * 8 - 1) -:8];
                            i = 3;
                        end
                    end
                end

                apl_check = 1;

            end
            //end
            /////////////////////////////////////////////////////////////////////

            /////////////////////////////////////////////////////////////////////
            // check the next position of the snake begin
            if (state == S_pos) begin 
                if (!is_dead) begin 
                    if(apl_eat == 1)
                        new_snkpos <= {apl_eaten_pos, snk_pos[399:8]};
                    else
                        new_snkpos <= {next_pos, snk_pos[399:399 - (snk_len - 1) * 8]}; 
                end  

                initialized <= 0;
                pos_check = 1;
            end
            //end
            /////////////////////////////////////////////////////////////////////
        end
    end
    ///////////////////////////////////////////////////////////////////////////////

endmodule
