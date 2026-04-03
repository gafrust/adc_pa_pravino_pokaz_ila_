`timescale 1 ns/1 ps

module adc_pa(
    input clk_120_i,
    input tx_active_i,
    (* IOB = "TRUE" *) output reg adc_sck_o,
    (* IOB = "TRUE" *) output reg adc_conv_o,
    input adc_sdo_i
);

// ������� ������� � IOB (������ ���� ����� ����� �����)
(* IOB = "TRUE" *) reg adc_sdo_ibuf;

wire rst_i;
reg tx_active_ibuf;
reg tx_active_ibuf_prev;
wire tx_active_rise;
reg [3:0] adc_sck_counter;
reg adc_sck_reg;
reg adc_sck_reg_prev;  // ��� �������� ������ SCK
reg adc_conv_reg;
RES RES(
    .clk(clk_120_i),
    .rst(rst_i)
);

// ============================================================================
// ������ �������� ������� � �������� ��������
// ============================================================================
always @(posedge clk_120_i or posedge rst_i) begin
    if(rst_i) begin
        adc_sck_counter <= 4'd0;
        adc_sck_reg <= 1'b0;
        adc_conv_o <= 1'b0;
        adc_sck_o <= 1'b0;
        adc_sck_reg_prev <= 1'b0;
        tx_active_ibuf <= 1'b0;
        tx_active_ibuf_prev <= 1'b0;
    end else begin
        adc_sck_counter <= adc_sck_counter + 1;
        adc_conv_o <= adc_conv_reg;
        adc_sck_o <= adc_sck_reg;
        adc_sck_reg_prev <= adc_sck_reg;
        tx_active_ibuf_prev <= tx_active_ibuf;
        
        if(adc_sck_counter == 4'd5) begin
            adc_sck_counter <= 4'h0;
            adc_sck_reg <= ~adc_sck_reg;
        end
    end
end

assign tx_active_rise = tx_active_ibuf && !tx_active_ibuf_prev;

// ============================================================================
// ������� ������� IOB (��������� always-���� ��� �������)
// ============================================================================
always @(posedge clk_120_i or posedge rst_i) begin
    if(rst_i) begin
        adc_sdo_ibuf <= 1'b0;
        tx_active_ibuf <= 1'b0;
    end else begin
        adc_sdo_ibuf <= adc_sdo_i;
        tx_active_ibuf <= tx_active_i;
    end
end

// ============================================================================
// ������ �������� � ������� ���������
// ============================================================================
reg [16:0] delay_counter;
reg [8:0]  measurement_counter;
reg [31:0] sum_u_pad;
reg [5:0]  sum_u_otr;

reg adc_sdo_sync_reg1;
reg adc_sdo_sync_reg2;
wire adc_sdo_sync;
reg [1:0] state;
reg [4:0] samples_cnt;


// �������� ��� ���������� ��������
reg [13:0] shift_reg_ch0;     // 14-������ ��������� ������� ��� ������ 0
reg [13:0] shift_reg_ch1;     // 14-������ ��������� ������� ��� ������ 1
reg [5:0]  bit_counter;        // ������� ����� (0-31)
reg        data_valid_ch0;     // ���� ���������� ������ 0
reg        data_valid_ch1;     // ���� ���������� ������ 1
reg  [13:0] adc_data_ch0;       // ������ ������ 0 (�������������� ���)
reg  [13:0] adc_data_ch1;       // ������ ������ 1 (�������������� ���)
reg        data_ready;         // ���� ���������� ����� ������
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
        samples_cnt          <=5'd31;
    end else begin
        case (state)
           IDLE: begin
              delay_counter <= 17'd200;
           if (tx_active_ibuf && (samples_cnt!=0)/*tx_active_rise*//*tx_active_ibuf ==1 && ~tx_active_ibuf_prev ==0*/)
              //samples_cnt <= 5'd31;
             // begin if(tx_active_rise && (samples_cnt!=0))
              state <= DELAY;
            else  
              state <= IDLE;
              end
           // end
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
                           if (samples_cnt != 0)
                          samples_cnt <= samples_cnt - 1;
                          state <= IDLE;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// ============================================================================
// ������������� �������� ������� (������ �� ����������������)
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
// ��������� ������� ��� ����� ������ ���
// ============================================================================
// ��������:
// 1. ������� ����� ������� �� 0 �� 31 (32 ���� �� ����)
// 2. ��� 0-13: ����� 0, ��� 14-27: ����� 1, ��� 28-31: �����
// 3. ���� ���������� ����� 3-�� ����� SCK ����� CONV
// 4. �� ��������� ������ SCK ����������� ��� � SDO
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
        // ����� ����� ���������� ������ (�� ������� ������ 1 ����)
        data_ready <= 1'b0;
      
        
        // ���������, ��� �� � ������ ���������
        if (state == MEASURE) begin
            // ����� �������� ����� SCK (adc_sck_reg �������� � 0 �� 1)
            if (adc_sck_reg == 1'b1 && adc_sck_reg_prev == 1'b0) begin
                
                // ========== ������ ����� ����� ==========
                // ��������� ������ ���� ����� (����� ���������)
                if (bit_counter < 6'd1) begin
                    shift_reg_ch0 <= 14'd0;  // ����� �������� ������ 0
                end else if (bit_counter < 6'd17) begin
                    // ��� ��� ������ 0 (���� 2-15)
                    shift_reg_ch0 <= {shift_reg_ch0[12:0], adc_sdo_sync};
                end else if (bit_counter < 6'd19) begin
                    shift_reg_ch1 <= 14'd0;  // ����� �������� ������ 1
                end else if (bit_counter < 6'd33) begin
                    // ��� ��� ������ 1 (���� 18-31)
                    shift_reg_ch1 <= {shift_reg_ch1[12:0], adc_sdo_sync};
                end
                // ���� 32-33 ���������� (�����)
                
                // ����������� ������� �����
                bit_counter <= bit_counter + 1'b1;
                
                // ========== �������� ���������� ������ ==========
                // ����� ������� 14 ��� ��� ������ 0 (��� 15 - ��������� 14-� ���)
                if (bit_counter == 6'd17) begin
                    data_valid_ch0 <= 1'b1;
                    adc_data_ch0 <= shift_reg_ch0;
                end
                
                // ����� ������� 14 ��� ��� ������ 1 (��� 31 - ��������� 14-� ���)
                if (bit_counter == 6'd33) begin
                    data_valid_ch1 <= 1'b1;
                    adc_data_ch1 <= shift_reg_ch1;
                end
                
                // ����� ������� ������ ���� (32 ����, ������� ������� �� 32)
                if (bit_counter == 6'd34) begin
                    // �������������, ��� ������ ������
                    data_ready <= 1'b1;
                    // ���������� ������� ��� ���������� �����
                    bit_counter <= 6'd0;
                end
                
            end  // if (adc_sck_reg == 1'b1 && adc_sck_reg_prev == 1'b0)
        end else begin
            // ���� �� � ������ ���������, ���������� ��������
            bit_counter <= 6'd0;
            data_valid_ch0 <= 1'b0;
            data_valid_ch1 <= 1'b0;
        end  // if (state == MEASURE)
    end  // else (�� rst)
end  // always
 //============================================================================
 //ILA (Integrated Logic Analyzer) - ������ ��� �������
 //============================================================================
`ifdef SYNTHESIS
    ila_0 ila_inst (
        .clk(clk_120_i),
        .probe0(adc_sck_counter),
        .probe1(adc_sck_reg),
        .probe2(delay_counter),
        .probe3(measurement_counter),
        .probe4(state),
        .probe5(adc_conv_reg),
        .probe6(bit_counter),
        .probe7(adc_sck_reg),
        .probe8(adc_sdo_sync),
        .probe9(adc_sdo_ibuf),
        .probe10(data_valid_ch0),
        .probe11(adc_data_ch0),
        .probe12(data_valid_ch1),
        .probe13(adc_data_ch1)
    );
`endif

endmodule





    
//endmodule /* adc_pa */
