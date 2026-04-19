`include "uvm_macros.svh"
import uvm_pkg::*;

interface spi_if(input logic clk);
    logic reset;
    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;
    logic [7:0] tx_data;
    logic       start;
    logic [7:0] rx_data;
    logic       done;
    logic       busy;
endinterface


class spi_seq_item extends uvm_sequence_item;
    rand bit [7:0] tx_data; 
    bit [7:0]      rx_data;

    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(tx_data, UVM_ALL_ON)
        `uvm_field_int(rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_miso_data {
        tx_data dist {
            8'h00 :/ 1,   // All-Zeros (10% 확률)
            8'hFF :/ 1,   // All-Ones  (10% 확률)
            8'h55 :/ 1,   // 01010101  (10% 확률)
            8'hAA :/ 1,   // 10101010  (10% 확률)
            [8'h01:8'hFE] :/ 6 // 나머지(60% 확률)
        };
    }

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction
endclass

class spi_slave_seq extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_slave_seq)

    function new(string name="spi_slave_seq"); 
        super.new(name); 
    endfunction

    virtual task body();
        forever begin
            req = spi_seq_item::type_id::create("req");
            start_item(req);
            assert(req.randomize()); 
            finish_item(req);
        end
    endtask

endclass

class spi_slave_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_slave_driver)
    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "VIF not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.miso <= 1'b0; 
        forever begin
            @(negedge vif.cs_n); 
            seq_item_port.get_next_item(req);
            
            for (int i = 7; i >= 0; i--) begin
                vif.miso <= req.tx_data[i];
                @(posedge vif.sclk);        
                req.rx_data[i] = vif.mosi;  
                if (i > 0) @(negedge vif.sclk); 
            end
            `uvm_info("DRV", $sformatf("Slave MISO sent: %h  Master MOSI received: %h", req.tx_data, req.rx_data), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask
endclass


class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)
    virtual spi_if vif;
    uvm_analysis_port #(spi_seq_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "VIF not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_seq_item item;
        forever begin           
            @(negedge vif.cs_n);
            item = spi_seq_item::type_id::create("item");

            item.tx_data = vif.tx_data; 

            
            for (int i = 7; i >= 0; i--) begin
                @(posedge vif.sclk);
                item.rx_data[i] = vif.mosi; 
            end
        
            @(posedge vif.cs_n);
            mon_ap.write(item); 
        end
    endtask
endclass


class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)
    
    spi_slave_driver drv;
    spi_monitor      mon;
    uvm_sequencer #(spi_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_slave_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass


class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)


    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) mon_export;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_export = new("mon_export", this);
    endfunction


   function void write(spi_seq_item item);
    
    
    if (item.tx_data !== item.rx_data) begin
        fail_cnt++;
        `uvm_error("SCB_MISMATCH", $sformatf("Mismatch!! Expected = 0x%h, Actual = 0x%h", item.tx_data, item.rx_data))
    end else begin
        pass_cnt++;
        `uvm_info("SCB_MATCH", $sformatf("MATCH Success!! Data = 0x%h", item.rx_data), UVM_MEDIUM)
    end
    endfunction

    
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), "       SPI Master Scoreboard Summary      ", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Total Transactions : %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MATCH              : %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" MISMATCH           : %0d", fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)

        if (fail_cnt > 0) begin
            `uvm_error("TEST_STATUS", $sformatf(" TEST FAILED!!!! %0d mismatches detected!", fail_cnt))
        end else begin
            `uvm_info("TEST_STATUS", $sformatf(" TEST PASSED!!!! %0d transactions complete", pass_cnt), UVM_LOW)
        end
        `uvm_info(get_type_name(), "\n", UVM_LOW)
    endfunction
endclass


class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)
    
    spi_agent      agt;
    spi_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = spi_agent::type_id::create("agt", this);
        scb = spi_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.mon_ap.connect(scb.mon_export);
    endfunction
endclass


class spi_master_test extends uvm_test;
    `uvm_component_utils(spi_master_test)

    spi_env env;
    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "VIF not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        spi_slave_seq slave_seq;
        
        bit [7:0] rand_mosi_data; 
        
        phase.raise_objection(this);

        vif.reset <= 1'b1;
        vif.start <= 1'b0;
        #20;
        vif.reset <= 1'b0;
        #20;

        
        slave_seq = spi_slave_seq::type_id::create("slave_seq");
        fork
            slave_seq.start(env.agt.sqr);
        join_none


        for (int i = 0; i < 50; i++) begin
            if (!std::randomize(rand_mosi_data) with {
                rand_mosi_data dist {
                    8'h00 := 1, 8'hFF := 1, 8'h55 := 1, 8'hAA := 1,
                    [8'h01:8'hFE] := 6
                };
            }) `uvm_fatal("TEST", "Randomization failed!")

            `uvm_info("TEST", $sformatf("=== [Iter %0d] Master TX Start: 8'h%0h ===", i+1, rand_mosi_data), UVM_LOW)

            @(posedge vif.clk);
            vif.tx_data <= rand_mosi_data;
            vif.start   <= 1'b1;
            @(posedge vif.clk);
            vif.start   <= 1'b0;

            @(posedge vif.done);
            #($urandom_range(10, 50)); 
        end

        #100;
        phase.drop_objection(this);
    endtask
endclass


module tb_top;
    logic clk, reset;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    spi_if vif(clk);

    SPI_Master DUT (
        .reset   (vif.reset),
        .clk     (vif.clk),
        .cpol    (1'b0),        
        .cpha    (1'b0),        
        .clk_div (8'd2),       
        .tx_data (vif.tx_data),
        .start   (vif.start),
        .miso    (vif.miso),
        .rx_data (vif.rx_data),
        .done    (vif.done),
        .busy    (vif.busy),
        .sclk    (vif.sclk),
        .mosi    (vif.mosi),
        .cs_n    (vif.cs_n)
    );

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "vif", vif);
        run_test("spi_master_test");
    end


    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb_top);
    end
endmodule