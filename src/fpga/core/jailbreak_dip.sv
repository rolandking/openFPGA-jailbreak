`timescale 1ns/1ps

module jailbreak_dip(
    bridge_if                      bridge,
    output jailbreak::dip_switch_t dip_switches
);

    // the bridge only covers one address so just write when it says
    // write and push the value back on every cycle

    jailbreak::dip_switch_t dip_switch_state = jailbreak::dip_switch_default;

    always @(posedge bridge.clk) begin
        bridge.rd_data <= dip_switches;
        if(bridge.wr) begin
            dip_switch_state <= jailbreak::dip_switch_t'(bridge.wr_data);
        end
    end

    always_comb dip_switches = dip_switch_state;

endmodule
