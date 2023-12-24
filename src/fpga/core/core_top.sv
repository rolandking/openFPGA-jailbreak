//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

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

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output  wire            bridge_endian_little,
    input   wire    [31:0]  bridge_addr,
    input   wire            bridge_rd,
    output  reg     [31:0]  bridge_rd_data,
    input   wire            bridge_wr,
    input   wire    [31:0]  bridge_wr_data,

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

    // not using the IR port, so turn off both the LED, and
    // disable the receive circuit to save power
    assign port_ir_tx = 0;
    assign port_ir_rx_disable = 1;

    // bridge endianness
    assign bridge_endian_little = 0;

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


    // for bridge write data, we just broadcast it to all bus devices
    // for bridge read data, we have to mux it
    // add your own devices here
    always_comb begin
        bridge_rd_data = 'x;

        if(bridge_addr[31 -: 5] == 5'b11111) begin
            bridge_rd_data = cmd_bridge_rd_data;
        end
    end

    //
    // host/target command handler
    //
    // driven by host commands, can be used as core-wide reset
    wire            reset_n;
    wire    [31:0]  cmd_bridge_rd_data;

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



    ////////////////////////////////////////////////////////////////////////////////////////

    /*
        core runs at 48.660480, use this for the display
        dot clock. The display code runs on a /8 enable
        and is 256x244 displayed, 384x264 total. For 60Hz
        that is 384 * 264 * 60 = 6,082,560
        x8 for the full clock is 48,660,480

        the clock on MiSTer runs at 49.152MHz which would
        generate 60.60 Hz but has an underclock option which
        reconfigs down to 48.660MHz. Use only that option
    */

    wire    pll_core_locked;
    wire    clk_48_660mhz;
    wire    clk_48_660mhz_90degrees;
    wire    clk_12_288_mhz;

    mf_pllbase mp1 (
        .refclk         ( clk_74a ),
        .rst            ( 0 ),

        .outclk_0       ( clk_48_660mhz ),
        .outclk_1       ( clk_48_660mhz_90degrees ),
        .outclk_2       ( clk_12_288_mhz ),

        .locked         ( pll_core_locked )
    );


    assign video_rgb_clock    = clk_48_660mhz;
    assign video_rgb_clock_90 = clk_48_660mhz_90degrees;

    typedef enum logic[3:0]{
        credits_1c_1cr = 4'd0,
        credits_1c_2cr = 4'd1,
        credits_1c_3cr = 4'd2,
        credits_1c_4cr = 4'd3,
        credits_1c_5cr = 4'd4,
        credits_1c_6cr = 4'd5,
        credits_1c_7cr = 4'd6,
        credits_2c_1cr = 4'd7,
        credits_2c_3cr = 4'd8,
        credits_2c_5cr = 4'd9,
        credits_3c_1cr = 4'd10,
        credits_3c_2cr = 4'd11,
        credits_3c_4cr = 4'd12,
        credits_4c_1cr = 4'd13,
        credits_4c_3cr = 4'd14,
        credits_free   = 4'd15
    } credits_e;

    typedef enum logic [1:0] {
        lives_1 = 2'd0,
        lives_2 = 2'd1,
        lives_3 = 2'd2,
        lives_5 = 2'd3
    } lives_e;

    typedef enum logic {
        cabinet_cocktail = 1'b0,
        cabinet_upright  = 1'b1
    } cabinet_e;

    typedef enum logic {
        bonus_30k_70k = 1'b0,
        bonus_40k_80k = 1'b1
    } bonus_e;

    typedef enum logic[1:0] {
        difficulty_easy    = 2'd0,
        difficulty_normal  = 2'd1,
        difficulty_hard    = 2'd2,
        difficulty_hardest = 2'd3
    } difficulty_e;

    typedef enum logic {
        controls_single = 1'b0,
        controls_dual   = 1'b1
    } upright_controls_e;

    typedef struct packed {
        upright_controls_e upright_controls;            // 1
        logic              flip_screen;                 // 1
        logic              attract_mode_sound;          // 1
        logic              unused;                      // 1
        difficulty_e       difficulty;                  // 2
        bonus_e            bonus;                       // 1
        cabinet_e          cabinet;                     // 1
        lives_e            lives;                       // 2
        credits_e          creditsB;                    // 4
        credits_e          creditsA;                    // 4
    } dip_switch_t;

    localparam dip_switch_t dip_switch_default = '{
        upright_controls:controls_single,
        flip_screen:1'b0,
        attract_mode_sound:1'b1,
        unused:1'b0,
        difficulty:difficulty_normal,
        bonus:bonus_30k_70k,
        cabinet:cabinet_upright,
        lives:lives_3,
        creditsB:credits_1c_1cr,
        creditsA:credits_1c_1cr
    };

    /*
    *  hook up the Jailbreak core from MiSTer here
    */

    logic [1:0]  coin_n;
    logic        btn_service_n;
    logic [1:0]  btn_start_n;
    logic [3:0]  p1_joystick_n;
    logic [3:0]  p2_joystick_n;
    logic [1:0]  p1_buttons_n;
    logic [1:0]  p2_buttons_n;
    logic [19:0] dipsw_n;
    logic        underclock;

    logic [11:0] hs_address;
    logic [7:0]  hs_data_in;
    logic [7:0]  hs_data_out;
    logic        hs_write_enable;
    logic        hs_access_write;

    logic signed [15:0] sound;

    logic        pause;

    logic        video_hsync;
    logic        video_vsync;
    logic        video_vblank;
    logic        video_hblank;
    logic        ce_pix;
    logic [3:0]  video_r;
    logic [3:0]  video_g;
    logic [3:0]  video_b;

    always_comb begin
        // temp tieoff
        coin_n          = 2'b11;
        btn_service_n   = 1'b1;
        btn_start_n     = 2'b11;
        p1_joystick_n   = 4'b1111;
        p2_joystick_n   = 4'b1111;
        p1_buttons_n    = 2'b11;
        p2_buttons_n    = 2'b11;

        // we always run in 'underclock' mode
        underclock      = 1'b1;

        pause           = 1'b0;

        hs_address      = '0;
        hs_data_in      = '0;
        hs_write_enable = '0;
        hs_access_write = '0;

    end

    // bridge ROM writes. ROM here goes from 0x00000000 to 0x0002423F
    // so mask out 0x0003FFFF

    logic [31:0] mem_address;
    logic [7:0]  mem_data;
    logic        mem_wr;

    bridge_to_bytes#(
        .valid_bits       (32'h0003ffff)
    ) b2b (
        .clk              (clk_74a),
        .bridge_addr      (bridge_addr),
        .bridge_wr_data   (bridge_wr_data),
        .bridge_wr        (bridge_wr),

        .mem_address,
        .mem_data,
        .mem_wr
    );

    typedef struct packed {
        logic [24:0] address;
        logic [7:0]  data;
    } rom_data_t;

    rom_data_t rom_data_in, rom_data_out;
    logic rom_data_valid;

    always_comb begin
        rom_data_in.address = mem_address[24:0];
        rom_data_in.data    = mem_data;
    end

    cdc_fifo#(
        .address_width(8),
        .data_width($bits(rom_data_t))
    ) rom_data_fifo(
        .write_clk       (clk_74a),
        .write_data      (rom_data_in),
        .write_valid     (mem_wr),
        .write_ready     (),

        .read_clk        (clk_48_660mhz),
        .read_data       (rom_data_out),
        .read_valid      (rom_data_valid),
        .read_ack        ('1)
    );

    Jailbreak jb_core(
        // reset pin is really ~reset
        .reset              (reset_n),

        .clk_49m            (clk_48_660mhz),  //Actual frequency: 48,660,480
        .coin               (coin_n),
        .btn_service        (btn_service_n),
        .btn_start          (btn_start_n),
        .p1_joystick        (p1_joystick_n),
        .p2_joystick        (p2_joystick_n),
        .p1_buttons         (p1_buttons_n),
        .p2_buttons         (p2_buttons_n),

        //.dipsw              ({3'b0,~dip_switch_default}),
        .dipsw              ({2'd0,~dip_switch_default}),
        // we alway run with the 'underclocked' frequence
        .underclock,

        //Screen centering (alters HSync and VSync timing of the Konami 005849 to reposition the video output)
        // fix at zero for known VSYNC/HSYNC timing and because we're not on a CRT
        .h_center           (4'h0),
        .v_center           (4'h0),

        .sound,
        .video_csync        (),     // no need for composite sync
        .video_hsync,
        .video_vsync,
        .video_vblank,
        .video_hblank,
        .ce_pix,
        .video_r,
        .video_g,
        .video_b,

        .ioctl_addr         (rom_data_out.address),
        .ioctl_data         (rom_data_out.data),
        .ioctl_wr           (rom_data_valid),

        .pause,

        .hs_address,
        .hs_data_in,
        .hs_data_out,
        .hs_write_enable,
        .hs_access_write
    );

    /*
     *   use the video_hsync and video_vsync signals to drive video_hs and video_vs
     *   on the falling edge, they are active low
     *   use video_hblank and video_vblank to drive video_de, combo them, they are
     *   active high
     *   use RGB directly (combo)
     *   use ce_pix == 6MHz enable to drive enable the video_skip
     */

     edge_detect#(
        .positive(1'b0)
     ) video_hsync_fall (
        .clk    (video_rgb_clock ),
        .in     (video_hsync),
        .out    (video_hs)
     );

     edge_detect#(
        .positive(1'b0)
     ) video_vsync_fall (
        .clk    (video_rgb_clock ),
        .in     (video_vsync),
        .out    (video_vs)
     );

     always_comb begin
        video_de   = ~(video_vblank || video_hblank);
        video_skip = video_de && !ce_pix;
        video_rgb  = video_de ? {video_r, 4'b0, video_g, 4'b0, video_b, 4'b0} : 24'b0;
     end

    logic [15:0] sound_clk_74a;
    // bring sound back into the I2S clock domain
    cdc_buffer(
    .write_clk   (clk_48_660mhz),
    .write_data  (sound),
    .write_en    (1'b1),

    .read_clk    (clk_12_288_mhz),
    .read_data   (sound_clk_74a)
    );

    // every 4 cycles of clk_12_288_mhz we shift
    // every 32 cycles of that we reload and switch L/R

    logic [6:0] counter;

    logic [31:0] shifter;

    always @(posedge clk_12_288_mhz) begin
        counter <= counter + 7'd1;

        if( counter[1:0] == 2'b00) begin
            shifter <= {shifter[30:0], 1'b0};
        end

        if(counter == '0) begin
            shifter    <= {1'b0, sound_clk_74a, 15'b0};
            audio_lrck <= ~audio_lrck;
        end
    end

    always_comb begin
        audio_mclk = clk_12_288_mhz;
        audio_dac  = shifter[31];
    end

endmodule
