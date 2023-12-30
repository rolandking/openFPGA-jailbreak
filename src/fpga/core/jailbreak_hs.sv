`timescale 1ns/1ps

/*
    these are the entries from the Jailbreak.mra file which put the
    high score table at
        0x1620 + 0x50 bytes and
        0x157e + 0x03 bytes
        `
    00 00 16 20 00 50 00 11
    00 00 15 7E 00 03 00 30

    the RAM is already enabled on bit 13 so the addresses we'll use are
    0x620+0x50 and 0x57e+0x03
*/

module jailbreak_hs(

    // for bridge data
    input  wire         clk_74a,
    // to trigger overwriting the slot entry
    input  wire         reset_n,
    input  wire[31:0]   bridge_addr,
    input  wire[31:0]   bridge_wr_data,
    input  wire         bridge_wr,
    output logic [31:0] bridge_rd_data,
    input  wire         bridge_rd,

    // bridge addresses match our range
    output wire         selected,

    // connection to the datatable to overwrite the slot entry
    output logic [9:0]  datatable_addr,
    output logic [31:0] datatable_data,
    output logic        datatable_wren,

    // for the JB core access
    input  wire         jb_core_clk,
    output wire [11:0]  hs_address,
    output wire         hs_access_write,
    output wire         hs_write_enable,
    output wire [7:0]   hs_data_in,
    input logic [7:0]   hs_data_out
);

    logic [31:0] mem_address;
    logic [7:0]  mem_wr_data;
    logic        mem_wr;
    logic [7:0]  mem_rd_data;
    logic        mem_rd;
    logic        bridge_rd_ready;

    /*
     * we need 0x53 bytes so map them from
     * 0x10000000 to 0x10000052
     */
    bridge_to_bytes#(
        .fixed_bits       (32'h10000000),
        .fixed_mask       (32'hffffff80),
        .read_cycles      (8),              // need to domain cross two ways
        .write_cycles     (2)
    ) b2b (
        .clk              (clk_74a),
        .bridge_addr,
        .bridge_wr_data,
        .bridge_wr,
        .bridge_rd_data,
        .bridge_rd,
        .bridge_rd_ready,

        .mem_address,
        .mem_wr_data,
        .mem_wr,
        .mem_rd_data,
        .mem_rd,

        .selected
    );

    // cross the reads and writes to the other clock domain
    // we only need the bottom 7 bits of the address

    typedef struct packed {
        logic [6:0] address;
        logic [7:0] data;
        logic       is_write;
    } mem_access_t;

    mem_access_t mem_access_in;

    always_comb begin
        mem_access_in.address  = mem_address[6:0];
        mem_access_in.data     = mem_wr_data;
        mem_access_in.is_write = mem_wr;
    end

    mem_access_t mem_access_out;
    logic        mem_access_out_valid;

    cdc_fifo #(
        .address_width(4),
        .data_width($bits(mem_access_t))
    ) hs_data_to_jb_core (
        .write_clk      (clk_74a),
        .write_data     (mem_access_in),
        .write_valid    (mem_rd || mem_wr),
        .write_ready    (),

        .read_clk       (jb_core_clk),
        .read_data      (mem_access_out),
        .read_valid     (mem_access_out_valid),
        .read_ack       ('1)
    );

    logic [31:0] hs1_address, hs2_address;
    logic        hs1_selected, hs2_selected;

    // map 0x00000000-0x0000004f to 0x620-0x66f
    remapper #(
        .BASE_ADDRESS       (32'h00000000),
        .MAP_ADDRESS        (32'h00000620),
        .MAP_LENGTH         (32'h50)
    ) hs1_remap (
        .raw_address        (mem_access_out.address),
        .selected           (hs1_selected),
        .mapped_address     (hs1_address)
    );

    // map 0x10000050-0x00000052 to 0x57e-0x580
    remapper #(
        .BASE_ADDRESS       (32'h00000050),
        .MAP_ADDRESS        (32'h0000057e),
        .MAP_LENGTH         (32'h3)
    ) hs2_remap  (
        .raw_address        (mem_access_out.address),
        .selected           (hs2_selected),
        .mapped_address     (hs2_address)
    );

    always_comb begin
        hs_address  = hs1_selected ? hs1_address : hs2_address;
    end

    always_comb begin
        hs_data_in      = mem_access_out.data;
        hs_access_write = 1'b0;
        hs_write_enable = 1'b0;
    end

    // overwrite the slot size to force high scores to be stored
    always_comb begin
        datatable_addr = 32'd5;
        datatable_data = 32'd83;
    end

    // write the data slot as we come out of reset
    edge_detect reset_edge (
        .clk       (clk_74a),
        .in        (reset_n),
        .out       (datatable_wren)
    );


endmodule