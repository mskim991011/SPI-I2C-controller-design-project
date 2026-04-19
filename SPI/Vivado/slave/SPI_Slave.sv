`timescale 1ns / 1ps

module spi_slave_rx (
    input  logic       clk,      
    input  logic       reset,    
    input  logic       sclk_i,  
    input  logic       mosi_i,  
    input  logic       cs_n_i,
    input  logic [7:0] tx_data_i,  
    output logic [7:0] rx_data,  
    output logic       rx_done,
    output logic       miso_o   
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
    assign miso_o = shift_reg[7];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            bit_cnt <= 0; 
            shift_reg <= 0; 
            rx_done <= 1'b0; 
            rx_data <= 0;
        end else if (cs_n_ff[1]) begin 
            shift_reg <= tx_data_i;
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
