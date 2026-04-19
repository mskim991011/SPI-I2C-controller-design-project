module slave_board (
    input  logic       clk, reset,
    input  logic       btn_l,
    input  logic       sclk_p, 
    input  logic       mosi_p, 
    input  logic       cs_n_p, 
    output logic       miso_p,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);
    logic [7:0] w_rx_data;
    logic      w_rx_done;
    logic [7:0] r_tx_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tx_data <= 8'h00;
        end else if (btn_l) begin
            r_tx_data <= w_rx_data; 
        end
    end

    spi_slave_rx U_SLAVE (
        .clk(clk), 
        .reset(reset),
        .sclk_i(sclk_p), 
        .mosi_i(mosi_p),
        .tx_data_i(r_tx_data), 
        .miso_o(miso_p),
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
