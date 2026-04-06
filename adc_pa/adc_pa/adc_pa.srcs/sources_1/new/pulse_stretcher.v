module pulse_stretcher (
    input wire clk,          // 120 МГц
    input wire rst,
    input wire tx_active_in, // короткий импульс (8 нс)
    output reg tx_active_out // растянутый импульс (100 нс)
);

    // Длительность 100 нс при 120 МГц = ceil(100 / 8.333) ≈ 12 тактов
    localparam WIDTH_CYCLES = 12;  
    reg [6:0] counter;      // 4 бита хватит (0..15)
    reg in_sync, in_prev;
    wire in_rising;

    // Синхронизация входа и детектор фронта
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_sync <= 1'b0;
            in_prev <= 1'b0;
        end else begin
            in_sync <= tx_active_in;
            in_prev <= in_sync;
        end
    end

    assign in_rising = in_sync && !in_prev;

    // Основной расширитель импульса
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_active_out <= 1'b0;
            counter <= 6'd0;
        end else begin
            if (in_rising) begin
                tx_active_out <= 1'b1;
                counter <= WIDTH_CYCLES - 1; // загружаем счётчик
            end else if (tx_active_out) begin
                if (counter == 6'd0)
                    tx_active_out <= 1'b0;
                else
                    counter <= counter - 1'b1;
            end
        end
    end

endmodule
