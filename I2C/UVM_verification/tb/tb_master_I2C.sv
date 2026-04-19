`include "uvm_macros.svh"
import uvm_pkg::*;


interface i2c_if(input logic clk);
    logic reset;
    logic cmd_start, cmd_write, cmd_read, cmd_stop;
    logic [7:0] tx_data;
    logic ack_i;
    logic [7:0] rx_data;
    logic done, busy, ack_o;

    tri1 scl; 
    tri1 sda;


    logic sda_out;
    logic sda_en;
    assign sda = (sda_en && sda_out == 1'b0) ? 1'b0 : 1'bz;
endinterface


class i2c_seq_item extends uvm_sequence_item;
    rand bit [7:0] tx_data; 
    bit [7:0]      rx_data; 

    `uvm_object_utils_begin(i2c_seq_item)
        `uvm_field_int(tx_data, UVM_ALL_ON)
        `uvm_field_int(rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_seq_item"); super.new(name); endfunction
endclass


class i2c_slave_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_slave_seq)
    function new(string name="i2c_slave_seq"); super.new(name); endfunction

    virtual task body();
        forever begin
            req = i2c_seq_item::type_id::create("req");
            start_item(req);
            finish_item(req);
        end
    endtask
endclass


class i2c_slave_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_slave_driver)
    virtual i2c_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.sda_en <= 0;
        vif.sda_out <= 0;
        
        forever begin
            seq_item_port.get_next_item(req);

            
            wait(vif.scl === 1'b1);
            @(negedge vif.sda);

            
            repeat(8) @(posedge vif.scl);

            
            @(negedge vif.scl);
            vif.sda_en <= 1'b1; vif.sda_out <= 1'b0;
            @(negedge vif.scl);
            vif.sda_en <= 1'b0;


            repeat(8) @(posedge vif.scl);

            
            @(negedge vif.scl);
            vif.sda_en <= 1'b1; vif.sda_out <= 1'b0;
            @(negedge vif.scl);
            vif.sda_en <= 1'b0;


            wait(vif.scl === 1'b1);
            @(posedge vif.sda);

            seq_item_port.item_done();
        end
    endtask
endclass


class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)
    virtual i2c_if vif;
    uvm_analysis_port #(i2c_seq_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2c_seq_item item;
        forever begin
            
            wait(vif.scl === 1'b1);
            @(negedge vif.sda);


            repeat(9) @(posedge vif.scl);

            item = i2c_seq_item::type_id::create("item");

            for(int i=7; i>=0; i--) begin
                @(posedge vif.scl);
                if (i == 7) item.tx_data = vif.tx_data;     
                #1; 
                item.rx_data[i] = vif.sda;
            end

            @(posedge vif.scl);

            wait(vif.scl === 1'b1);
            @(posedge vif.sda);

            mon_ap.write(item);
        end
    endtask
endclass


class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)
    uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) mon_export;
    int pass_cnt = 0, fail_cnt = 0;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_export = new("mon_export", this);
    endfunction

    function void write(i2c_seq_item item);
        if (item.tx_data !== item.rx_data) begin
            fail_cnt++;
            `uvm_error("SCB_MISMATCH", $sformatf("Mismatch! Expected=0x%h, Actual=0x%h", item.tx_data, item.rx_data))
        end else begin
            pass_cnt++;
            `uvm_info("SCB_MATCH", $sformatf("Match Success! Data=0x%h", item.rx_data), UVM_MEDIUM)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), "       I2C Master Scoreboard Summary      ", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MATCH    : %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MISMATCH : %0d", fail_cnt), UVM_LOW)
        if (fail_cnt > 0) `uvm_error("STATUS", "TEST FAILED!")
        else `uvm_info("STATUS", "TEST PASSED!!!!", UVM_LOW)
    endfunction
endclass


class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)
    i2c_slave_driver drv;
    i2c_monitor mon;
    uvm_sequencer #(i2c_seq_item) sqr;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = i2c_slave_driver::type_id::create("drv", this);
        mon = i2c_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("sqr", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)
    i2c_agent agt;
    i2c_scoreboard scb;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = i2c_agent::type_id::create("agt", this);
        scb = i2c_scoreboard::type_id::create("scb", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        agt.mon.mon_ap.connect(scb.mon_export);
    endfunction
endclass


class i2c_master_test extends uvm_test;
    `uvm_component_utils(i2c_master_test)
    i2c_env env;
    virtual i2c_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = i2c_env::type_id::create("env", this);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2c_slave_seq slave_seq;
        bit [7:0] rand_data;
        
        phase.raise_objection(this);

   
        vif.cmd_start <= 0; vif.cmd_write <= 0; vif.cmd_stop <= 0; vif.ack_i <= 1;
        vif.reset <= 1'b1; #20;
        vif.reset <= 1'b0; #20;

       
        slave_seq = i2c_slave_seq::type_id::create("slave_seq");
        fork
            slave_seq.start(env.agt.sqr);
        join_none

     
        // 50번 반복 테스트
        for (int i = 0; i < 50; i++) begin
            rand_data = $urandom;
            `uvm_info("TEST", $sformatf("=== [task %0d] Master TX Start: 8'h%0h ===", i+1, rand_data), UVM_LOW)

            @(posedge vif.clk); #1; 
            vif.cmd_start = 1'b1;
            @(posedge vif.clk); #1; 
            vif.cmd_start = 1'b0;
            @(posedge vif.done);
            repeat(2) @(posedge vif.clk); 
            @(posedge vif.clk); #1; 
            vif.tx_data = 8'h24; 
            vif.cmd_write = 1'b1;
            @(posedge vif.clk); #1; 
            vif.cmd_write = 1'b0;
            @(posedge vif.done);
            repeat(2) @(posedge vif.clk); 
            @(posedge vif.clk); #1; 
            vif.tx_data = rand_data; 
            vif.cmd_write = 1'b1;
            @(posedge vif.clk); #1; 
            vif.cmd_write = 1'b0;       
            @(posedge vif.done);
            repeat(2) @(posedge vif.clk); 
            @(posedge vif.clk); #1; 
            vif.cmd_stop = 1'b1;
            @(posedge vif.clk); #1; 
            vif.cmd_stop = 1'b0;          
            @(posedge vif.done);
            #200;
        end

        #1000;
        phase.drop_objection(this);
    endtask
endclass


module tb_top;
    logic clk;
    initial begin clk = 0; forever #5 clk = ~clk; end 

    i2c_if vif(clk);

    master_board DUT (
        .clk(vif.clk), .reset(vif.reset),
        .cmd_start(vif.cmd_start), .cmd_write(vif.cmd_write),
        .cmd_read(vif.cmd_read), .cmd_stop(vif.cmd_stop),
        .tx_data(vif.tx_data), .ack_i(vif.ack_i),
        .rx_data(vif.rx_data), .done(vif.done),
        .ack_o(vif.ack_o), .busy(vif.busy),
        .scl(vif.scl), .sda(vif.sda)
    );

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "*", "vif", vif);
        run_test("i2c_master_test");
    end

    initial begin
        $fsdbDumpfile("dump_i2c_master.fsdb");
        $fsdbDumpvars(0, tb_top);
    end
endmodule