module board_a_top (
    input  logic       clk,       
    input  logic       reset,     
    input  logic [7:0] sw,         
    input  logic       btn_start,  
    output logic       sclk_p,
    output logic       mosi_p,
    output logic       cs_n_p
);

    wire w_start_pulse;
    wire [7:0] w_dummy_rx; 
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
        .miso(1'b0),          
        
        // to board B
        .sclk(sclk_p),
        .mosi(mosi_p),
        .cs_n(cs_n_p),
        
        //dummy data
        .rx_data(w_dummy_rx),
        .done(w_dummy_done),
        .busy(w_dummy_busy)
    );

endmodule

module SPI_Master (
    input  logic       clk,
    input  logic       reset,
    input  logic       cpol,     //IDLE    0: log 1:high
    input  logic       cpha,     //first sample 0:first edge  1: second edge 
    input  logic [7:0] clk_div,
    input  logic [7:0] tx_data,
    input  logic       start,
    input  logic       miso,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy,
    output logic       sclk,
    output logic       mosi,
    output logic       cs_n
);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;
    logic [7:0] div_cnt, tx_shift_reg, rx_shift_reg;
    logic half_tick;
    logic [2:0] bit_cnt;
    logic step;
    logic sclk_r;

    assign sclk = sclk_r;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state == DATA) begin
                if (div_cnt == clk_div) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end else begin
                div_cnt   <= 0;
                half_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            mosi <= 1'b1;
            cs_n <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt <= 0;
            step <= 1'b0;
            rx_data <= 0;
            sclk_r <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mosi   <= 1'b1;
                    cs_n   <= 1'b1;
                    sclk_r <= cpol;
                    step   <= 1'b0;
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= 0;
                        step <= 1'b0;
                        busy <= 1'b1;
                        cs_n <= 1'b0;
                        state <= START;
                    end
                end
                START: begin
                    if (!cpha) begin
                        mosi <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                    state <= DATA;
                end
                DATA: begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (step == 0) begin
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end else begin
                                mosi <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                        end else begin
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 7) begin
                                    mosi <= tx_shift_reg[7];
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end
                            if (bit_cnt == 7) begin
                                state   <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;
                                end else begin
                                    rx_data <= {rx_shift_reg[6:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                STOP: begin
                    sclk_r <= cpol;
                    cs_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule