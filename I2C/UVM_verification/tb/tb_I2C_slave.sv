`include "uvm_macros.svh"
import uvm_pkg::*;


interface i2c_slave_if(input logic clk);
    logic reset;
    tri1  scl; 
    tri1  sda;
    logic [7:0] rx_data;
    logic rx_done;
    logic [7:0] expected_data;
    logic scl_out, sda_out, scl_en, sda_en;

    assign scl = (scl_en && scl_out == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (sda_en && sda_out == 1'b0) ? 1'b0 : 1'bz;
endinterface


class i2c_item extends uvm_sequence_item;
    rand bit [6:0] addr;
    rand bit       read_write; 
    rand bit [7:0] wdata;
    bit [7:0]      rdata;

    `uvm_object_utils_begin(i2c_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(read_write, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_item"); 
        super.new(name); 
    endfunction
endclass

class i2c_master_write_seq extends uvm_sequence #(i2c_item);
    `uvm_object_utils(i2c_master_write_seq)
    function 
        new(string name="i2c_master_write_seq"); super.new(name); 
    endfunction

    virtual task body();
        i2c_item item;
        item = i2c_item::type_id::create("item");
        
        for(int i=0; i<50; i++) begin
            start_item(item); 
            if (!item.randomize() with { addr == 7'h12; read_write == 1'b0; }) begin
                `uvm_fatal("RAND", "Randomization failed")
            end
            item.wdata = $urandom;
            finish_item(item);
            #500; 
        end
    endtask
endclass

class i2c_slave_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_slave_monitor)
    virtual i2c_slave_if vif;
    uvm_analysis_port #(i2c_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(virtual i2c_slave_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2c_item item;
        forever begin
            @(posedge vif.rx_done); 
            item = i2c_item::type_id::create("item");
            item.wdata = vif.expected_data; 
            item.rdata = vif.rx_data;            
            mon_ap.write(item);
        end
    endtask
endclass

class i2c_slave_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_slave_scoreboard)
    uvm_analysis_imp #(i2c_item, i2c_slave_scoreboard) mon_export;
    int pass_cnt = 0, fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_export = new("mon_export", this);
    endfunction

    virtual function void write(i2c_item item);
        if (item.wdata !== item.rdata) begin 
            fail_cnt++;
            `uvm_error("SCB_MISMATCH", $sformatf("Mismatch! Expected=0x%h, Actual=0x%h", item.wdata, item.rdata))
        end else begin
            pass_cnt++;
            `uvm_info("SCB_MATCH", $sformatf("Match Success! Data=0x%h", item.rdata), UVM_MEDIUM)
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

class i2c_slave_driver extends uvm_driver #(i2c_item);
    `uvm_component_utils(i2c_slave_driver)
    virtual i2c_slave_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual i2c_slave_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get vif")
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.scl_out <= 1; 
        vif.scl_en <= 0;
        #100;
        vif.sda_out <= 1; 
        vif.sda_en <= 0;
        #100;
        
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    
    task drive_transfer(i2c_item tr);
    
    vif.sda_en <= 1; 
    vif.sda_out <= 0;
    #100;
    vif.scl_en <= 1; 
    vif.scl_out <= 0; 
    #100; 
    vif.expected_data <= tr.wdata;

    send_byte({tr.addr, tr.read_write});
    wait_ack();

   
    if (tr.read_write == 1'b0) begin 
        send_byte(tr.wdata);
        wait_ack();
    end else begin 
        read_byte(tr.rdata);
        send_nack();
    end

   
    vif.sda_en <= 1; 
    vif.sda_out <= 0; 
    #100;
    vif.scl_out <= 1; 
    #100;
    vif.sda_out <= 1; 
    #100;
    vif.scl_en <= 0; 
    vif.sda_en <= 0; 
    #500;
endtask

    task send_byte(input [7:0] data);
        for(int i=7; i>=0; i--) begin
            vif.sda_out <= data[i]; 
            #150;
            vif.scl_out <= 1; 
            #200;
            vif.scl_out <= 0; 
            #100;
        end
    endtask

    task read_byte(output [7:0] data);
        vif.sda_en <= 0;
        for(int i=7; i>=0; i--) begin
            vif.scl_out <= 1;
            #100;
            data[i] = vif.sda;
            vif.scl_out <= 0;
            #100;
        end
        vif.sda_en <= 1;
    endtask

    task wait_ack();
        vif.sda_en <= 0; 
        vif.scl_out <= 1; 
        #100; 
        vif.scl_out <= 0; 
        #100;
        vif.sda_en <= 1;
    endtask

    task send_nack();
        vif.sda_out <= 1; 
        #100;
        vif.scl_out <= 1;
        #100;
        vif.scl_out <= 0; 
        #100;
    endtask
endclass





class i2c_slave_env extends uvm_env;
    `uvm_component_utils(i2c_slave_env)
    i2c_slave_driver    drv;
    i2c_slave_monitor   mon;
    i2c_slave_scoreboard scb; 
    uvm_sequencer #(i2c_item) sqr;

    function new(string name, uvm_component parent); 
        super.new(name, parent); 
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase); 
        drv = i2c_slave_driver::type_id::create("drv", this);
        mon = i2c_slave_monitor::type_id::create("mon", this);
        scb = i2c_slave_scoreboard::type_id::create("scb", this); 
        sqr = uvm_sequencer#(i2c_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        mon.mon_ap.connect(scb.mon_export); 
    endfunction
endclass

class i2c_slave_test extends uvm_test;
    `uvm_component_utils(i2c_slave_test)
    i2c_slave_env env;

    function new(string name, uvm_component parent); 
        super.new(name, parent); 
    endfunction

    virtual function void build_phase(uvm_phase phase);
        env = i2c_slave_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2c_master_write_seq seq; 
        phase.raise_objection(this);
        seq = i2c_master_write_seq::type_id::create("seq");
        seq.start(env.sqr); 
        #1000;
        phase.drop_objection(this);
    endtask
endclass


module tb_top;
    logic clk;
    initial begin clk = 0; forever #5 clk = ~clk; end

    i2c_slave_if vif(clk);

    tri1 scl_pullup = vif.scl;
    tri1 sda_pullup = vif.sda;

    top_slave_board DUT (
        .clk(vif.clk),
        .reset(vif.reset),
        .scl(vif.scl),
        .sda(vif.sda),
        .rx_data(vif.rx_data),
        .rx_done(vif.rx_done)
    );

    initial begin
        uvm_config_db#(virtual i2c_slave_if)::set(null, "*", "vif", vif);
        run_test("i2c_slave_test");
    end

    initial begin
        vif.reset = 1;
        #50;
        vif.reset = 0;
    end

    initial begin
        $fsdbDumpfile("dump_i2c_master.fsdb");
        $fsdbDumpvars(0, tb_top);
    end
endmodule