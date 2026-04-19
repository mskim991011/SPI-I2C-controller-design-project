module fnd_controller (
    input  logic       clk,         
    input  logic       reset,        
    input  logic [7:0] spi_rx_data,   
    input  logic       spi_rx_done,   
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
        end else if (spi_rx_done) begin
            r_digit_1000 <= {2'b00, spi_rx_data[7:6]}; 
            r_digit_100  <= {2'b00, spi_rx_data[5:4]}; 
            r_digit_10   <= {2'b00, spi_rx_data[3:2]}; 
            r_digit_1    <= {2'b00, spi_rx_data[1:0]}; 
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