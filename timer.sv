`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Timer Module - Starts on a pulse, and counts down an input length
module timer #(parameter COUNTER_HI=26'd52_000_000) (
    input clk_104mhz, // input clock, at 104 MHz
    input start_timer, // a pulse to start the countdown
    input [3:0] value, // how long to countdown for
    output logic expired, // a pulse indicating whether the timer has expired
    output [3:0] countdown_out // the current countdown position
);
    // fields to convert the input clock to a 2 hz signal
    localparam COUNTER_LO = 26'd0; 
    logic one_hz_enable;
    logic [25:0] counter;
    
    // fields perform the countdown
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
            // will latch onto value when [start_timer] is asserted, 
            // and only reread this value when [start_timer] is next asserted
            countdown <= value;
            state <= COUNTING;
        end else begin
            // one hz signal state updates
            if(counter < COUNTER_HI - 26'd1) one_hz_enable <= 1'b0;
            else one_hz_enable <= 1'b1;
            
            if(counter == COUNTER_HI - 26'd1) counter <= COUNTER_LO;
            else counter <= counter + 26'd1;
            
            // countdown logic
            case(state)
              IDLE: begin
                  expired <= 1'b0;
                  countdown <= 4'b0;
                  state <= IDLE;    
              end
              COUNTING: begin
                  if(countdown == 4'b0) begin // handle the 0 value edge case
                      countdown <= 4'b0;
                      expired <= 1'b1;
                      state <= IDLE;                
                  end
                  else begin
                    countdown <= (one_hz_enable) ? countdown - 4'b1 : countdown;
                    // check here to avoid a one cycle delay between countdown and output
                    expired <= (one_hz_enable) ? ((countdown == 4'b1) ? 1'b1 : 1'b0) : expired;
                    state <= (one_hz_enable) ? ((countdown == 4'b1) ? IDLE : COUNTING) : state;
                  end
              end   
              default: state <= IDLE; // revert from invalid state to IDLE
            endcase
        end
    end
endmodule
