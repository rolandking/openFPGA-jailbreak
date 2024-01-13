//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module user_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input   wire            clk_74a, // mainclk1
    input   wire            clk_74b, // mainclk1

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    port_if                 port_cart_tran_bank0,

    // GBA A[23:16]
    port_if                 port_cart_tran_bank1,

    // GBA AD[15:8]
    port_if                 port_cart_tran_bank2,

    // GBA AD[7:0]
    port_if                 port_cart_tran_bank3,

    // GBA CS2#/RES#
    port_if                 port_cart_tran_pin30,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output  wire            cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    port_if                 port_cart_tran_pin31,

    // infrared
    port_ir_if              port_ir,

    // GBA link port
    gba_if                  port_gba,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    cram_if                 cram0,
    cram_if                 cram1,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    dram_if                 dram,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    sram_if                 sram,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input   wire            vblank,

    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    video_if                video,

    audio_if                audio,

    output  logic           bridge_endian_little,
    bridge_if               bridge,

    ///////////////////////////////////////////////////
    // controller data
    //
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    //   [31:28] type
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    controller_if           controller[1:4]
);

    localparam int NUM_LEAVES = 1;
    bridge_if bridge_out[NUM_LEAVES](.clk(clk_74a));

    localparam pocket::bridge_addr_range_t range_all[NUM_LEAVES] = '{
        '{from_addr : 32'h00000000, to_addr : 32'hffffffff}
    };

    bridge_master #(
        .ENDIAN_LITTLE     (1'b0),
        .NUM_LEAVES        (NUM_LEAVES),
        .ADDR_RANGES       (range_all)
        ) bm (
            .bridge_endian_little,
            .bridge_in             (bridge),
            .bridge_out            (bridge_out)
        );

    typedef enum int {
        CMD = 0
    } leaf_e;

    /* TEMP */
    pocket::bridge_addr_t bridge_addr;
    pocket::bridge_data_t bridge_rd_data, bridge_wr_data;
    logic bridge_rd, bridge_wr;
    always_comb bridge_out[CMD].explode(bridge_addr, bridge_wr_data, bridge_wr, bridge_rd_data, bridge_rd);
    /* TEMP */

    assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this

    always_comb begin
        // tie the cart off
        port_cart_tran_bank0.tie_off_out(4'b1111);
        port_cart_tran_bank1.tie_off_in();
        port_cart_tran_bank2.tie_off_in();
        port_cart_tran_bank3.tie_off_in();
        port_cart_tran_pin30.tie_off_in();
        port_cart_tran_pin31.tie_off_in();

        cart_pin30_pwroff_reset = 1'b0;

        // not using the IR port, so turn off both the LED, and
        // disable the receive circuit to save power
        port_ir.tie_off();

        port_gba.tie_off();

        cram0.tie_off();
        cram1.tie_off();

        dram.tie_off();

        sram.tie_off();
    end

    jailbreak::dip_switch_t dip_switches = jailbreak::dip_switch_default;

    // read data from the high score system
    logic [31:0] hs_rd_data;
    logic        hs_selected;

    // for bridge write data, we just broadcast it to all bus devices
    // for bridge read data, we have to mux it
    // add your own devices here
    always_comb begin
        bridge_rd_data = 'x;

        if(bridge_addr[31 -: 5] == 5'b11111) begin
            bridge_rd_data = cmd_bridge_rd_data;
        end

        if(bridge_addr == 32'h00100000) begin
            bridge_rd_data = 32'(dip_switches);
        end

        if(hs_selected) begin
            bridge_rd_data = hs_rd_data;
        end
    end

    always_ff @(posedge clk_74a) begin
        if(bridge_wr && (bridge_addr == 32'h00100000)) begin
            dip_switches <= jailbreak::dip_switch_t'(bridge_wr_data);
        end
    end

    //
    // host/target command handler
    //
    // driven by host commands, can be used as core-wide reset
    wire            reset_n;
    wire    [31:0]  cmd_bridge_rd_data;
    wire            pll_core_locked;

    // bridge host commands
    // synchronous to clk_74a
    wire            status_boot_done = pll_core_locked;
    wire            status_setup_done = pll_core_locked; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;

    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;

    wire            osnotify_inmenu;

    // bridge target commands
    // synchronous to clk_74a

    reg             target_dataslot_read;
    reg             target_dataslot_write;

    wire            target_dataslot_ack;
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;

    // bridge data slot access
    // synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

    core_bridge_cmd icb (

        .clk                ( clk_74a ),
        .reset_n            ( reset_n ),

        .bridge_endian_little   ( bridge_endian_little ),
        .bridge_addr            ( bridge_addr ),
        .bridge_rd              ( bridge_rd ),
        .bridge_rd_data         ( cmd_bridge_rd_data ),
        .bridge_wr              ( bridge_wr ),
        .bridge_wr_data         ( bridge_wr_data ),

        .status_boot_done       ( status_boot_done ),
        .status_setup_done      ( status_setup_done ),
        .status_running         ( status_running ),

        .dataslot_requestread       ( dataslot_requestread ),
        .dataslot_requestread_id    ( dataslot_requestread_id ),
        .dataslot_requestread_ack   ( dataslot_requestread_ack ),
        .dataslot_requestread_ok    ( dataslot_requestread_ok ),

        .dataslot_requestwrite      ( dataslot_requestwrite ),
        .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
        .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
        .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
        .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

        .dataslot_update            ( dataslot_update ),
        .dataslot_update_id         ( dataslot_update_id ),
        .dataslot_update_size       ( dataslot_update_size ),

        .dataslot_allcomplete   ( dataslot_allcomplete ),

        .rtc_epoch_seconds      ( rtc_epoch_seconds ),
        .rtc_date_bcd           ( rtc_date_bcd ),
        .rtc_time_bcd           ( rtc_time_bcd ),
        .rtc_valid              ( rtc_valid ),

        .savestate_supported    ( savestate_supported ),
        .savestate_addr         ( savestate_addr ),
        .savestate_size         ( savestate_size ),
        .savestate_maxloadsize  ( savestate_maxloadsize ),

        .savestate_start        ( savestate_start ),
        .savestate_start_ack    ( savestate_start_ack ),
        .savestate_start_busy   ( savestate_start_busy ),
        .savestate_start_ok     ( savestate_start_ok ),
        .savestate_start_err    ( savestate_start_err ),

        .savestate_load         ( savestate_load ),
        .savestate_load_ack     ( savestate_load_ack ),
        .savestate_load_busy    ( savestate_load_busy ),
        .savestate_load_ok      ( savestate_load_ok ),
        .savestate_load_err     ( savestate_load_err ),

        .osnotify_inmenu        ( osnotify_inmenu ),

        .target_dataslot_read       ( target_dataslot_read ),
        .target_dataslot_write      ( target_dataslot_write ),

        .target_dataslot_ack        ( target_dataslot_ack ),
        .target_dataslot_done       ( target_dataslot_done ),
        .target_dataslot_err        ( target_dataslot_err ),

        .target_dataslot_id         ( target_dataslot_id ),
        .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
        .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
        .target_dataslot_length     ( target_dataslot_length ),

        .datatable_addr         ( datatable_addr ),
        .datatable_wren         ( datatable_wren ),
        .datatable_data         ( datatable_data ),
        .datatable_q            ( datatable_q )

    );

    logic processor_halt;

    jailbreak_core jb_core (

        .clk_74a,
        .reset_n,

        .pll_core_locked,

        .video,

        .bridge_addr,
        .bridge_wr_data,
        .bridge_wr,
        .bridge_rd_data,
        .bridge_rd,

        .datatable_addr,
        .datatable_data,
        .datatable_wren,
        .datatable_q,

        .target_dataslot_read,       // rising edge triggered
        .target_dataslot_write,
        .target_dataslot_ack,        // asserted upon command start until completion

        .target_dataslot_id,         // parameters for each of the read/reload/write commands
        .target_dataslot_slotoffset,
        .target_dataslot_bridgeaddr,
        .target_dataslot_length,

        .processor_halt,

        .audio,

        .controller_key    (controller[1].key),

        .dip_switches,

        .pause             (osnotify_inmenu),

        .hs_selected,
        .hs_rd_data
    );

endmodule
