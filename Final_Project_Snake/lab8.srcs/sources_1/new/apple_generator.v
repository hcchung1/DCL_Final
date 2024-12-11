module apple_generator (
    input wire clk,               // 時脈訊號
    input wire reset,             // 重置訊號
    input wire [39:0] snake_pos,  // 蛇的位置，每個節點 [7:0]
    input wire [39:0] obstacle_pos, // 障礙物的位置，每個障礙物 [7:0]
    output reg [39:0] apple_pos   // 蘋果的位置，每個蘋果 [7:0]
);

    reg [7:0] temp_pos;           // 暫時儲存生成的蘋果位置
    reg [4:0] apple_count;        // 已成功生成的蘋果數量
    reg [15:0] lfsr;              // 用於隨機數生成的 LFSR

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            apple_pos <= 40'b0;   // 重置所有蘋果的位置
            apple_count <= 0;     // 重置蘋果計數
            lfsr <= 16'hACE1;     // 初始化 LFSR
        end else begin
            if (apple_count < 5) begin
                // 生成隨機位置 (4 bits for X, 4 bits for Y)
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                temp_pos <= {lfsr[3:0], lfsr[7:4]}; // [7:4] = X, [3:0] = Y
                
                // 檢查是否與蛇或障礙物重疊
                if (!is_overlap(temp_pos, snake_pos) && !is_overlap(temp_pos, obstacle_pos)) begin
                    // 儲存蘋果位置
                    apple_pos <= apple_pos | (temp_pos << (apple_count * 8));
                    apple_count <= apple_count + 1;
                end
            end
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