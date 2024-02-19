`timescale 1ns/1ps

module jailbreak_core(

    input wire                                      clk_74a,

    bus_if                                          bridge_rom,
    bus_if                                          bridge_dip,
    bus_if                                          bridge_hs,

    bus_if                                          bridge_dataslot_in,
    bus_if                                          bridge_dataslot_out,

    input logic                                     reset_n,
    input logic                                     in_menu,

    output bridge_pkg::host_request_status_result_e core_status,
    core_ready_to_run_if                            core_ready_to_run,

    host_dataslot_request_write_if                  host_dataslot_request_write,
    core_dataslot_read_if                           core_dataslot_read,

    video_if                                        video,
    audio_if                                        audio,

    input pocket::key_t                             controller_key
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

    logic clk_48_660mhz;
    logic clk_48_660mhz_90degrees;
    logic clk_12_288_mhz;
    logic pll_core_locked;

    mf_pllbase mp1 (
        .refclk         ( clk_74a ),
        .rst            ( 0 ),

        .outclk_0       ( clk_48_660mhz ),
        .outclk_1       ( clk_48_660mhz_90degrees ),
        .outclk_2       ( clk_12_288_mhz ),

        .locked         ( pll_core_locked )
    );


    always_comb begin
        video.rgb_clock    = clk_48_660mhz;
        video.rgb_clock_90 = clk_48_660mhz_90degrees;

        core_status = bridge_pkg::host_request_status_result_default(
            pll_core_locked,
            reset_n,
            1'b0
        );
    end

    core_ready_to_run crtr(
        .bridge_clk       (bridge_rom.clk),
        .pll_core_locked,
        .reset_n,
        .core_ready_to_run
    );

    jailbreak::dip_switch_t dip_switches;
    jailbreak_dip jdip(
        .bridge       (bridge_dip),
        .dip_switches
    );

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
    logic        underclock;

    logic [11:0] hs_address;
    logic [7:0]  hs_data_in;
    logic [7:0]  hs_data_out;
    logic        hs_write_enable;
    logic        hs_access_write;

    logic signed [15:0] sound;

    logic        video_hsync;
    logic        video_vsync;
    logic        video_vblank;
    logic        video_hblank;
    logic        ce_pix;
    logic [3:0]  video_r;
    logic [3:0]  video_g;
    logic [3:0]  video_b;

    always_comb begin
        coin_n          = {1'b1,~controller_key.face_select};
        btn_service_n   = 1'b1;
        btn_start_n     = 2'b11;
        btn_start_n     = {1'b1,~controller_key.face_start};
        p1_joystick_n   = {
            ~controller_key.dpad_down,
            ~controller_key.dpad_up,
            ~controller_key.dpad_right,
            ~controller_key.dpad_left
        };
        p2_joystick_n   = 4'b1111;
        p1_buttons_n    = {~controller_key.face_a,~controller_key.face_b};
        p2_buttons_n    = 2'b11;

        // we always run in 'underclock' mode
        underclock      = 1'b0;

    end

    // cross the rom bridge into the fast clock domain
    bus_if #(
        .addr_width  (32),
        .data_width (32)
    ) bridge_rom_cdc (
        .clk (clk_48_660mhz)
    );

    bridge_cdc rom_cdc(
        .in   (bridge_rom),
        .out  (bridge_rom_cdc)
    );

    bus_if#(
        .addr_width(32),
        .data_width(8)
    ) mem (
        .clk (bridge_rom_cdc.clk)
    );

    bridge_to_bytes b2b (
        .bridge           (bridge_rom_cdc),
        .mem              (mem)
    );

    logic processor_halt, pause;

    always_comb begin
        pause = in_menu;
    end

    jailbreak_hs hs(

        .bridge_hs,

        .bridge_dataslot_in,
        .bridge_dataslot_out,

        .host_dataslot_request_write,
        .core_dataslot_read,

        // for the JB core access
        .jb_core_clk         (clk_48_660mhz),

        .hs_address,
        .hs_access_write,
        .hs_write_enable,
        .hs_data_in,
        .hs_data_out,

        .processor_halt
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

        .dipsw              (~dip_switches),

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

        .ioctl_addr         (mem.addr),
        .ioctl_data         (mem.wr_data),
        .ioctl_wr           (mem.wr),

        .pause              (pause || processor_halt),

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
        .clk    (video.rgb_clock ),
        .in     (video_hsync),
        .out    (video.hs)
     );

     edge_detect#(
        .positive(1'b0)
     ) video_vsync_fall (
        .clk    (video.rgb_clock ),
        .in     (video_vsync),
        .out    (video.vs)
     );

     always_comb begin
        video.de   = ~(video_vblank || video_hblank);
        video.skip = video.de && !ce_pix;
        video.rgb  = video.de ? {video_r, 4'b0, video_g, 4'b0, video_b, 4'b0} : 24'b0;
     end

    logic [15:0] sound_clk_74a;
    // bring sound back into the I2S clock domain
    cdc_buffer#(
        .data_width  (16)
    ) i2s_cdc (
        .wr_clk      (clk_48_660mhz),
        .wr_data     (sound),
        .wr          (1'b1),

        .rd_clk      (clk_12_288_mhz),
        .rd_data     (sound_clk_74a)
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
            audio.lrck <= ~audio.lrck;
        end
    end

    always_comb begin
        audio.mclk = clk_12_288_mhz;
        audio.dac  = shifter[31];
    end

endmodule
