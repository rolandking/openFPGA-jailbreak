`timescale 1ns/1ps

/*
    these are the entries from the Jailbreak.mra file which put the
    high score table at
        0x1620 + 0x50 bytes and
        0x157e + 0x03 bytes
        `
    header
    00 00 00 00 00 FF 00 02
    00 02 00 01 00 FF 02 00

4 byte START_WAIT          0x00000000
2 byte CHECK_WAIT          0x00ff
2 byte CHECK_HOLD          0x0002
2 byte WRITE_HOLD          0x0002
2 byte WRITE_REPEATCOUNT   0x0001
2 byte WRITE_REPEATWAIT    0x00ff
1 byte ACCESS_PAUSEPAD     0x02
1 byte CHANGEMASK          0x00

    00 00 16 20 00 50 00 11
    00 00 15 7E 00 03 00 30

    Address: 0x00001620
    Length:      0x0050
    Start:         0x00
    End:           0x11

    Address: 0x0000157e
    Length:      0x0003
    Start:         0x00
    End;           0x30

    the RAM is already enabled on bit 13 so the addresses we'll use are
    0x620+0x50 and 0x57e+0x03

rols@Rols-MacBook-Pro rols.Jailbreak % hexdump -vC Jailbreak.nvm
00000000  00 25 30 02 00 29 0c 23  00 21 40 01 01 11 1b 19  |.%0..).#.!@.....|
00000010  00 18 50 01 02 11 11 11  00 15 10 01 03 1e 0c 1d  |..P.............|
00000020  00 11 70 01 04 1e 0c 24  00 09 30 01 00 24 0c 19  |..p....$..0..$..|
00000030  00 09 20 01 01 11 11 11  00 08 50 01 02 11 0c 16  |.. .......P.....|
00000040  00 06 60 01 03 17 24 19  00 04 20 01 04 1f 1b 11  |..`...$... .....|
00000050  00 25 30                                          |.%0|

*/

/*
 * the high scores are mapped at 0x1620 for 0x50 bytes
 * map them in pocket at 0x10001620 + 0x50 to make it
 * easier to map them.
 *
 * the check data is at 0x157e + 0x03 and should be
 * 0x00 0x25 0x30
 *
 * catch the slot write for NVRAM, slot 2 and then intercept
 * any reads to replace it with length 0x50
 *
 * if the written length was 0x00, do nothing
 *
 * wait until a read from 0x157e + 0x03 returns the signature
 * then ask for a write of the NVRAM data
 */

module jailbreak_hs(

    bus_if                         bridge_hs,

    bus_if                         bridge_dataslot_in,
    bus_if                         bridge_dataslot_out,

    host_dataslot_request_write_if host_dataslot_request_write,
    core_dataslot_read_if          core_dataslot_read,

    // for the JB core access
    input  wire                    jb_core_clk,
    output wire [11:0]             hs_address,
    output wire                    hs_access_write,
    output wire                    hs_write_enable,
    output wire  [7:0]             hs_data_in,
    input  logic [7:0]             hs_data_out,

    output logic                   processor_halt
);

    // look for the size written to the hiscore dataslot
    // and the memory location which keeps that size

    parameter logic[15:0] HISCORE_SLOT_ID     = 16'd2;
    parameter logic[31:0] HISCORE_SIZE        = 32'h50;
    parameter logic[31:0] HISCORE_BRIDGE_ADDR = 32'h10001620;

    // the start address to look for the signature
    parameter logic[11:0] CHECK_ADDR          = 11'h57e;
    parameter logic[23:0] CHECK_VALUE         = 24'h003025;

    // the address of the memory location keeping
    // the address of the HISCORE slot
    pocket::bridge_addr_t slot_size_addr = '1;

    // status flags for what has been discovered
    logic slot_addr_found = '0;

    // default to '1 as a missing file will mean host_dataslot_request_write is
    // not issued
    logic slot_size_zero  = '1;

    bridge_pkg::dataslot_even_t dataslot_even;
    always_comb dataslot_even = bridge_pkg::dataslot_even_t'(bridge_dataslot_in.wr_data);

    // core clock domain

    always @(posedge bridge_dataslot_in.clk) begin

        if( host_dataslot_request_write.valid &&
            host_dataslot_request_write.param.slot_id == HISCORE_SLOT_ID
        ) begin
            slot_size_zero  <= (host_dataslot_request_write.param.expected_size == '0);
        end

        if(
            bridge_dataslot_in.addr[2:0] == '0       &&
            bridge_dataslot_in.wr                    &&
            dataslot_even.slot_id == HISCORE_SLOT_ID
        ) begin
            // the size is stored one memory address higher
            slot_size_addr  <= {bridge_dataslot_in.addr[31:3], 3'b100};
            slot_addr_found <= '1;
        end
    end

    // JB clock domain
    logic        hs_signature_found = 0;
    logic [23:0] check_data         = '1;

    bus_if#(
        .data_width  (8),
        .addr_width  (12)
    ) hs_bus (
        .clk (jb_core_clk)
    );

    logic       hs_bus_rd_ff  = 0;
    logic [5:0] check_offsets = 6'b100100;
    logic [1:0] check_offset;

    always_comb begin
        check_offset = check_offsets[1:0];
    end

    always_ff @(posedge jb_core_clk) begin

        // rotate the offsets
        check_offsets <= {check_offsets[3:0], check_offsets[5:4]};

        // collect the data - this will be off by one
        // cycle so data[0]->check[1], so compare with
        // a signature which is rotated
        if(!hs_signature_found) begin
            check_data[check_offset * 8 +: 8] <= hs_data_out;
        end

        if(check_data == CHECK_VALUE) begin
            hs_signature_found <= '1;
        end

        hs_bus_rd_ff <= hs_bus.rd;
    end

    // cross the hs bridge into the fast domain
    bus_if#(
        .addr_width (32),
        .data_width (32)
    ) bridge_hs_cdc(
        .clk  (jb_core_clk)
    );

    bridge_cdc(
        .in    (bridge_hs),
        .out   (bridge_hs_cdc)
    );

    bridge_to_bytes(
        .bridge (bridge_hs_cdc),
        .mem    (hs_bus)
    );

    always_comb begin
        hs_bus.rd_data  = hs_data_out;

        if(hs_signature_found) begin
            // connect the memory to the bus
            hs_address           = hs_bus.addr;
            hs_data_in           = hs_bus.wr_data;
            hs_access_write      = hs_bus.wr;
            hs_write_enable      = hs_bus.wr;
            hs_bus.rd_data_valid = hs_bus_rd_ff;
        end else begin
            hs_address           = CHECK_ADDR + check_offset;
            hs_data_in           = 'x;
            hs_access_write      = '0;
            hs_write_enable      = '0;
            hs_bus.rd_data_valid = '0;
        end
    end

    bidir_oneway#(.width(32)) bio_addr    (.in(bridge_dataslot_in.addr),    .out(bridge_dataslot_out.addr   ));
    bidir_oneway#(.width(32)) bio_wr_data (.in(bridge_dataslot_in.wr_data), .out(bridge_dataslot_out.wr_data));
    bidir_oneway#(.width(1) ) bio_rd_data (.in(bridge_dataslot_in.wr),      .out(bridge_dataslot_out.wr     ));
    bidir_oneway#(.width(1) ) bio_rd      (.in(bridge_dataslot_in.rd),      .out(bridge_dataslot_out.rd     ));

    bidir_oneway#(
        .width(1)
    ) bio_rd_dv (
        .in   (bridge_dataslot_out.rd_data_valid),
        .out  (bridge_dataslot_in.rd_data_valid )
    );

    always_comb begin
        bridge_dataslot_in.rd_data =
            (bridge_dataslot_out.addr == slot_size_addr) ? HISCORE_SIZE : bridge_dataslot_out.rd_data;
    end

    // move the signature ready signal into the bridge clock domain
    logic hs_signature_found_bridge;
    cdc_sync#(
        .num_bits  (1)
    ) hssig_cdc (
        .from_clk    (jb_core_clk),
        .from_data   (hs_signature_found),
        .to_clk      (bridge_hs.clk),
        .to_data     (hs_signature_found_bridge)
    );

    typedef enum logic[1:0] {
        WAIT_SLOT      = 2'b00,
        WAIT_SIGNATURE = 2'b01,
        READ_DATA      = 2'b10,
        IDLE           = 2'b11
    } state_e;

    state_e state = WAIT_SLOT;

    always @(posedge bridge_hs.clk) begin
        case(state)
            WAIT_SLOT: begin
                if(slot_addr_found) begin
                    state <= WAIT_SIGNATURE;
                end
            end
            WAIT_SIGNATURE: begin
                if(hs_signature_found_bridge) begin
                    if(slot_size_zero) begin
                        state <= IDLE;
                    end else begin
                        state <= READ_DATA;
                    end
                end
            end
            READ_DATA: begin
                if(core_dataslot_read.done) begin
                    state <= IDLE;
                end
            end
            IDLE: begin
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        core_dataslot_read.param             = '0;
        core_dataslot_read.param.slot_id     = HISCORE_SLOT_ID;
        core_dataslot_read.param.bridge_addr = HISCORE_BRIDGE_ADDR;
        core_dataslot_read.param.length      = HISCORE_SIZE;

        core_dataslot_read.valid             = '0;
        processor_halt                       = '0;
        case(state)
            READ_DATA: begin
                core_dataslot_read.valid     = '1;
                processor_halt               = '1;
            end
            default: begin
            end
        endcase
    end

endmodule
