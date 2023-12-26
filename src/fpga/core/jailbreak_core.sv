`timescale 1ns/1ps

import jailbreak::*;
import pocket_pkg::*;

module jailbreak_core(

    input  wire        clk_74a,
    input  wire        reset_n,

    output logic       pll_core_locked,

    output logic       video_rgb_clock,
    output logic       video_rgb_clock_90,

    input  wire[31:0]  bridge_addr,
    input  wire[31:0]  bridge_wr_data,
    input  wire        bridge_wr,

    output logic       video_vs,
    output logic       video_hs,
    output logic       video_de,
    output logic       video_skip,
    // FIXME: use the structure
    output logic [23:0] video_rgb,

    output logic        audio_mclk,
    output logic        audio_lrck,
    output logic        audio_dac,

    input  key_t        cont1_key,

    input  dip_switch_t dip_switches
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


    always_comb begin
        video_rgb_clock    = clk_48_660mhz;
        video_rgb_clock_90 = clk_48_660mhz_90degrees;
    end

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
//        coin_n          = 2'b11;
        coin_n          = {1'b1,~cont1_key.face_select};
        btn_service_n   = 1'b1;
        btn_start_n     = 2'b11;
        btn_start_n     = {1'b1,~cont1_key.face_start};
        p1_joystick_n   = {
            ~cont1_key.dpad_down,
            ~cont1_key.dpad_up,
            ~cont1_key.dpad_right,
            ~cont1_key.dpad_left
        };
        p2_joystick_n   = 4'b1111;
        p1_buttons_n    = {~cont1_key.face_a,~cont1_key.face_b};
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
