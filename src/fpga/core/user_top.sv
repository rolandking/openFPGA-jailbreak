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

    // GBA AD[15:8]
    inout   wire    [7:0]   cart_tran_bank2,
    output  wire            cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout   wire    [7:0]   cart_tran_bank3,
    output  wire            cart_tran_bank3_dir,

    // GBA A[23:16]
    inout   wire    [7:0]   cart_tran_bank1,
    output  wire            cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout   wire    [7:4]   cart_tran_bank0,
    output  wire            cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout   wire            cart_tran_pin30,
    output  wire            cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output  wire            cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout   wire            cart_tran_pin31,
    output  wire            cart_tran_pin31_dir,

    // infrared
    input   wire            port_ir_rx,
    output  wire            port_ir_tx,
    output  wire            port_ir_rx_disable,

    // GBA link port
    inout   wire            port_tran_si,
    output  wire            port_tran_si_dir,
    inout   wire            port_tran_so,
    output  wire            port_tran_so_dir,
    inout   wire            port_tran_sck,
    output  wire            port_tran_sck_dir,
    inout   wire            port_tran_sd,
    output  wire            port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output  wire    [21:16] cram0_a,
    inout   wire    [15:0]  cram0_dq,
    input   wire            cram0_wait,
    output  wire            cram0_clk,
    output  wire            cram0_adv_n,
    output  wire            cram0_cre,
    output  wire            cram0_ce0_n,
    output  wire            cram0_ce1_n,
    output  wire            cram0_oe_n,
    output  wire            cram0_we_n,
    output  wire            cram0_ub_n,
    output  wire            cram0_lb_n,

    output  wire    [21:16] cram1_a,
    inout   wire    [15:0]  cram1_dq,
    input   wire            cram1_wait,
    output  wire            cram1_clk,
    output  wire            cram1_adv_n,
    output  wire            cram1_cre,
    output  wire            cram1_ce0_n,
    output  wire            cram1_ce1_n,
    output  wire            cram1_oe_n,
    output  wire            cram1_we_n,
    output  wire            cram1_ub_n,
    output  wire            cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output  wire    [12:0]  dram_a,
    output  wire    [1:0]   dram_ba,
    inout   wire    [15:0]  dram_dq,
    output  wire    [1:0]   dram_dqm,
    output  wire            dram_clk,
    output  wire            dram_cke,
    output  wire            dram_ras_n,
    output  wire            dram_cas_n,
    output  wire            dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output  wire    [16:0]  sram_a,
    inout   wire    [15:0]  sram_dq,
    output  wire            sram_oe_n,
    output  wire            sram_we_n,
    output  wire            sram_ub_n,
    output  wire            sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input   wire            vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output  wire            dbg_tx,
    input   wire            dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output  wire            user1,
    input   wire            user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout   wire            aux_sda,
    output  wire            aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output  wire            vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output  wire    [23:0]  video_rgb,
    output  wire            video_rgb_clock,
    output  wire            video_rgb_clock_90,
    output  wire            video_de,
    output  wire            video_skip,
    output  wire            video_vs,
    output  wire            video_hs,

    output  wire            audio_mclk,
    input   wire            audio_adc,
    output  wire            audio_dac,
    output  wire            audio_lrck,

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
    input   wire    [31:0]  cont1_key,
    input   wire    [31:0]  cont2_key,
    input   wire    [31:0]  cont3_key,
    input   wire    [31:0]  cont4_key,
    input   wire    [31:0]  cont1_joy,
    input   wire    [31:0]  cont2_joy,
    input   wire    [31:0]  cont3_joy,
    input   wire    [31:0]  cont4_joy,
    input   wire    [15:0]  cont1_trig,
    input   wire    [15:0]  cont2_trig,
    input   wire    [15:0]  cont3_trig,
    input   wire    [15:0]  cont4_trig

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

    always_comb begin
        bridge_addr             = bridge_out[CMD].addr;
        bridge_wr_data          = bridge_out[CMD].wr_data;
        bridge_rd               = bridge_out[CMD].rd;
        bridge_wr               = bridge_out[CMD].wr;
        bridge_out[CMD].rd_data = bridge_rd_data;
    end
    /*
    always_comb begin
        bridge_addr        = bridge.addr;
        bridge_wr_data     = bridge.wr_data;
        bridge_rd          = bridge.rd;
        bridge_wr          = bridge.wr;
        bridge.rd_data     = bridge_rd_data;
    end
    */
    /* TEMP */

    // not using the IR port, so turn off both the LED, and
    // disable the receive circuit to save power
    assign port_ir_tx = 0;
    assign port_ir_rx_disable = 1;

    // bridge endianness
    //assign bridge_endian_little = 0;

    // cart is unused, so set all level translators accordingly
    // directions are 0:IN, 1:OUT
    assign cart_tran_bank3 = 8'hzz;
    assign cart_tran_bank3_dir = 1'b0;
    assign cart_tran_bank2 = 8'hzz;
    assign cart_tran_bank2_dir = 1'b0;
    assign cart_tran_bank1 = 8'hzz;
    assign cart_tran_bank1_dir = 1'b0;
    assign cart_tran_bank0 = 4'hf;
    assign cart_tran_bank0_dir = 1'b1;
    assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
    assign cart_tran_pin30_dir = 1'bz;
    assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
    assign cart_tran_pin31 = 1'bz;      // input
    assign cart_tran_pin31_dir = 1'b0;  // input

    // link port is unused, set to input only to be safe
    // each bit may be bidirectional in some applications
    assign port_tran_so = 1'bz;
    assign port_tran_so_dir = 1'b0;     // SO is output only
    assign port_tran_si = 1'bz;
    assign port_tran_si_dir = 1'b0;     // SI is input only
    assign port_tran_sck = 1'bz;
    assign port_tran_sck_dir = 1'b0;    // clock direction can change
    assign port_tran_sd = 1'bz;
    assign port_tran_sd_dir = 1'b0;     // SD is input and not used

    // tie off the rest of the pins we are not using
    assign cram0_a = 'h0;
    assign cram0_dq = {16{1'bZ}};
    assign cram0_clk = 0;
    assign cram0_adv_n = 1;
    assign cram0_cre = 0;
    assign cram0_ce0_n = 1;
    assign cram0_ce1_n = 1;
    assign cram0_oe_n = 1;
    assign cram0_we_n = 1;
    assign cram0_ub_n = 1;
    assign cram0_lb_n = 1;

    assign cram1_a = 'h0;
    assign cram1_dq = {16{1'bZ}};
    assign cram1_clk = 0;
    assign cram1_adv_n = 1;
    assign cram1_cre = 0;
    assign cram1_ce0_n = 1;
    assign cram1_ce1_n = 1;
    assign cram1_oe_n = 1;
    assign cram1_we_n = 1;
    assign cram1_ub_n = 1;
    assign cram1_lb_n = 1;

    assign dram_a = 'h0;
    assign dram_ba = 'h0;
    assign dram_dq = {16{1'bZ}};
    assign dram_dqm = 'h0;
    assign dram_clk = 'h0;
    assign dram_cke = 'h0;
    assign dram_ras_n = 'h1;
    assign dram_cas_n = 'h1;
    assign dram_we_n = 'h1;

    assign sram_a = 'h0;
    assign sram_dq = {16{1'bZ}};
    assign sram_oe_n  = 1;
    assign sram_we_n  = 1;
    assign sram_ub_n  = 1;
    assign sram_lb_n  = 1;

    assign dbg_tx = 1'bZ;
    assign user1 = 1'bZ;
    assign aux_scl = 1'bZ;
    assign vpll_feed = 1'bZ;

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

    logic [31:0] cycle_counter = 0 /* synthesis preserve */;
    logic processor_halt;

    always @(posedge clk_74a) begin
        cycle_counter <= cycle_counter + 32'd1;
    end

    always_comb dbg_tx = ^cycle_counter;

    jailbreak_core jb_core (

        .clk_74a,
        .reset_n,

        .pll_core_locked,

        .video_rgb_clock,
        .video_rgb_clock_90,

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

        .video_vs,
        .video_hs,
        .video_de,
        .video_skip,
        .video_rgb,

        .audio_mclk,
        .audio_lrck,
        .audio_dac,

        .cont1_key,

        .dip_switches,

        .pause             (osnotify_inmenu),

        .hs_selected,
        .hs_rd_data
    );


endmodule
