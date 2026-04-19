module top_slave_board (
    input  logic       clk,
    input  logic       reset,
    input  logic       scl,
    inout  wire        sda,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    logic [7:0] tx_data_reg;
    assign tx_data_reg = 8'hA5;


    i2c_slave U_I2C_SLAVE (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .tx_data(tx_data_reg), 
        .rx_data(rx_data),    
        .rx_done(rx_done)      
    );

endmodule


module i2c_slave (
    input  logic       clk,
    input  logic       reset,
    input  logic       scl,
    inout  wire        sda,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    localparam SLAVE_ADDR = 7'h12;


    logic [2:0] scl_ff, sda_ff;
    always_ff @(posedge clk) begin
        scl_ff <= {scl_ff[1:0], scl};
        sda_ff <= {sda_ff[1:0], sda};
    end

    wire scl_rise = (scl_ff[2:1] == 2'b01);
    wire scl_fall = (scl_ff[2:1] == 2'b10);
    wire sda_fall = (sda_ff[2:1] == 2'b10);
    wire sda_rise = (sda_ff[2:1] == 2'b01);
    wire scl_high = (scl_ff[1] == 1'b1);


    wire start_cond = scl_high & sda_fall;
    wire stop_cond = scl_high & sda_rise;

    typedef enum logic [2:0] {
        IDLE,
        ADDR,
        ACK_ADDR,
        W_DATA,
        ACK_W,
        R_DATA,
        ACK_R
    } state_e;
    state_e state;

    logic [7:0] shift_reg;
    logic [3:0] bit_cnt;
    logic sda_out, sda_en;


    assign sda = (sda_en && (sda_out == 1'b0)) ? 1'b0 : 1'bz;
    wire sda_in = sda_ff[1];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            rx_data <= 0;
            rx_done <= 0;
            sda_en <= 0;
            sda_out <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
        end else begin
            rx_done <= 1'b0;


            if (start_cond) begin
                state   <= ADDR;
                bit_cnt <= 0;
                sda_en  <= 0;
            end else if (stop_cond) begin
                state  <= IDLE;
                sda_en <= 0;
            end else begin
                case (state)
                    IDLE: sda_en <= 0;


                    ADDR: begin
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                            bit_cnt   <= bit_cnt + 1;
                        end else if (scl_fall && bit_cnt == 4'd8) begin
                            if (shift_reg[7:1] == SLAVE_ADDR) begin
                                state   <= ACK_ADDR;
                                sda_en  <= 1;
                                sda_out <= 0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end


                    ACK_ADDR: begin
                        if (scl_fall) begin
                            if (shift_reg[0] == 1'b0) begin
                                state  <= W_DATA;
                                sda_en <= 0;
                            end else begin
                                state <= R_DATA;
                                shift_reg <= tx_data;
                                sda_en <= 1;
                                sda_out <= tx_data[7];
                            end
                            bit_cnt <= 0;
                        end
                    end


                    W_DATA: begin
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                        end else if (scl_fall) begin 
                                    if (bit_cnt == 4'd7) begin 
                                        state   <= ACK_W;
                                        sda_en  <= 1;
                                        sda_out <= 0;
                                        rx_data <= shift_reg;
                                        rx_done <= 1'b1;
                                        bit_cnt <= 0;
                                    end else begin
                                        bit_cnt <= bit_cnt + 1;
                                    end
                            end
                        end

                    ACK_W: begin
                        if (scl_fall) begin
                            state  <= IDLE;
                            sda_en <= 0;
                        end
                    end

                    R_DATA: begin
                        if (scl_fall) begin
                            if (bit_cnt == 4'd8) begin 
                                state  <= ACK_R;
                                sda_en <= 0;
                            end else begin
                                shift_reg <= {shift_reg[6:0], 1'b0};
                                sda_out   <= shift_reg[6];
                                bit_cnt   <= bit_cnt + 1;
                            end
                        end
                    end

                    ACK_R: begin
                        if (scl_fall) begin
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end
endmodule


