`timescale 1ns / 1ps

module fnd_controller (
    input  logic       clk,         
    input  logic       reset,        
    input  logic [7:0] i2c_rx_data,   
    input  logic       i2c_rx_done,   
    output logic [3:0] fnd_digit,  
    output logic [7:0] fnd_data      
);

    
    logic [1:0] w_digit_sel;
    logic [3:0] w_mux_out;
    logic       w_1khz;
    logic [3:0] r_digit_1, r_digit_10, r_digit_100, r_digit_1000;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_digit_1    <= 4'd0;
            r_digit_10   <= 4'd0;
            r_digit_100  <= 4'd0;
            r_digit_1000 <= 4'd0;
        end else if (i2c_rx_done) begin
            r_digit_1000 <= {2'b00, i2c_rx_data[7:6]}; 
            r_digit_100  <= {2'b00, i2c_rx_data[5:4]}; 
            r_digit_10   <= {2'b00, i2c_rx_data[3:2]}; 
            r_digit_1    <= {2'b00, i2c_rx_data[1:0]}; 
        end
    end

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_MUX_4x1 (
        .sel(w_digit_sel),
        .digit_1(r_digit_1),
        .digit_10(r_digit_10),
        .digit_100(r_digit_100),
        .digit_1000(r_digit_1000),
        .mux_out(w_mux_out)
    );
    bcd U_BCD (
        .bcd(w_mux_out),
        .fnd_data(fnd_data)
    );
endmodule


module clk_div (
    input  logic clk, reset,
    output logic o_1khz
);
    logic [16:0] counter_r;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else if (counter_r == 99_999) begin
            counter_r <= 0;
            o_1khz    <= 1'b1;
        end else begin
            counter_r <= counter_r + 1;
            o_1khz    <= 1'b0;
        end
    end
endmodule

module counter_4 (
    input  logic clk, reset,
    output logic [1:0] digit_sel
);
    logic [1:0] counter_r;
    assign digit_sel = counter_r;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) counter_r <= 0;
        else       counter_r <= counter_r + 1;
    end
endmodule

module decoder_2x4 (
    input  logic [1:0] digit_sel,
    output logic [3:0] fnd_digit
);
    always_comb begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
            default: fnd_digit = 4'b1111;
        endcase
    end
endmodule

module mux_4x1 (
    input  logic [1:0] sel,
    input  logic [3:0] digit_1, digit_10, digit_100, digit_1000,
    output logic [3:0] mux_out
);
    always_comb begin
        case (sel)
            2'b00: mux_out = digit_1;
            2'b01: mux_out = digit_10;
            2'b10: mux_out = digit_100;
            2'b11: mux_out = digit_1000;
            default: mux_out = 4'b0000;
        endcase
    end
endmodule

module bcd (
    input  logic [3:0] bcd,
    output logic [7:0] fnd_data 
);
    always_comb begin
        case (bcd)
            4'd0:    fnd_data = 8'hC0; // '0'
            4'd1:    fnd_data = 8'hF9; // '1'
            4'd2:    fnd_data = 8'hA4; // '2'
            4'd3:    fnd_data = 8'hB0; // '3'
            default: fnd_data = 8'hFF; 
        endcase
    end
endmodule