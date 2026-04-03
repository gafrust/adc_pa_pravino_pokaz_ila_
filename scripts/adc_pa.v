`timescale 1 ns/1 ps

module adc_pa(
    input clk_120_i,
    (* IOB = "TRUE" *) output reg adc_sck_o,
    (* IOB = "TRUE" *) output reg adc_conv_o,
    input adc_sdo_i
);

// Входной регистр в IOB (должен быть сразу после входа)
(* IOB = "TRUE" *) reg adc_sdo_ibuf;

wire rst_i;
reg [3:0] adc_sck_counter;
reg adc_sck_reg;
reg adc_sck_reg_prev;  // Для детекции фронта SCK
reg adc_conv_reg;
RES RES(
    .clk(clk_120_i),
    .rst(rst_i)
);

// ============================================================================
// Логика делителя частоты и выходные регистры
// ============================================================================
always @(posedge clk_120_i or posedge rst_i) begin
    if(rst_i) begin
        adc_sck_counter <= 4'd0;
        adc_sck_reg <= 1'b0;
        adc_conv_o <= 1'b0;
        adc_sck_o <= 1'b0;
        adc_sck_reg_prev <= 1'b0;
    end else begin
        adc_sck_counter <= adc_sck_counter + 1;
        adc_conv_o <= adc_conv_reg;
        adc_sck_o <= adc_sck_reg;
        adc_sck_reg_prev <= adc_sck_reg;
        
        if(adc_sck_counter == 4'd5) begin
            adc_sck_counter <= 4'h0;
            adc_sck_reg <= ~adc_sck_reg;
        end
    end
end

// ============================================================================
// Входной регистр IOB (отдельный always-блок для ясности)
// ============================================================================
always @(posedge clk_120_i or posedge rst_i) begin
    if(rst_i) begin
        adc_sdo_ibuf <= 1'b0;
    end else begin
        adc_sdo_ibuf <= adc_sdo_i;
    end
end

// ============================================================================
// Логика задержки и запуска измерений
// ============================================================================
reg [16:0] delay_counter;
reg [8:0]  measurement_counter;
reg [31:0] sum_u_pad;
reg [5:0]  sum_u_otr;

reg adc_sdo_sync_reg1;
reg adc_sdo_sync_reg2;
wire adc_sdo_sync;
reg [1:0] state;



// Регистры для сдвигового регистра
reg [13:0] shift_reg_ch0;     // 14-битный сдвиговый регистр для канала 0
reg [13:0] shift_reg_ch1;     // 14-битный сдвиговый регистр для канала 1
reg [5:0]  bit_counter;        // Счетчик битов (0-31)
reg        data_valid_ch0;     // Флаг готовности канала 0
reg        data_valid_ch1;     // Флаг готовности канала 1
reg  [13:0] adc_data_ch0;       // Данные канала 0 (дополнительный код)
reg  [13:0] adc_data_ch1;       // Данные канала 1 (дополнительный код)
reg        data_ready;         // Флаг готовности новых данных
localparam IDLE = 2'd0;
localparam DELAY = 2'd1;
localparam MEASURE = 2'd2;

always @(posedge adc_sck_reg or posedge rst_i) begin
    if (rst_i) begin
        delay_counter       <= 17'd0;
        measurement_counter <= 9'd0;
        sum_u_pad           <= 32'd0;
        sum_u_otr           <= 32'd0;
        adc_conv_reg        <= 1'b0;
        state               <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                delay_counter <= 17'd200; // 17'd48000;
                state <= DELAY;
            end
            DELAY: begin
                if (delay_counter != 0) begin
                    delay_counter <= delay_counter - 1;
                    if (delay_counter == 1) begin
                        adc_conv_reg <= 1'b1;
                        measurement_counter <= 9'd39;
                        state <= MEASURE;
                    end
                end
            end
            MEASURE: begin
                adc_conv_reg <= 1'b0;
                if (measurement_counter != 0) begin
                    measurement_counter <= measurement_counter - 1;
                    if (measurement_counter == 1) begin
                        state <= IDLE;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// ============================================================================
// Синхронизация входного сигнала (защита от метастабильности)
// ============================================================================
always @(posedge clk_120_i or posedge rst_i) begin
    if (rst_i) begin
        adc_sdo_sync_reg1 <= 1'b0;
        adc_sdo_sync_reg2 <= 1'b0;
    end else begin
        adc_sdo_sync_reg1 <= adc_sdo_ibuf;
        adc_sdo_sync_reg2 <= adc_sdo_sync_reg1;
    end
end

assign adc_sdo_sync = adc_sdo_sync_reg2;

// ============================================================================
// СДВИГОВЫЙ РЕГИСТР ДЛЯ СБОРА ДАННЫХ АЦП
// ============================================================================
// Алгоритм:
// 1. Счетчик битов считает от 0 до 31 (32 бита на кадр)
// 2. Бит 0-13: канал 0, бит 14-27: канал 1, бит 28-31: пауза
// 3. Сбор начинается после 3-го такта SCK после CONV
// 4. По переднему фронту SCK защелкиваем бит с SDO
// ============================================================================

always @(posedge adc_sck_reg or posedge rst_i) begin
    if (rst_i) begin
        shift_reg_ch0   <= 14'd0;
        shift_reg_ch1   <= 14'd0;
        bit_counter     <= 6'd0;
        data_valid_ch0  <= 1'b0;
        data_valid_ch1  <= 1'b0;
        adc_data_ch0    <= 14'd0;
        adc_data_ch1    <= 14'd0;
        data_ready      <= 1'b0;
    end else begin
        // Сброс флага готовности данных (он активен только 1 такт)
        data_ready <= 1'b0;
        
        // Проверяем, что мы в режиме измерения
        if (state == MEASURE) begin
            // Ловим передний фронт SCK (adc_sck_reg меняется с 0 на 1)
            if (adc_sck_reg == 1'b1 && adc_sck_reg_prev == 1'b0) begin
                
                // ========== ЛОГИКА СБОРА БИТОВ ==========
                // Обработка первых двух битов (сброс регистров)
                if (bit_counter < 6'd1) begin
                    shift_reg_ch0 <= 14'd0;  // Сброс регистра канала 0
                end else if (bit_counter < 6'd17) begin
                    // Бит для канала 0 (биты 2-15)
                    shift_reg_ch0 <= {shift_reg_ch0[12:0], adc_sdo_sync};
                end else if (bit_counter < 6'd19) begin
                    shift_reg_ch1 <= 14'd0;  // Сброс регистра канала 1
                end else if (bit_counter < 6'd33) begin
                    // Бит для канала 1 (биты 18-31)
                    shift_reg_ch1 <= {shift_reg_ch1[12:0], adc_sdo_sync};
                end
                // Биты 32-33 игнорируем (пауза)
                
                // Увеличиваем счетчик битов
                bit_counter <= bit_counter + 1'b1;
                
                // ========== ПРОВЕРКА ГОТОВНОСТИ ДАННЫХ ==========
                // Когда собрали 14 бит для канала 0 (бит 15 - последний 14-й бит)
                if (bit_counter == 6'd17) begin
                    data_valid_ch0 <= 1'b1;
                    adc_data_ch0 <= shift_reg_ch0;
                end
                
                // Когда собрали 14 бит для канала 1 (бит 31 - последний 14-й бит)
                if (bit_counter == 6'd33) begin
                    data_valid_ch1 <= 1'b1;
                    adc_data_ch1 <= shift_reg_ch1;
                end
                
                // Когда собрали полный кадр (32 бита, счетчик доходит до 32)
                if (bit_counter == 6'd34) begin
                    // Сигнализируем, что данные готовы
                    data_ready <= 1'b1;
                    // Сбрасываем счетчик для следующего кадра
                    bit_counter <= 6'd0;
                end
                
            end  // if (adc_sck_reg == 1'b1 && adc_sck_reg_prev == 1'b0)
        end else begin
            // Если не в режиме измерения, сбрасываем счетчики
            bit_counter <= 6'd0;
            data_valid_ch0 <= 1'b0;
            data_valid_ch1 <= 1'b0;
        end  // if (state == MEASURE)
    end  // else (не rst)
end  // always
 

endmodule


//`timescale 1 ns/1 ps
////module adc_pa(
////    input  clk_120_i,
////   (*IOB = "TRUE" *) output reg adc_sck_o,
////   (*IOB = "TRUE" *) output reg adc_conv_o,
////   (*IOB = "TRUE" *) input  adc_sdo_i
////);

//module adc_pa(
//    input clk_120_i,
//    (* IOB = "TRUE" *) output reg adc_sck_o,
//    (* IOB = "TRUE" *) output reg adc_conv_o,
//    input adc_sdo_i  // атрибут здесь не работает
//);

//// Входной регистр в IOB (должен быть сразу после входа)
//(* IOB = "TRUE" *) reg adc_sdo_ibuf;

//always @(posedge clk_120_i) begin
//    adc_sdo_ibuf <= adc_sdo_i;  // этот регистр будет в IOB
//end

//wire rst_i;
//reg adc_sdo_ibuf;
//reg [3:0] adc_sck_counter;
//reg adc_sck_reg;
//reg adc_sck_out;


//RES RES(
//    .clk(clk_120_i),
//    .rst(rst_i)
//);


//always @(posedge clk_120_i or posedge rst_i) begin
//    if(rst_i) begin
//        adc_sck_counter <= 4'd0;
//        adc_sck_reg <= 1'b0;
//    end else begin
//        adc_sck_counter <= adc_sck_counter + 1;
//         adc_conv_o <= adc_conv_reg;
//         adc_sck_o <= adc_sck_reg;
//         adc_sdo_ibuf <= adc_sdo_i;
//        if(adc_sck_counter == 4'd5) begin
//            adc_sck_counter <= 4'h0;
//            adc_sck_reg <= ~adc_sck_reg;
//        end
//    end
//end



//// ============================================================================
//// Логика задержки и запуска измерений
//// ============================================================================
//reg [16:0] delay_counter;
//reg [5:0]  measurement_counter;
//reg [31:0] sum_u_pad;
//reg [5:0]  sum_u_otr;
//reg adc_conv_reg;
//reg adc_sdo_sync_reg1;
//reg adc_sdo_sync_reg2;
//wire adc_sdo_sync;
//reg [1:0] state;
//localparam IDLE = 2'd0;
//localparam DELAY = 2'd1;
//localparam MEASURE = 2'd2;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        delay_counter       <= 17'd0;
//        measurement_counter <= 6'd0;
//        sum_u_pad           <= 32'd0;
//        sum_u_otr           <= 32'd0;
//        adc_conv_reg        <= 1'b0;
//        state               <= IDLE;
//    end else begin
//        case (state)
//            IDLE: begin
//                delay_counter <= 17'd1200;//17'd48000;
//                state <= DELAY;
//            end
//            DELAY: begin
//                if (delay_counter != 0) begin
//                    delay_counter <= delay_counter - 1;
//                    if (delay_counter == 1) begin
//                        adc_conv_reg <= 1'b1;
//                        measurement_counter <= 6'd32;
//                        state <= MEASURE;
//                    end
//                end
//            end
//            MEASURE: begin
//                adc_conv_reg <= 1'b0;
//                if (measurement_counter != 0) begin
//                    measurement_counter <= measurement_counter - 1;
//                    if (measurement_counter == 1) begin
//                        state <= IDLE;
//                    end
//                end
//            end
//            default: state <= IDLE;
//        endcase
//    end
//end

//// ============================================================================
//// Синхронизация входного сигнала
//// ============================================================================


//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        adc_sdo_sync_reg1 <= 1'b0;
//        adc_sdo_sync_reg2 <= 1'b0;
//    end else begin
//        adc_sdo_sync_reg1 <= adc_sdo_ibuf;
//        adc_sdo_sync_reg2 <= adc_sdo_sync_reg1;
//    end
//end

//assign adc_sdo_sync = adc_sdo_sync_reg2;


//// ============================================================================
//// ILA (Integrated Logic Analyzer) - ТОЛЬКО ДЛЯ СИНТЕЗА
//// ============================================================================
//`ifdef SYNTHESIS
//    // ILA IP Core instantiation
//    // Подключаем ТОЛЬКО внутренние сигналы, НЕ подключаем порты напрямую!
    
//    ila_0 ila_inst (
//        .clk(clk_120_i),                        // тактовый сигнал
//        .probe0(adc_sck_counter),               // [3:0] счетчик SCK
//        .probe1(adc_sck_reg),                   // [0] регистр SCK
//        .probe2(delay_counter),                 // [16:0] счетчик задержки
//        .probe3(measurement_counter),           // [5:0] счетчик измерений
//        .probe4(state),                         // [1:0] состояние автомата
//        .probe5(adc_conv_reg),                  // [0] внутренний conv
//        .probe6(adc_conv_reg),                  // [0] внутренний conv сигнал (до OBUF)
//        .probe7(adc_sck_reg),                   // [0] внутренний sck сигнал (до OBUF)
//        .probe8(adc_sdo_sync),                  // [0] синхронизированный вход
//        .probe9(adc_sdo_ibuf)                   // [0] выход IBUF
//    );
//`endif

//endmodule


//`timescale 1 ns/1 ps
//module adc_pa(
//    input wire clk_120_i,
//    output wire adc_sck_o,
//    output wire adc_conv_o,
//    input wire adc_sdo_i
//);

//// ============================================================================
//// УСЛОВНАЯ КОМПИЛЯЦИЯ: IBUF/OBUF только для синтеза
//// ============================================================================
//`ifdef SYNTHESIS
//    // Для синтеза используем реальные примитивы
//    wire adc_sdo_ibuf;
//    IBUF #(.IBUF_LOW_PWR("TRUE"), .IOSTANDARD("LVCMOS33")) adc_sdo_ibuf_inst (
//        .I(adc_sdo_i), 
//        .O(adc_sdo_ibuf)
//    );
    
//    wire adc_sck_int;
//    wire adc_sck_out;
//    OBUF #(.IOSTANDARD("LVCMOS33"), .DRIVE(12), .SLEW("SLOW")) adc_sck_obuf_inst (
//        .I(adc_sck_int), 
//        .O(adc_sck_out)
//    );
//    assign adc_sck_o = adc_sck_out;
    
//    wire adc_conv_int;
//    wire adc_conv_out;
//    OBUF #(.IOSTANDARD("LVCMOS33"), .DRIVE(12), .SLEW("SLOW")) adc_conv_obuf_inst (
//        .I(adc_conv_int), 
//        .O(adc_conv_out)
//    );
//    assign adc_conv_o = adc_conv_out;
//`else
//    // Для симуляции используем прямые соединения
//    wire adc_sdo_ibuf = adc_sdo_i;
//    wire adc_sck_int;
//    wire adc_conv_int;
//    assign adc_sck_o = adc_sck_int;
//    assign adc_conv_o = adc_conv_int;
//`endif

//// ============================================================================
//// Внутренний сброс
//// ============================================================================
//wire rst_i;

//RES RES(
//    .clk(clk_120_i),
//    .rst(rst_i)
//);

//// ============================================================================
//// Логика делителя частоты
//// ============================================================================
//reg [3:0] adc_sck_counter;
//reg adc_sck_reg;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if(rst_i) begin
//        adc_sck_counter <= 4'd0;
//        adc_sck_reg <= 1'b0;
//    end else begin
//        adc_sck_counter <= adc_sck_counter + 1;
//        if(adc_sck_counter == 4'd5) begin
//            adc_sck_counter <= 4'h0;
//            adc_sck_reg <= ~adc_sck_reg;
//        end
//    end
//end

//assign adc_sck_int = adc_sck_reg;

//// ============================================================================
//// Логика задержки и запуска измерений
//// ============================================================================
//reg [16:0] delay_counter;
//reg [5:0]  measurement_counter;
//reg [31:0] sum_u_pad;
//reg [5:0]  sum_u_otr;
//reg adc_conv_reg;

//reg [1:0] state;
//localparam IDLE = 2'd0;
//localparam DELAY = 2'd1;
//localparam MEASURE = 2'd2;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        delay_counter       <= 17'd0;
//        measurement_counter <= 6'd0;
//        sum_u_pad           <= 32'd0;
//        sum_u_otr           <= 32'd0;
//        adc_conv_reg        <= 1'b0;
//        state               <= IDLE;
//    end else begin
//        case (state)
//            IDLE: begin
//                delay_counter <= 17'd1200;//17'd48000;
//                state <= DELAY;
//            end
//            DELAY: begin
//                if (delay_counter != 0) begin
//                    delay_counter <= delay_counter - 1;
//                    if (delay_counter == 1) begin
//                        adc_conv_reg <= 1'b1;
//                        measurement_counter <= 6'd32;
//                        state <= MEASURE;
//                    end
//                end
//            end
//            MEASURE: begin
//                adc_conv_reg <= 1'b0;
//                if (measurement_counter != 0) begin
//                    measurement_counter <= measurement_counter - 1;
//                    if (measurement_counter == 1) begin
//                        state <= IDLE;
//                    end
//                end
//            end
//            default: state <= IDLE;
//        endcase
//    end
//end

//// ============================================================================
//// Синхронизация входного сигнала
//// ============================================================================
//reg adc_sdo_sync_reg1;
//reg adc_sdo_sync_reg2;
//wire adc_sdo_sync;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        adc_sdo_sync_reg1 <= 1'b0;
//        adc_sdo_sync_reg2 <= 1'b0;
//    end else begin
//        adc_sdo_sync_reg1 <= adc_sdo_ibuf;
//        adc_sdo_sync_reg2 <= adc_sdo_sync_reg1;
//    end
//end

//assign adc_sdo_sync = adc_sdo_sync_reg2;
//assign adc_conv_int = adc_conv_reg;

//// ============================================================================
//// ILA (Integrated Logic Analyzer) - ТОЛЬКО ДЛЯ СИНТЕЗА
//// ============================================================================
//`ifdef SYNTHESIS
//    // ILA IP Core instantiation
//    // Подключаем ТОЛЬКО внутренние сигналы, НЕ подключаем порты напрямую!
    
//    ila_0 ila_inst (
//        .clk(clk_120_i),                        // тактовый сигнал
//        .probe0(adc_sck_counter),               // [3:0] счетчик SCK
//        .probe1(adc_sck_reg),                   // [0] регистр SCK
//        .probe2(delay_counter),                 // [16:0] счетчик задержки
//        .probe3(measurement_counter),           // [5:0] счетчик измерений
//        .probe4(state),                         // [1:0] состояние автомата
//        .probe5(adc_conv_reg),                  // [0] внутренний conv
//        .probe6(adc_conv_int),                  // [0] внутренний conv сигнал (до OBUF)
//        .probe7(adc_sck_int),                   // [0] внутренний sck сигнал (до OBUF)
//        .probe8(adc_sdo_sync),                  // [0] синхронизированный вход
//        .probe9(adc_sdo_ibuf)                   // [0] выход IBUF
//    );
//`endif

//endmodule





//module adc_pa(
//    input wire clk_120_i,
//    output wire adc_sck_o,
//    output wire adc_conv_o,
//    input wire adc_sdo_i
//);

//// ============================================================================
//// УСЛОВНАЯ КОМПИЛЯЦИЯ: IBUF/OBUF только для синтеза
//// ============================================================================
//`ifdef SYNTHESIS
//    // Для синтеза используем реальные примитивы
//    wire adc_sdo_ibuf;
//    IBUF #(.IBUF_LOW_PWR("TRUE"), .IOSTANDARD("LVCMOS33")) adc_sdo_ibuf_inst (
//        .I(adc_sdo_i), .O(adc_sdo_ibuf)
//    );
    
//    wire adc_sck_int;
//    OBUF #(.IOSTANDARD("LVCMOS33"), .DRIVE(12), .SLEW("SLOW")) adc_sck_obuf_inst (
//        .I(adc_sck_int), .O(adc_sck_o)
//    );
    
//    wire adc_conv_int;
//    OBUF #(.IOSTANDARD("LVCMOS33"), .DRIVE(12), .SLEW("SLOW")) adc_conv_obuf_inst (
//        .I(adc_conv_int), .O(adc_conv_o)
//    );
//`else
//    // Для симуляции используем прямые соединения
//    wire adc_sdo_ibuf = adc_sdo_i;
//    wire adc_sck_int;
//    wire adc_conv_int;
//    assign adc_sck_o = adc_sck_int;
//    assign adc_conv_o = adc_conv_int;
//`endif

//// ============================================================================
//// Внутренний сброс (временный)
//// ============================================================================
//wire rst_i;// = 1'b0;  // для симуляции сброс неактивен

//RES RES(
//.clk(clk_120_i),
//.rst(rst_i)
//    );

//// ============================================================================
//// Логика делителя частоты
//// ============================================================================
//reg [3:0] adc_sck_counter;
//reg adc_sck_reg;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if(rst_i) begin
//        adc_sck_counter <= 4'd0;
//        adc_sck_reg <= 1'b0;
//    end else begin
//        adc_sck_counter <= adc_sck_counter + 1;
//        if(adc_sck_counter == 4'd5) begin
//            adc_sck_counter <= 4'h0;
//            adc_sck_reg <= ~adc_sck_reg;
//        end
//    end
//end

//assign adc_sck_int = adc_sck_reg;

//// ============================================================================
//// Логика задержки и запуска измерений
//// ============================================================================
//reg [16:0] delay_counter;
//reg [5:0]  measurement_counter;
//reg [31:0] sum_u_pad;
//reg [5:0]  sum_u_otr;
//reg adc_conv_reg;

//reg [1:0] state;
//localparam IDLE = 2'd0;
//localparam DELAY = 2'd1;
//localparam MEASURE = 2'd2;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        delay_counter       <= 17'd0;
//        measurement_counter <= 6'd0;
//        sum_u_pad           <= 32'd0;
//        sum_u_otr           <= 32'd0;
//        adc_conv_reg        <= 1'b0;
//        state               <= IDLE;
//    end else begin
//        case (state)
//            IDLE: begin
//                delay_counter <= 17'd48000;
//                state <= DELAY;
//            end
//            DELAY: begin
//                if (delay_counter != 0) begin
//                    delay_counter <= delay_counter - 1;
//                    if (delay_counter == 1) begin
//                        adc_conv_reg <= 1'b1;
//                        measurement_counter <= 6'd32;
//                        state <= MEASURE;
//                    end
//                end
//            end
//            MEASURE: begin
//                adc_conv_reg <= 1'b0;
//                if (measurement_counter != 0) begin
//                    measurement_counter <= measurement_counter - 1;
//                    if (measurement_counter == 1) begin
//                        state <= IDLE;
//                    end
//                end
//            end
//            default: state <= IDLE;
//        endcase
//    end
//end

//// ============================================================================
//// Синхронизация входного сигнала
//// ============================================================================
//reg adc_sdo_sync_reg1;
//reg adc_sdo_sync_reg2;
//wire adc_sdo_sync;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if (rst_i) begin
//        adc_sdo_sync_reg1 <= 1'b0;
//        adc_sdo_sync_reg2 <= 1'b0;
//    end else begin
//        adc_sdo_sync_reg1 <= adc_sdo_ibuf;
//        adc_sdo_sync_reg2 <= adc_sdo_sync_reg1;
//    end
//end

//assign adc_sdo_sync = adc_sdo_sync_reg2;
//assign adc_conv_int = adc_conv_reg;

//endmodule









//`timescale 1 ns/1 ps
//module adc_pa(
//    // РЎРёСЃС‚РµРјРЅС‹Рµ СЃРёРіРЅР°Р»С‹
//   // input wire rst_i,
//    input wire clk_120_i,

//    // Axi BRAM РёРЅС‚РµСЂС„РµР№СЃ РІР·Р°РёРјРѕРґРµР№СЃС‚РІРёСЏ СЃ MicroBlaze
////    input wire axi_en_i,
////    input wire [31:0] axi_data_i,
////    input wire axi_we_i,
////    input wire [31:0] axi_addr_i,
////    output reg axi_vd_o,
////    output reg [31:0] axi_data_o,
////    output reg axi_irq_o,

////    // Р’С…РѕРґРЅС‹Рµ РїРѕСЂС‚С‹ РѕС‚ РјРѕРґСѓР»СЏ РїРµСЂРµРґР°С‚С‡РёРєР°
////    input wire tx_active_i,
////    input wire [3:0] tx_mode_i,

//    // Р’С…РѕРґРЅС‹Рµ/РІС‹С…РѕРґРЅС‹Рµ РїРѕСЂС‚С‹ Рє РђР¦Рџ
//    output reg adc_sck_o,
//    output reg adc_conv_o,
//    input wire adc_sdo_i
//    );

//RES RES(
//.clk(clk_120_i),
//.rst(rst_i)
//    );

//    //Р’РЅСѓС‚СЂРµРЅРЅРёРµ СЂРµРіРёСЃС‚СЂС‹
//    reg [31:0] control_reg = 32'h0;
//    reg [31:0] rezult_reg = 32'h0;
//    reg [31:0] calib_reg [0:15];
//    integer i;

////    //Р›РѕРіРёРєР° СЃР±СЂРѕСЃР°
////    always @(posedge clk_120_i or posedge rst_i) begin
////        if(rst_i) begin
////            control_reg <= 32'h0;
////            rezult_reg <= 32'h0;
////            for ( i = 0; i < 16; i = i + 1) begin
////            calib_reg [i] <= 32'h0;
////            end
////            axi_vd_o <= 1'h0;
////            axi_data_o <= 32'h0;
////            axi_irq_o <=1'h0;
////            adc_sck_o <= 1'h0;
////            adc_conv_o <= 1'h0;
////        end
////    end


////always @(posedge clk_120_i) begin
////    if(!rst_i && axi_en_i) begin
////       if(axi_we_i) begin
////         // Р—Р°РїРёСЃСЊ РґР°РЅРЅС‹С…
////         case (axi_addr_i[7:0])
////             8'h0: control_reg <= axi_data_i;
////             8'h4:; //Р РµРіРёСЃС‚СЂ С‚РѕР»СЊРєРѕ РґР»СЏ С‡С‚РµРЅРёСЏ
////             8'h8: calib_reg[0] <= axi_data_i;
////             8'hc: calib_reg[1] <= axi_data_i;
////             default: ;
////         endcase
////       end else begin
////         // Р§С‚РµРЅРёРµ РґР°РЅРЅС‹С…
////         case (axi_addr_i[7:0])
////             8'h0: axi_data_o <= control_reg;
////             8'h4: axi_data_o <= axi_data_o; 
////             8'h8: axi_data_o <= calib_reg[0];
////             8'hc: axi_data_o <= calib_reg[1];
////             default: axi_data_o <= 32'h0;
////         endcase
////         axi_vd_o <= 1'b1;
////       end
////    end else begin
////         axi_vd_o <= 1'b0;
        
////    end
////end
    
//// Р›РѕРіРёРєР° РґРµР»РµРЅРёСЏ С‡Р°СЃС‚РѕС‚С‹ РёР· 120 РњРіС† РґРѕ 10 РњРіС†    
//reg [3:0] adc_sck_counter;

//always @(posedge clk_120_i or posedge rst_i) begin
//    if(rst_i) begin
//      adc_sck_counter <= 4'd0;
//      adc_sck_o <= 1'b0;
//    end else begin
//      adc_sck_counter <= adc_sck_counter + 1;
//      if(adc_sck_counter == 4'd5) begin
//        adc_sck_counter <= 4'h0;
//        adc_sck_o <= ~adc_sck_o;
//      end
//    end
//end


//// Р›РѕРіРёРєР° Р·Р°РґРµСЂР¶РєРё Рё Р·Р°РїСѓСЃРєР° РёР·РјРµСЂРµРЅРёР№
//reg [16:0] delay_counter;      // СЃС‡С‘С‚С‡РёРє Р·Р°РґРµСЂР¶РєРё РїРµСЂРµРґ РЅР°С‡Р°Р»РѕРј РёР·РјРµСЂРµРЅРёР№
//reg [5:0]  measurement_counter; // СЃС‡С‘С‚С‡РёРє РєРѕР»РёС‡РµСЃС‚РІР° РёР·РјРµСЂРµРЅРёР№ (32 РёР·РјРµСЂРµРЅРёСЏ)
//reg [31:0] sum_u_pad;           // СЃСѓРјРјР° РїРѕР»РѕР¶РёС‚РµР»СЊРЅС‹С… Р·РЅР°С‡РµРЅРёР№ (РЅРµ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ РІ Р»РѕРіРёРєРµ)
//reg [5:0]  sum_u_otr;           // СЃСѓРјРјР° РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹С… Р·РЅР°С‡РµРЅРёР№ (РЅРµ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ РІ Р»РѕРіРёРєРµ)

//// -------------------------------------------------------------------
//// Р“Р»Р°РІРЅС‹Р№ С†РёРєР»: always-Р±Р»РѕРє СЃСЂР°Р±Р°С‚С‹РІР°РµС‚ РїРѕ РїРѕР»РѕР¶РёС‚РµР»СЊРЅРѕРјСѓ С„СЂРѕРЅС‚Сѓ С‚Р°РєС‚Р°
//// РёР»Рё РїРѕ СЃР±СЂРѕСЃСѓ. Р—РґРµСЃСЊ СЂРµР°Р»РёР·РѕРІР°РЅ РєРѕРЅРµС‡РЅС‹Р№ Р°РІС‚РѕРјР°С‚ СѓРїСЂР°РІР»РµРЅРёСЏ РђР¦Рџ.
//// -------------------------------------------------------------------
//always @(posedge clk_120_i or posedge rst_i) begin
//  // --------------------- Р’РµС‚РІР»РµРЅРёРµ 1: СЃР±СЂРѕСЃ ------------------------
//  if (rst_i) begin
//    // РћР±РЅСѓР»РµРЅРёРµ РІСЃРµС… СЂРµРіРёСЃС‚СЂРѕРІ РїСЂРё Р°РєС‚РёРІРЅРѕРј СЃР±СЂРѕСЃРµ
//    delay_counter      <= 17'd0;
//    measurement_counter <= 6'd0;
//    sum_u_pad          <= 32'd0;
//    sum_u_otr          <= 32'd0;
//    adc_conv_o         <= 1'b0;    // СЃРёРіРЅР°Р» Р·Р°РїСѓСЃРєР° РђР¦Рџ РІС‹РєР»СЋС‡РµРЅ
//  // --------------------- Р’РµС‚РІР»РµРЅРёРµ 2: РѕР±С‹С‡РЅР°СЏ СЂР°Р±РѕС‚Р° ---------------
//  end else begin
//    // -------- Р Р°Р·РІРµС‚РІР»РµРЅРёРµ 2.1: Р°РєС‚РёРІРЅР° РїРµСЂРµРґР°С‡Р°? ----------
//    if (1) begin
//      // РЈСЃС‚Р°РЅР1°РІР»РёРІР°РµРј Р·Р°РґРµСЂР¶РєСѓ 48000 С‚Р°РєС‚РѕРІ (РґР»СЏ РїР°СѓР·С‹ РїРѕСЃР»Рµ РїРµСЂРµРґР°С‡Рё)
//      delay_counter <= 17'd48000;
//    // -------- Р Р°Р·РІРµС‚РІР»РµРЅРёРµ 2.2: РёРґС‘С‚ РѕС‚СЃС‡С‘С‚ Р·Р°РґРµСЂР¶РєРё? ----------
//    end else if (delay_counter != 0) begin
//      // РЈРјРµРЅСЊС€Р°РµРј СЃС‡С‘С‚С‡РёРє Р·Р°РґРµСЂР¶РєРё РЅР° 1
//      delay_counter <= delay_counter - 1;
//      // Р’Р»РѕР¶РµРЅРЅРѕРµ СЂР°Р·РІРµС‚РІР»РµРЅРёРµ: РїРѕСЃР»Рµ РґРµРєСЂРµРјРµРЅС‚Р° РґРѕСЃС‚РёРіР»Рё РЅСѓР»СЏ?
//      // (РµСЃР»Рё delay_counter Р±С‹Р» СЂР°РІРµРЅ 1, С‚Рѕ С‚РµРїРµСЂСЊ СЃС‚Р°Р» 0)
//      if (delay_counter == 1) begin
//        // Р—Р°РїСѓСЃРєР°РµРј РђР¦Рџ Рё СѓСЃС‚Р°РЅР°РІР»РёРІР°РµРј СЃС‡С‘С‚С‡РёРє РёР·РјРµСЂРµРЅРёР№ РЅР° 32
//        adc_conv_o      <= 1'b1;
//        measurement_counter <= 6'd32;
//      end
//    // -------- Р Р°Р·РІРµС‚РІР»РµРЅРёРµ 2.3: РёРґС‘С‚ РїСЂРѕС†РµСЃСЃ РёР·РјРµСЂРµРЅРёР№? ----------
//    end else if (measurement_counter != 0) begin
//      // РЎР±СЂР°СЃС‹РІР°РµРј СЃРёРіРЅР°Р» Р·Р°РїСѓСЃРєР° РђР¦Рџ Рё СѓРјРµРЅСЊС€Р°РµРј СЃС‡С‘С‚С‡РёРє РёР·РјРµСЂРµРЅРёР№
//      adc_conv_o      <= 1'b0;
//      measurement_counter <= measurement_counter - 1;
//    // -------- Р Р°Р·РІРµС‚РІР»РµРЅРёРµ 2.4: РІСЃРµ РѕСЃС‚Р°Р»СЊРЅС‹Рµ СЃР»СѓС‡Р°Рё ----------
//    end else begin
//      // РќРёС‡РµРіРѕ РЅРµ РґРµР»Р°РµРј, РїСЂРѕСЃС‚Рѕ РґРµСЂР¶РёРј adc_conv_o РІ 0
//      adc_conv_o <= 1'b0;
//    end
//  end
//end




    
//endmodule /* adc_pa */
