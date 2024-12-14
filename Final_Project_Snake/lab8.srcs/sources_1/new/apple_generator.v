module apple_generator (
    input wire clk,               // 時脈訊號
    input wire reset,             // 重置訊號
    input wire [2:0] state,
    input wire ready,
    input wire [4:0] main_apple_count,
    input wire [7:0] apple_eat_pos,         // 蘋果是否被吃掉
    input wire [399:0] snake_pos,  // 蛇的位置，每個節點 [7:0]
    input wire [79:0] obstacle_pos, // 障礙物的位置，每個障礙物 [7:0]
    output reg [23:0] apple_pos,   // 蘋果的位置，每個蘋果 [7:0]
    output reg [4:0] apple_count
);

    reg [7:0] temp_pos;           // 暫時儲存生成的蘋果位置
    // reg [4:0] apple_count;        // 已成功生成的蘋果數量
    reg [15:0] lfsr;              // 用於隨機數生成的 LFSR
    reg [4:0] pre_apple_count;
    reg first_time;


    always @(posedge clk) begin
        if (~reset) begin
            apple_pos <= 40'b0;   // 重置所有蘋果的位置
            apple_count <= 0;     // 重置蘋果計數
            lfsr <= 16'hACE1;     // 初始化 LFSR
            first_time <= 0;
        end else begin
          // 如果蘋果被吃掉，則生成新的蘋果
          if(state == 4)begin 
            first_time <= 0;
            apple_pos <= apple_eat_pos;
          end else if(state == 5)begin 
            pre_apple_count <= main_apple_count;
            if(~first_time)begin 
              apple_pos <= apple_eat_pos;
              first_time <= 1;
            end else if(ready) begin 
              if(pre_apple_count < 3)begin 

                // 生成隨機位置 (4 bits for X, 4 bits for Y)
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                temp_pos <= lfsr[6:0];
                
                // 檢查是否與蛇或障礙物重疊
                if(temp_pos <= 120 && temp_pos > 0)begin 
                  if (!is_overlap(temp_pos, snake_pos) && !is_overlap(temp_pos, obstacle_pos)) begin
                    // 找到被吃掉的蘋果位置，並儲存蘋果位置
                    if(apple_pos[7:0] == 0) begin
                      apple_pos <= {temp_pos, apple_pos[15:0]};
                    end else if(apple_pos[15:8] == 0) begin
                      apple_pos <= {apple_pos[7:0], temp_pos, apple_pos[23:16]};
                    end else if(apple_pos[23:16] == 0) begin
                      apple_pos <= {apple_pos[15:0], temp_pos};
                    end
                    apple_count <= apple_count + 1;
                  end
                end
              end

            end
            
            
            
          end
          // apple_count <= apple_count - (apple_eat_pos != 0);
          // if (main_apple_count < 3) begin
          //   // 生成隨機位置 (4 bits for X, 4 bits for Y)
          //   lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
          //   temp_pos <= lfsr[6:0];
            
          //   // 檢查是否與蛇或障礙物重疊
          //   if(temp_pos <= 120 && temp_pos > 0)begin 
          //     if (!is_overlap(temp_pos, snake_pos) && !is_overlap(temp_pos, obstacle_pos)) begin
          //       // 儲存蘋果位置
          //       if(apple_pos[7:0] == 0) begin
          //         apple_pos <= {temp_pos, apple_pos[15:0]};
          //       end else if(apple_pos[15:8] == 0) begin
          //         apple_pos <= {apple_pos[7:0], temp_pos, apple_pos[23:16]};
          //       end else if(apple_pos[23:16] == 0) begin
          //         apple_pos <= {apple_pos[15:0], temp_pos};
          //       end
          //       apple_count <= apple_count + 1;
          //     end
          //   end
              
          // end
        end
    end

    // 判斷重疊的函數
    function is_overlap(
        input [7:0] pos,
        input [39:0] entity_pos
    );
        integer i;
        begin
            is_overlap = 0;
            for (i = 0; i < 5; i = i + 1) begin
                if (pos == entity_pos[i*8 +: 8]) begin
                    is_overlap = 1;
                end
            end
        end
    endfunction

endmodule