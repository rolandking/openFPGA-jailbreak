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
    ir_if                   ir,

    // GBA link port
    gba_if                  gba,

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
    bus_if                  bridge,

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

    localparam int NUM_LEAVES = 6;
    bus_if#(
        .addr_width (32),
        .data_width (32)
    ) bridge_out[NUM_LEAVES](.clk(clk_74a));

    localparam pocket::bridge_addr_range_t range_all[NUM_LEAVES] = '{
        '{from_addr : 32'hf8000000, to_addr : 32'hf8001fff},
        '{from_addr : 32'hf8002000, to_addr : 32'hf80020ff},
        '{from_addr : 32'hf8002380, to_addr : 32'hf80023ff},
        '{from_addr : 32'h00000000, to_addr : 32'h000fffff},
        '{from_addr : 32'h00100000, to_addr : 32'h00100000},
        '{from_addr : 32'h10001620, to_addr : 32'h1000166f}
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
        CMD      = 0,
        DATASLOT = 1,
        ID       = 2,
        ROM      = 3,
        DIP      = 4,
        HS       = 5
    } leaf_e;

    always_comb begin
        cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
        // tie the cart off
        port_cart_tran_bank0.tie_off_out(4'b1111);
        port_cart_tran_bank1.tie_off_in();
        port_cart_tran_bank2.tie_off_in();
        port_cart_tran_bank3.tie_off_in();
        port_cart_tran_pin30.tie_off_in();
        port_cart_tran_pin31.tie_off_in();

        // not using the IR port, so turn off both the LED, and
        // disable the receive circuit to save power
        ir.tie_off();

        gba.tie_off();

        cram0.tie_off();
        cram1.tie_off();

        dram.tie_off();

        sram.tie_off();

        //video.tie_off();
        //audio.tie_off();
    end

    bridge_pkg::host_request_status_result_e core_status;
    logic                                    reset_n;
    host_dataslot_request_read_if            host_dataslot_request_read();
    host_dataslot_request_write_if           host_dataslot_request_write();
    host_dataslot_update_if                  host_dataslot_update();
    host_dataslot_complete_if                host_dataslot_complete();
    host_rtc_update_if                       host_rtc_update();
    host_savestate_start_query_if            host_savestate_start_query();
    host_savestate_load_query_if             host_savestate_load_query();
    logic                                    in_menu;
    host_notify_cartridge_if                 host_notify_cartridge();
    logic                                    docked;
    host_notify_display_mode_if              host_notify_display_mode();

    core_ready_to_run_if                     core_ready_to_run();
    core_debug_event_log_if                  core_debug_event_log();
    core_dataslot_read_if                    core_dataslot_read();
    core_dataslot_write_if                   core_dataslot_write();
    core_dataslot_flush_if                   core_dataslot_flush();
    core_get_dataslot_filename_if            core_get_dataslot_filename();
    core_open_dataslot_file_if               core_open_dataslot_file();

    bus_if#(
        .addr_width (32),
        .data_width (32)
    ) bridge_dataslot_adjusted (
        .clk  (bridge.clk)
    );

    bridge_core bc(
        .bridge_cmd                        (bridge_out[CMD]),
        .bridge_id                         (bridge_out[ID]),
        .bridge_dataslot                   (bridge_dataslot_adjusted),
        .core_status,
        .reset_n,
        .host_dataslot_request_read,
        .host_dataslot_request_write,
        .host_dataslot_update,
        .host_dataslot_complete,
        .host_rtc_update,
        .host_savestate_start_query,
        .host_savestate_load_query,
        .in_menu,
        .host_notify_cartridge,
        .docked,
        .host_notify_display_mode,

        .core_ready_to_run,
        .core_debug_event_log,
        .core_dataslot_read,
        .core_dataslot_write,
        .core_dataslot_flush,
        .core_get_dataslot_filename,
        .core_open_dataslot_file
    );

    always_comb begin
        host_dataslot_request_read.tie_off();
        host_dataslot_request_write.tie_off();
        host_dataslot_update.tie_off();
        host_dataslot_complete.tie_off();
        host_rtc_update.tie_off();
        host_savestate_start_query.tie_off();
        host_savestate_load_query.tie_off();
        host_notify_cartridge.tie_off();
        host_notify_display_mode.tie_off();

        //core_status = bridge_pkg::host_request_status_result_default(pll_core_locked, reset_n, 1'b0);
        //core_ready_to_run.tie_off();
        core_debug_event_log.tie_off();
        //core_dataslot_read.tie_off();
        core_dataslot_write.tie_off();
        core_dataslot_flush.tie_off();
        core_get_dataslot_filename.tie_off();
        core_open_dataslot_file.tie_off();
    end

    jailbreak_core jb_core (
        .clk_74a,

        .bridge_rom           (bridge_out[ROM]),
        .bridge_dip           (bridge_out[DIP]),
        .bridge_hs            (bridge_out[HS]),

        .bridge_dataslot_in   (bridge_out[DATASLOT]),
        .bridge_dataslot_out  (bridge_dataslot_adjusted),

        .reset_n,
        .in_menu,

        .core_status,
        .core_ready_to_run,

        .host_dataslot_request_write,
        .core_dataslot_read,

        .video,
        .audio,

        .controller_key       (controller[1].key)
    );

endmodule
