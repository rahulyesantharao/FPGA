`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/15/2019 02:28:27 PM
// Design Name: 
// Module Name: timer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module timer #(parameter COUNTER_HI=26'd52_000_000)
    (
        input clk_104mhz,
        input start_timer,
        input [3:0] value,
        output logic expired,
        output [3:0] countdown_out
    );
    // convert the input clock to a 2 hz signal
    localparam COUNTER_LO = 26'd0; 
    logic one_hz_enable;
    logic [25:0] counter;
    
    // perform the countdown
    localparam IDLE = 1'b0;
    localparam COUNTING = 1'b1;
    logic [3:0] countdown;
    logic state;
    
    assign countdown_out = countdown;
    always_ff @(posedge clk_104mhz) begin
        if(start_timer) begin
            // reset
            counter <= COUNTER_LO;
            one_hz_enable <= 1'b0;
            expired <= 1'b0;
            // will latch onto value when start_timer is asserted, and only reread this value when start_timer is next asserted
            countdown <= value;
            state <= COUNTING;
        end else begin
            // one hz signal state updates
            if(counter < COUNTER_HI - 26'd1) one_hz_enable <= 1'b0;
            else one_hz_enable <= 1'b1;
            
            if(counter == COUNTER_HI - 26'd1) counter <= COUNTER_LO;
            else counter <= counter + 26'd1;
            
            // countdown logic
            if(state == COUNTING) begin
                if(countdown == 4'b0) begin // handle the 0 value edge case
                    countdown <= 4'b0;
                    expired <= 1'b1;
                    state <= IDLE;                
                end
                else if(one_hz_enable) begin
                    countdown <= countdown - 4'b1;
                    if(countdown == 4'b1) begin // put it here to avoid a one cycle delay between countdown and output
                        expired <= 1'b1;
                        state <= IDLE;
                    end
                    else begin
                        expired <= 1'b0;
                        state <= COUNTING;
                    end
                end
                else begin
                    countdown <= countdown;
                    expired <= expired;
                    state <= state;
                end
            end else begin
                expired <= 1'b0;
                countdown <= 4'b0;
                state <= IDLE;    
            end
        end
    end
endmodule
