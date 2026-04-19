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

    fnd_controller U_FND_CTRL (
        .clk(clk), 
        .reset(reset),
        .spi_rx_data(w_rx_data), 
        .spi_rx_done(w_rx_done),
        .fnd_digit(fnd_digit), 
        .fnd_data(fnd_data)
    );
endmodule
