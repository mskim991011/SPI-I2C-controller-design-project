module slave_board (
    input  logic       clk, reset,
    input  logic       sclk_p, 
    input  logic       mosi_p, 
    input  logic       cs_n_p, 
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);
    wire [7:0] w_rx_data;
    wire       w_rx_done;

    spi_slave_rx U_SLAVE (
        .clk(clk), 
        .reset(reset),
        .sclk_i(sclk_p), 
        .mosi_i(mosi_p), 
        .cs_n_i(cs_n_p),
        .rx_data(w_rx_data), 
        .rx_done(w_rx_done)
    );
endmodule

module spi_slave_rx (
    input  logic       clk,      
    input  logic       reset,    
    input  logic       sclk_i,  
    input  logic       mosi_i,  
    input  logic       cs_n_i,  
    output logic [7:0] rx_data,  
    output logic       rx_done   
);

    
    logic [2:0] sclk_ff;
    logic [1:0] mosi_ff, cs_n_ff;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sclk_ff <= 3'b000; 
            mosi_ff <= 2'b00; 
            cs_n_ff <= 2'b11;
        end else begin
            sclk_ff <= {sclk_ff[1:0], sclk_i};
            mosi_ff <= {mosi_ff[0], mosi_i};
            cs_n_ff <= {cs_n_ff[0], cs_n_i};
        end
    end

    wire sclk_rise = (sclk_ff[2] == 1'b0 && sclk_ff[1] == 1'b1);

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            bit_cnt <= 0; 
            shift_reg <= 0; 
            rx_done <= 1'b0; 
            rx_data <= 0;
        end else if (cs_n_ff[1]) begin 
            bit_cnt <= 0; 
            rx_done <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            if (sclk_rise) begin
                shift_reg <= {shift_reg[6:0], mosi_ff[1]};
                if (bit_cnt == 7) begin
                    bit_cnt <= 0;
                    rx_data <= {shift_reg[6:0], mosi_ff[1]};
                    rx_done <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end
endmodule