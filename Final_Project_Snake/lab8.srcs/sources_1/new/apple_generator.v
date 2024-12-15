module apple_generator (
    input wire clk,               // 時脈訊號
    input wire reset,             // 重置訊號
    input wire [2:0] state,
    input wire [1:0] mode,        // 遊戲模式
    input wire [23:0] main_apple_pos, // 蘋果位置
    input wire [2:0] apple_eat_pos, // 蘋果被吃掉的位置
    input wire [399:0] snake_pos,  // 蛇的位置，每個節點 [7:0]
    input wire [79:0] obstacle_pos, // 障礙物的位置，每個障礙物 [7:0]
    input wire [3:0] obstacle_hit_pos, // 障礙物被撞到的位置
    output reg [23:0] apple_pos,   // 蘋果的位置，每個蘋果 [7:0]
    output reg [79:0] obstacle_new_pos // 新的障礙物位置
);

reg [7:0] temp_pos;           // 暫時儲存生成的蘋果位置
reg [15:0] lfsr;              // 用於隨機數生成的 LFSR


always @(posedge clk) begin
  if (~reset) begin
      apple_pos <= 40'b0;   // 重置所有蘋果的位置
      obstacle_new_pos <= 80'b0; // 重置所有障礙物的位置
      lfsr <= 16'hACE1;     // 初始化 LFSR
  end else begin
    // 如果蘋果被吃掉，則生成新的蘋果
    if(state == 5)begin 
        
      // 生成隨機位置 (4 bits for X, 4 bits for Y)
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      temp_pos <= lfsr[6:0];
      if(temp_pos <= 120 && temp_pos > 0)begin 
        if (!is_overlap(temp_pos, snake_pos) && !is_overlap(temp_pos, obstacle_pos) && !is_overlap(temp_pos, apple_pos)) begin
          // 找到被吃掉的蘋果位置，並儲存蘋果位置
          if(apple_eat_pos == 1)begin 
            apple_pos <= {temp_pos, apple_pos[15:8], apple_pos[7:0]};
          end else if(apple_eat_pos == 2)begin 
            apple_pos <= {apple_pos[23:16], temp_pos, apple_pos[7:0]};
          end else if(apple_eat_pos == 3)begin 
            apple_pos <= {apple_pos[23:16], apple_pos[15:8], temp_pos};
          end else if(obstacle_hit_pos == 1 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {temp_pos, obstacle_pos[71:0]};
          end else if(obstacle_hit_pos == 2 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin
            obstacle_new_pos <= {obstacle_pos[79:72], temp_pos, obstacle_pos[63:0]};
          end else if(obstacle_hit_pos == 3 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:64], temp_pos, obstacle_pos[55:0]};
          end else if(obstacle_hit_pos == 4 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:56], temp_pos, obstacle_pos[47:0]};
          end else if(obstacle_hit_pos == 5 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:48], temp_pos, obstacle_pos[39:0]};
          end else if(obstacle_hit_pos == 6 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:40], temp_pos, obstacle_pos[31:0]};
          end else if(obstacle_hit_pos == 7 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:32], temp_pos, obstacle_pos[23:0]};
          end else if(obstacle_hit_pos == 8 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:24], temp_pos, obstacle_pos[15:0]};
          end else if(obstacle_hit_pos == 9 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:16], temp_pos, obstacle_pos[7:0]};
          end else if(obstacle_hit_pos == 10 && temp_pos != snake_pos[399:392] + 1 && temp_pos != snake_pos[399:392]-1)begin 
            obstacle_new_pos <= {obstacle_pos[79:8], temp_pos};
          end
        end
        
      end
    
    end else begin 
      apple_pos <= main_apple_pos;
      obstacle_new_pos <= obstacle_pos;
    end
  end
end

// 判斷重疊的函數
function is_overlap(
    input [7:0] pos,
    input [399:0] entity_pos
);
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

endmodule