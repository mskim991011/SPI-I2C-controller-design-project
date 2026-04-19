module top_master (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] sw,
    input  logic       btn_write,
    input  logic       btn_read,
    output logic [7:0] led,
    output logic       scl,
    inout  wire        sda
);


    localparam SLA_W = {7'h12, 1'b0};
    localparam SLA_R = {7'h12, 1'b1};

    logic cmd_start, cmd_write, cmd_read, cmd_stop;
    logic [7:0] tx_data, rx_data;
    logic done, busy;
    logic ack_i;
    logic ack_o;


    master_board U_I2C_MASTER (
        .clk(clk),
        .reset(reset),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .cmd_stop(cmd_stop),
        .tx_data(tx_data),
        .ack_i(ack_i),
        .rx_data(rx_data),
        .done(done),
        .busy(busy),
        .scl(scl),
        .sda(sda),
        .ack_o(ack_o)
    );


    logic bw_d1, bw_d2, br_d1, br_d2;
    always_ff @(posedge clk) begin
        if (reset) begin
            bw_d1 <= 0;
            bw_d2 <= 0;
            br_d1 <= 0;
            br_d2 <= 0;
        end else begin
            bw_d1 <= btn_write;
            bw_d2 <= bw_d1;
            br_d1 <= btn_read;
            br_d2 <= br_d1;
        end
    end
    wire bw_edge = bw_d1 & ~bw_d2;
    wire br_edge = br_d1 & ~br_d2;


    typedef enum logic [3:0] {
        IDLE,
        W_START,
        W_ADDR,
        W_DATA,
        W_STOP,
        R_START,
        R_ADDR,
        R_DATA,
        R_STOP
    } state_e;
    state_e state;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            {cmd_start, cmd_write, cmd_read, cmd_stop} <= 4'b0000;
            ack_i <= 1'b1;
            led <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    {cmd_start, cmd_write, cmd_read, cmd_stop} <= 4'b0000;
                    if (!busy) begin
                        if (bw_edge) state <= W_START;
                        else if (br_edge) state <= R_START;
                    end
                end


                W_START: begin
                    cmd_start <= 1;
                    if (done) state <= W_ADDR;
                end
                W_ADDR: begin
                    cmd_start <= 0;
                    cmd_write <= 1;
                    tx_data   <= SLA_W;
                    if (done) state <= W_DATA;
                end
                W_DATA: begin
                    cmd_write <= 1;
                    tx_data   <= sw;
                    if (done) state <= W_STOP;
                end
                W_STOP: begin
                    cmd_write <= 0;
                    cmd_stop  <= 1;
                    if (done) state <= IDLE;
                end


                R_START: begin
                    cmd_start <= 1;
                    if (done) state <= R_ADDR;
                end
                R_ADDR: begin
                    cmd_start <= 0;
                    cmd_write <= 1;
                    tx_data   <= SLA_R;
                    if (done) state <= R_DATA;
                end
                R_DATA: begin
                    cmd_write <= 0;
                    cmd_read <= 1;
                    ack_i <= 1'b1;
                    if (done) begin
                        led   <= rx_data;
                        state <= R_STOP;
                    end
                end
                R_STOP: begin
                    cmd_read <= 0;
                    cmd_stop <= 1;
                    if (done) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
