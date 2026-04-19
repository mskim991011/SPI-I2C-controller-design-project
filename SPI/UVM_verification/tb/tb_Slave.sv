`include "uvm_macros.svh"
import uvm_pkg::*;

interface slave_if(input logic clk);
    logic reset;
    logic sclk;
    logic mosi;
    logic cs_n;
    logic [7:0] rx_data;
    logic rx_done;
endinterface


class slave_item extends uvm_sequence_item;
    rand bit [7:0] data_sent;     
    bit [7:0]      data_received; 

    `uvm_object_utils_begin(slave_item)
        `uvm_field_int(data_sent, UVM_ALL_ON)
        `uvm_field_int(data_received, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_data {
        data_sent dist {
            8'h00 := 1, 8'hFF := 1, 8'h55 := 1, 8'hAA := 1,
            [8'h01:8'hFE] := 6
        };
    }

    function new(string name = "slave_item"); super.new(name); endfunction
endclass


class slave_base_seq extends uvm_sequence #(slave_item);
    `uvm_object_utils(slave_base_seq)
    function new(string name="slave_base_seq"); super.new(name); endfunction

    virtual task body();
        repeat(50) begin
            req = slave_item::type_id::create("req");
            start_item(req);
            if (!req.randomize()) `uvm_error("SEQ", "Randomization failed")
            finish_item(req);
        end
    endtask
endclass

class spi_master_driver extends uvm_driver #(slave_item);
    `uvm_component_utils(spi_master_driver)
    virtual slave_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual slave_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "VIF not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.sclk <= 1'b0;
        vif.mosi <= 1'b0;
        vif.cs_n <= 1'b1;

        forever begin
            seq_item_port.get_next_item(req);
            
            
            vif.cs_n <= 1'b0; 
            #100; // Setup time

            for (int i = 7; i >= 0; i--) begin
                vif.mosi <= req.data_sent[i]; 
                #500;
                vif.sclk <= 1'b1; 
                #500;
                vif.sclk <= 1'b0; 
            end
            
            #200;
            vif.cs_n <= 1'b1; 
            #500; 
            
            seq_item_port.item_done();
        end
    endtask
endclass


class slave_monitor extends uvm_monitor;
    `uvm_component_utils(slave_monitor)
    virtual slave_if vif;
    uvm_analysis_port #(slave_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual slave_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "VIF not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        slave_item item;
        bit [7:0]from_mosi; 

        forever begin
            @(negedge vif.cs_n);
           from_mosi = 0;       
            for (int i = 7; i >= 0; i--) begin
                @(posedge vif.sclk);
               from_mosi[i] = vif.mosi;
            end                 
            @(posedge vif.rx_done);           
            item = slave_item::type_id::create("item");
            item.data_sent     =from_mosi; 
            item.data_received = vif.rx_data;        
            `uvm_info("MON", $sformatf("In =0x%h, Out=0x%h", item.data_sent, item.data_received), UVM_LOW)
            mon_ap.write(item); 
        end
    endtask
endclass


class slave_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(slave_scoreboard)
    uvm_analysis_imp #(slave_item, slave_scoreboard) mon_export;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_export = new("mon_export", this);
    endfunction

    function void write(slave_item item);
    
        if (item.data_sent !== item.data_received) begin
            fail_cnt++;
            `uvm_error("SCB", $sformatf("Mismatch!! Sent=0x%h, Recv=0x%h", item.data_sent, item.data_received))
        end else begin
            pass_cnt++;
            `uvm_info("SCB", $sformatf("Match Success!! Data=0x%h", item.data_received), UVM_MEDIUM)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), "       SPI Slave Verification Summary     ", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Total Transactions : %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MATCH              : %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MISMATCH           : %0d", fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        if (fail_cnt == 0) `uvm_info("STATUS", " TEST PASSED", UVM_LOW)
        else `uvm_error("STATUS", " TEST FAILED")
    endfunction
endclass


class slave_agent extends uvm_agent;
    `uvm_component_utils(slave_agent)
    spi_master_driver drv;
    slave_monitor mon;
    uvm_sequencer #(slave_item) sqr;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_master_driver::type_id::create("drv", this);
        mon = slave_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(slave_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class slave_env extends uvm_env;
    `uvm_component_utils(slave_env)
    slave_agent agt;
    slave_scoreboard scb;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = slave_agent::type_id::create("agt", this);
        scb = slave_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agt.mon.mon_ap.connect(scb.mon_export);
    endfunction
endclass


class slave_test extends uvm_test;
    `uvm_component_utils(slave_test)
    slave_env env;
    virtual slave_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = slave_env::type_id::create("env", this);
        void'(uvm_config_db#(virtual slave_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        slave_base_seq seq;
        phase.raise_objection(this);
        
    
        vif.reset <= 1'b1;
        #100;
        vif.reset <= 1'b0;
        #100;

        seq = slave_base_seq::type_id::create("seq");
        seq.start(env.agt.sqr);

        #1000;
        phase.drop_objection(this);
    endtask
endclass


module tb_top;
    logic clk;
    initial begin clk = 0; forever #5 clk = ~clk; end 

    slave_if vif(clk);


    spi_slave_rx DUT (
        .clk     (vif.clk),
        .reset   (vif.reset),
        .sclk_i  (vif.sclk),
        .mosi_i  (vif.mosi),
        .cs_n_i  (vif.cs_n),
        .rx_data (vif.rx_data), 
        .rx_done (vif.rx_done) 
    );

    initial begin
        uvm_config_db#(virtual slave_if)::set(null, "*", "vif", vif);
        run_test("slave_test");
    end

    initial begin
        $fsdbDumpfile("dump_slave.fsdb");
        $fsdbDumpvars(0, tb_top);
    end
endmodule