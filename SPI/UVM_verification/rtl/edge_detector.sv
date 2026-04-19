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