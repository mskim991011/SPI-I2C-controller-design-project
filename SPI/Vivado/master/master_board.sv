`timescale 1ns / 1ps

module board_a_top (
    input  logic       clk,       
    input  logic       reset,     
    input  logic [7:0] sw,         
    input  logic       btn_start,  
    input  logic       miso_p,
    output logic       sclk_p,
    output logic       mosi_p,
    output logic       cs_n_p,
    output logic [3:0] fnd_digit, 
    output logic [7:0] fnd_data
);

    wire w_start_pulse, w_done;
    wire [7:0] w_rx_data; 
    wire w_dummy_done, w_dummy_busy;


    btn_edge_detector U_BTN (
        .clk(clk),
        .reset(reset),
        .btn_in(btn_start),
        .btn_out(w_start_pulse)
    );
    SPI_Master U_MASTER (
        .clk(clk),
        .reset(reset),
        .cpol(1'b0),         
        .cpha(1'b0),          
        .clk_div(8'd50),      
        .tx_data(sw),        
        .start(w_start_pulse),
        .miso(miso_p),
       
        
        // to board B
        .sclk(sclk_p),
        .mosi(mosi_p),
        .cs_n(cs_n_p),
        
        //dummy data
        .rx_data(w_rx_data),
        .done(w_done),
        .busy(w_dummy_busy)
    );
    fnd_controller U_FND_A (
        .clk(clk), .reset(reset),
        .spi_rx_data(w_rx_data),
        .spi_rx_done(w_done),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule


module btn_edge_detector (
    input  logic clk,
    input  logic reset,
    input  logic btn_in,     
    output logic btn_out  
);
    logic [1:0] btn_ff;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_ff <= 2'b00;
        end else begin          
            btn_ff <= {btn_ff[0], btn_in};
        end
    end


    assign btn_out = (~btn_ff[1] & btn_ff[0]);

endmodule