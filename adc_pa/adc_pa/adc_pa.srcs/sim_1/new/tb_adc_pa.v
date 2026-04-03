`timescale 1 ns/1 ps

module tb_adc_pa_simple();

// �������
reg         clk_120_i;
reg         adc_sdo_i;
reg       tx_active_i;
wire        adc_sck_o;
wire        adc_conv_o;

// �������� ������
reg [31:0] test_data;
integer    bit_cnt;

// ���������������� ������
adc_pa uut (
    .clk_120_i  (clk_120_i),
    .adc_sck_o  (adc_sck_o),
    .adc_conv_o (adc_conv_o),
    .adc_sdo_i  (adc_sdo_i),
    .tx_active_i (tx_active_i)
);

// ��������� ��������� �������
initial begin
    clk_120_i = 0;
    forever #4.1667 clk_120_i = ~clk_120_i;  // 120 ���
end

// �������� ������� ���������
initial begin
    // �������������
    adc_sdo_i = 1'b1;
    bit_cnt = 0;
    tx_active_i = 1'b0;
    #100
    repeat(1) begin
    #100
    tx_active_i = 1'b1;
    #1000
    tx_active_i = 1'b0;
    
   end 
    // �������� ������ (�����0=1024, �����1=2048, �����=1111)
    test_data = {14'd10, 2'b11, 14'd5};
    
    $display("=== ������ ����� ===");
    $display("�������� ������: 0x%08X", test_data);
    
    // ���� ������� CONV
    @(posedge uut.adc_conv_reg);
    $display("CONV ��������� �� ������� %0t ��", $time);
    
    // ���� 3 ����� SCK
    repeat(1) @(posedge adc_sck_o);
    $display("������ �������� ������ �� ������� %0t ��", $time);
    
    // �������� 32 ����
    for (bit_cnt = 31; bit_cnt >= 0; bit_cnt = bit_cnt - 1) begin
        @(posedge adc_sck_o);
        adc_sdo_i = test_data[bit_cnt];
        $display("  ��� %2d: %d", bit_cnt, adc_sdo_i);
    end
  
    # 20000
    tx_active_i = 1'b1;
    #1000
    tx_active_i = 1'b0;
    
  
    # 20000
    tx_active_i = 1'b1;
    #1000
    tx_active_i = 1'b0;
    
    $display("=== �������� ��������� ===");
    
    #1000000;
    $finish;
end

// ����������
initial begin
    $monitor("�����=%0t | CONV=%b SCK=%b SDO=%b", 
             $time, adc_conv_o, adc_sck_o, adc_sdo_i);
end

endmodule



//`timescale 1 ns / 1 ps

//module tb_adc_pa();

//// ============================================================================
//// ���������
//// ============================================================================
//parameter CLK_PERIOD = 8.333;  // 120 ��� -> ������ 8.333 ��
//parameter SIMULATION_TIME = 100000000; // ����� ��������� � �� (500 ���)

//// ============================================================================
//// ������� ���������
//// ============================================================================
//reg  clk_120_i;          // �������� ������ 120 ���
//wire adc_sck_o;          // ����� ����� ���
//wire adc_conv_o;         // ����� ������� �����������
//reg  adc_sdo_i;          // ���� ������ �� ��� (����������)

//// ============================================================================
//// ������� ������������ ������
//// ============================================================================
//adc_pa dut (
//    .clk_120_i(clk_120_i),
//    .adc_sck_o(adc_sck_o),
//    .adc_conv_o(adc_conv_o),
//    .adc_sdo_i(adc_sdo_i)
//);

//// ============================================================================
//// ��������� ��������� ������� 120 ���
//// ============================================================================
//initial begin
//    clk_120_i = 1'b0;
//    forever #(CLK_PERIOD/2) clk_120_i = ~clk_120_i;
//end

//// ============================================================================
//// ��������� ������ ��� (��������� ������)
//// ============================================================================
//reg  [31:0] test_data;           // �������� ������ ��� ��������
//reg  [4:0]  bit_counter;         // ������� �����
//reg         data_ready;          // ���� ���������� ������
//reg  [31:0] received_data;       // �������� ������ (��� ��������)
//reg         sim_active;          // ���� �������� ���������

//initial begin
//    test_data = 32'h12345678;
//    bit_counter = 5'd0;
//    data_ready = 1'b0;
//    adc_sdo_i = 1'b0;
//    sim_active = 1'b1;
//end

//// ��������� ������ ������ �� ���
//always @(negedge adc_sck_o) begin
//    if (sim_active) begin
//        if (adc_conv_o) begin
//            // ������ ��������� - ���������� �������
//            bit_counter <= 5'd0;
//            data_ready <= 1'b0;
//        end else if (!data_ready) begin
//            // ������ ��������� ���
//            if (bit_counter < 32) begin
//                adc_sdo_i <= test_data[31 - bit_counter];
//                bit_counter <= bit_counter + 1;
//            end else begin
//                data_ready <= 1'b1;
//                adc_sdo_i <= 1'b0;
//            end
//        end
//    end
//end

//// ============================================================================
//// ���������� �������� (����� � �������)
//// ============================================================================
//reg  [31:0] conv_count;
//reg         prev_conv;

//initial begin
//    conv_count = 0;
//    prev_conv = 0;
//end

//always @(posedge clk_120_i) begin
//    // ����������� ������ ���������
//    if (adc_conv_o && !prev_conv) begin
//        conv_count = conv_count + 1;
//        $display("[%0t ns] ADC_CONV start #%0d", $time, conv_count);
//    end
//    prev_conv <= adc_conv_o;
//end

//// ============================================================================
//// �������� ������� ������������
//// ============================================================================
//initial begin
//    $display("========================================");
//    $display("Starting ADC_PA testbench");
//    $display("Clock: 120 MHz (period = %0.3f ns)", CLK_PERIOD);
//    $display("Test data: 0x%h", test_data);
//    $display("========================================");
//    $display("");
    
//    // ���� ��������� ������ ��� ������������
//    repeat(100) @(posedge clk_120_i);
    
//    $display("[%0t ns] Simulation running...", $time);
//    $display("");
    
//    // ���� ��������� ����� ���������
//    #SIMULATION_TIME;
    
//    $display("");
//    $display("========================================");
//    $display("Simulation finished at %0t ns", $time);
//    $display("Total conversions: %0d", conv_count);
//    $display("========================================");
    
//    sim_active = 1'b0;
//    $finish;
//end

//// ============================================================================
//// �������� ������� adc_sck_o (������ ���� 10 ���)
//// ============================================================================
//reg  [31:0] sck_period_count;
//reg         sck_prev;

//initial begin
//    sck_period_count = 0;
//    sck_prev = 0;
//end

//always @(posedge clk_120_i) begin
//    if (adc_sck_o != sck_prev) begin
//        sck_period_count = sck_period_count + 1;
//        sck_prev = adc_sck_o;
//    end
//end

//endmodule








////module tb_adc_pa();

////// ============================================================================
////// ���������
////// ============================================================================
////parameter CLK_PERIOD = 8.333;  // 120 ��� -> ������ 8.333 ��
////parameter SIMULATION_TIME = 500000; // ����� ��������� � �� (500 ���)

////// ============================================================================
////// ������� ���������
////// ============================================================================
////reg  clk_120_i;          // �������� ������ 120 ���
////wire adc_sck_o;          // ����� ����� ���
////wire adc_conv_o;         // ����� ������� �����������
////reg  adc_sdo_i;          // ���� ������ �� ��� (����������)

////// �������� ��� � ������ ��������� ��� � ��������� ����
////`ifndef SYNTHESIS
////// �������� ��� ���������
////module IBUF #(parameter IBUF_LOW_PWR = "TRUE", IOSTANDARD = "LVCMOS33") (
////    input I,
////    output O
////);
////    assign O = I;
////endmodule

////module OBUF #(parameter IOSTANDARD = "LVCMOS33", DRIVE = 12, SLEW = "SLOW") (
////    input I,
////    output O
////);
////    assign O = I;
////endmodule
////`endif


////// ============================================================================
////// ������� ������������ ������
////// ============================================================================
////adc_pa dut (
////    .clk_120_i(clk_120_i),
////    .adc_sck_o(adc_sck_o),
////    .adc_conv_o(adc_conv_o),
////    .adc_sdo_i(adc_sdo_i)
////);

////// ============================================================================
////// ��������� ��������� ������� 120 ���
////// ============================================================================
////initial begin
////    clk_120_i = 1'b0;
////    forever #(CLK_PERIOD/2) clk_120_i = ~clk_120_i;
////end

////// ============================================================================
////// ��������� ������ ��� (��������� ������)
////// ============================================================================
////// ���������� ����� ���: ������ ���� adc_sck_o ������ ��� ������
////// ��� �������: ���������� �������� ������������������ 0x12345678

////reg  [31:0] test_data;           // �������� ������ ��� ��������
////reg  [4:0]  bit_counter;         // ������� �����
////reg         data_ready;          // ���� ���������� ������
////reg  [31:0] received_data;       // �������� ������ (��� ��������)

////always @(posedge adc_sck_o or negedge clk_120_i) begin
////    // ��������� ������ ������ �� ��� �� ����� ����� (��� � �������� ���)
////    if (adc_conv_o) begin
////        // ������ ��������� - ���������� �������
////        bit_counter <= 5'd0;
////        data_ready <= 1'b0;
////    end else if (adc_sck_o == 1'b0 && !data_ready) begin
////        // �� ����� ����� ������ ��������� ���
////        if (bit_counter < 32) begin
////            adc_sdo_i <= test_data[31 - bit_counter];
////            bit_counter <= bit_counter + 1;
////        end else begin
////            data_ready <= 1'b1;
////            adc_sdo_i <= 1'b0;
////        end
////    end
////end

////// ============================================================================
////// ���������� �������� (����� � �������)
////// ============================================================================
////reg  [31:0] conv_count;
////reg         prev_conv;

////initial begin
////    conv_count = 0;
////    prev_conv = 0;
////end

////always @(posedge clk_120_i) begin
////    // ����������� ������ ���������
////    if (adc_conv_o && !prev_conv) begin
////        conv_count = conv_count + 1;
////        $display("[%0t ns] ADC_CONV start #%0d", $time, conv_count);
////    end
////    prev_conv = adc_conv_o;
////end

////// ============================================================================
////// �������� ������� ������������
////// ============================================================================
////initial begin
////    // �������������
////    adc_sdo_i = 1'b0;
////    test_data = 32'h12345678;  // �������� ������
    
////    $display("========================================");
////    $display("Starting ADC_PA testbench");
////    $display("Clock: 120 MHz (period = %0.3f ns)", CLK_PERIOD);
////    $display("Test data: 0x%h", test_data);
////    $display("========================================");
////    $display("");
    
////    // ���� ��������� ������ ��� ������������
////    repeat(100) @(posedge clk_120_i);
    
////    $display("[%0t ns] Simulation running...", $time);
////    $display("");
    
////    // ���� ��������� ����� ���������
////    #SIMULATION_TIME;
    
////    $display("");
////    $display("========================================");
////    $display("Simulation finished at %0t ns", $time);
////    $display("Total conversions: %0d", conv_count);
////    $display("========================================");
    
////    $finish;
////end

////// ============================================================================
////// ��������� ��������� ��� ��������� � Vivado Waveform
////// ============================================================================
////// ��������� �������������� ������� ��� �����������
////reg [16:0] delay_counter_sim;
////reg [5:0]  measurement_counter_sim;
////reg [1:0]  state_sim;

////// ���������� ���������� ������� ��� ���������� (������ ��� ���������)
////// � Vivado ��� ����� ������� ����� ���� Waveform

////// ============================================================================
////// �������� ������� adc_sck_o (������ ���� 10 ���)
////// ============================================================================
////reg  [31:0] sck_period_count;
////reg         sck_prev;
////real        sck_frequency;

////initial begin
////    sck_period_count = 0;
////    sck_prev = 0;
////end

////always @(posedge clk_120_i) begin
////    if (adc_sck_o != sck_prev) begin
////        sck_period_count = sck_period_count + 1;
////        sck_prev = adc_sck_o;
////    end
////end

////// ============================================================================
////// �������������� �������� (assertions)
////// ============================================================================

////// ��������, ��� adc_sck_o �������������
////property sck_toggles;
//////    @(posedge clk_120_i) $stable(adc_sck_o) |=> ##[1:100] !$stable(adc_sck_o);
//////endproperty

//////// ��������, ��� adc_conv_o �� ������ ����� 1 �����
//////property conv_pulse_width;
//////    @(posedge clk_120_i) $rose(adc_conv_o) |=> ##1 $fell(adc_conv_o);
//////endproperty

//////// ��������, ��� ����� adc_conv_o ������� 32 ���� ������
//////property data_bits_count;
//////    @(posedge clk_120_i) $rose(adc_conv_o) |=> ##[32:32] (!adc_conv_o);
//////endproperty

////endmodule