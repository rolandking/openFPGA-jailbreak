package jailbreak;

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

    parameter dip_switch_t dip_switch_default = '{
        upright_controls:controls_single,
        flip_screen:1'b0,
        attract_mode_sound:1'b0,
        unused:1'b0,
        difficulty:difficulty_normal,
        bonus:bonus_30k_70k,
        cabinet:cabinet_upright,
        lives:lives_3,
        creditsB:credits_1c_1cr,
        creditsA:credits_1c_1cr
    };

endpackage
