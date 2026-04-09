`timescale 1 ns/1 ns

module tb_adc_pa_simple();

// Сигналы
reg         clk_120_i;
reg         adc_sdo_i;
reg         tx_active_i;
wire        adc_sck_o;
wire        adc_conv_o;
wire        adc_conv_flag;

wire [13:0] adc_data_ch0;
wire [13:0] adc_data_ch1;

// Переменные тестбенча
reg [31:0] test_data;
integer    bit_cnt;

// Инстанцирование модуля
adc_pa uut (
    .clk_120_i   (clk_120_i),
    .adc_sck_o   (adc_sck_o),
    .adc_conv_o  (adc_conv_o),
    .adc_sdo_i   (adc_sdo_i),
    .adc_data_ch0(adc_data_ch0),
    .adc_data_ch1(adc_data_ch1),
    .tx_active_i (tx_active_i),
    .adc_conv_flag(adc_conv_flag)
);

// Генератор тактов
initial begin
    clk_120_i = 0;
    forever #4.1667 clk_120_i = ~clk_120_i;  // 120 МГц
end

// Основной процесс тестирования
initial begin
    // Инициализация
    adc_sdo_i = 1'b1;
    bit_cnt = 0;
    tx_active_i = 1'b0;
    #100;
// Тестовые данные (канал0=10, канал1=5, маркер=11)
    test_data = {14'd10, 2'b11, 14'd5};

    
    // Первый запуск tx_active (не обязателен, но оставим)
    repeat(1) begin
        #100;
        tx_active_i = 1'b1;
        #1000;
        tx_active_i = 1'b0;
    end 
    
    
    
    $display("=== Начало теста ===");
    $display("Тестовые данные: 0x%08X", test_data);





    #10000
     repeat(1) begin
        #100;
        tx_active_i = 1'b1;
        #1000;
        tx_active_i = 1'b0;
    end 
    
    // ------------------------------------------------------------------
    // Первый сеанс имитации данных АЦП (ожидаем adc_conv_flag)
    // ------------------------------------------------------------------
    #50000;
    @(posedge uut.adc_conv_flag);        // ждём сигнал начала преобразования
    repeat(1) @(posedge adc_sck_o);      // ждём первый такт SCK
    $display("Первый сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    // ------------------------------------------------------------------
    // Второй сеанс
    // ------------------------------------------------------------------
    #50000;
    @(posedge uut.adc_conv_flag);
    repeat(1) @(posedge adc_sck_o);
    $display("Второй сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    // ------------------------------------------------------------------
    // Третий сеанс
    // ------------------------------------------------------------------
    #50000;
    @(posedge uut.adc_conv_flag);
    repeat(1) @(posedge adc_sck_o);
    $display("Третий сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    // ------------------------------------------------------------------
    // Четвёртый сеанс
    // ------------------------------------------------------------------
    #50000;
    @(posedge uut.adc_conv_flag);
    repeat(1) @(posedge adc_sck_o);
    $display("Четвёртый сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    // ------------------------------------------------------------------
    // Пятый сеанс
    // ------------------------------------------------------------------
    #50000;
    @(posedge uut.adc_conv_flag);
    repeat(1) @(posedge adc_sck_o);
    $display("Пятый сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    // ------------------------------------------------------------------
    // Дополнительная активация tx_active и ещё один сеанс
    // ------------------------------------------------------------------
    #400000;
    tx_active_i = 1'b1;
    #1000;
    tx_active_i = 1'b0;

    #50000;
    @(posedge uut.adc_conv_flag);
    repeat(1) @(posedge adc_sck_o);
    $display("Шестой сеанс: начало передачи на %0t нс", $time);
    if(adc_conv_o) begin  
        for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
            @(posedge adc_sck_o);
            adc_sdo_i = test_data[bit_cnt];
            $display("  бит %2d: %d", bit_cnt, adc_sdo_i);
        end
    end

    $display("=== Тест завершён ===");
    
    #1000000;
    $finish;
end

// Монитор сигналов
initial begin
    $monitor("Время=%0t | CONV=%b SCK=%b SDO=%b", 
             $time, adc_conv_o, adc_sck_o, adc_sdo_i);
end

endmodule





// `timescale 1 ns/1 ns

// module tb_adc_pa_simple();

// // �������
// reg         clk_120_i;
// reg         adc_sdo_i;
// reg       tx_active_i;
// wire        adc_sck_o;
// wire        adc_conv_o;
// wire     adc_conv_flag;

// wire [13:0] adc_data_ch0;
// wire [13:0] adc_data_ch1;

// // �������� ������
// reg [31:0] test_data;
// integer    bit_cnt;

// // ���������������� ������
// adc_pa uut (
//     .clk_120_i  (clk_120_i),
//     .adc_sck_o  (adc_sck_o),
//     .adc_conv_o (adc_conv_o),
//     .adc_sdo_i  (adc_sdo_i),
//     .adc_data_ch0(adc_data_ch0),
//     .adc_data_ch1(adc_data_ch1),
//     .tx_active_i (tx_active_i),
//     .adc_conv_flag(adc_conv_flag)
// );

// // ��������� ��������� �������
// initial begin
//     clk_120_i = 0;
//     forever #4.1667 clk_120_i = ~clk_120_i;  // 120 ���
// end

// // �������� ������� ���������
// initial begin
//     // �������������
//     adc_sdo_i = 1'b1;
//     bit_cnt = 0;
//     tx_active_i = 1'b0;
//     #100
//     repeat(1) begin
//     #100
//     tx_active_i = 1'b1;
//     #1000
//     tx_active_i = 1'b0;
    
//    end 
//     // �������� ������ (�����0=1024, �����1=2048, �����=1111)
//     test_data = {14'd10, 2'b11, 14'd5};
    
//     $display("=== ������ ����� ===");
//     $display("�������� ������: 0x%08X", test_data);
    
//     // ���� ������� CONV
//    // @(posedge adc_conv_o);
//   //  $display("CONV ��������� �� ������� %0t ��", $time);
    
   
  
  

   
    
// #50000

//  //@(posedge uut.adc_conv_reg);
//     //$display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end

//    #50000

//  //@(posedge uut.adc_conv_reg);
//   //  $display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end

//    #50000

//  //@(posedge uut.adc_conv_reg);
//  //   $display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end

//    #50000

//  //@(posedge uut.adc_conv_reg);
//  //   $display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end

//    #50000

//  //@(posedge uut.adc_conv_reg);
//  //   $display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end

//   #400000

  
// tx_active_i = 1'b1;
// #1000
// tx_active_i = 1'b0;

//  #50000

//  //@(posedge uut.adc_conv_reg);
//  //   $display("CONV ��������� �� ������� %0t ��", $time);
    
//     // ���� 3 ����� SCK
//     repeat(1) @(posedge adc_sck_o);
//     $display("������ �������� ������ �� ������� %0t ��", $time);
  
// if(adc_conv_o) begin  
//    // �������� 32 ����
//    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//        @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//    end
//    end
    
  


// // for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
// //         @(posedge adc_sck_o);
// //         if(adc_conv_o) begin
// //         adc_sdo_i = test_data[bit_cnt];
// //         $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
// //     end
// // end
  
    
//     $display("=== �������� ��������� ===");

 
  

    
   
// end

// // ����������
// initial begin
//     $monitor("�����=%0t | CONV=%b SCK=%b SDO=%b", 
//              $time, adc_conv_o, adc_sck_o, adc_sdo_i);
// end
// // ���� 3 ����� SCK
//     always @(posedge adc_sck_o) begin
//      if(adc_conv_o) begin  
//    // �������� 32 ����
//      for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
//       // @(posedge adc_sck_o);
//        adc_sdo_i = test_data[bit_cnt];
//        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
//      end
//     end
        
//     end

//  #1000000;
//     $finish;

// endmodule