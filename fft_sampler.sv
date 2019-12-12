`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////
// FFT Sampler Module - Performs an averaging sweep over the FFT input
// and outputs the largest index from the resulting signal.
//  - Takes in the FFT coefficient as input
//  - Outputs the largest bucket (and a signal to indicate completion of the
//  calculation)
module fft_sampler(
  input logic clk, // input clock signal
  input logic start, // start system pulse
  input logic [15:0] cur_fft, // current FFT magnitude
  output logic [9:0] read_addr, // address to read FFT magnitude from (in FFT BRAM)
  output logic read_enable, // read enable signal to FFT BRAM
  output logic [10:0] largest_bucket, // the index of the largest FFT coefficient
  output logic done // pulse to indicate that processing is complete
);

// PARAMETERS ----------------------------
localparam IDLE = 2'd0;
localparam SWEEPING = 2'd1;

// Sweep Indices (audible range in input FFT)
localparam SWEEP_START = 11'd8;
localparam SWEEP_END = 11'd300; // used to be 400

// FFT Tuning Parameters
localparam NUM_BUCKETS = 11'd1024; // The total number of buckets in the FFT
localparam WINDOW_LEN = 2; // size of window for averaging filter
localparam SUM_LOW_THRESHOLD = 21'd100; // Minimum FFT sum magnitude

// STATE ---------------------------------
logic [1:0] state = IDLE;
logic [10:0] counter = 11'd0;
logic [15:0] window [WINDOW_LEN-1:0];
logic [20:0] sum = 21'd0;
logic [20:0] largest_sum = 21'd0;
logic [10:0] largest_index = 11'd0;
logic done_state = 1'b0;
    
// STATE TRANSITIONS -------------------------- 
logic [1:0] next_state;
logic [10:0] next_counter;
logic [20:0] next_sum;
logic [20:0] next_largest_sum;
logic [10:0] next_largest_index;
logic next_done_state;

always_comb begin
    case(state)
        IDLE: begin // stay in IDLE state
            next_state = IDLE;
            next_counter = SWEEP_START;
            next_sum = 21'd0;
            next_largest_sum = largest_sum;
            next_largest_index = largest_index; // just hold values
            next_done_state = 1'b0;
        end
        SWEEPING: begin
            // if the sweep is complete, switch back to IDLE
            if(counter == SWEEP_END) begin
                next_state = IDLE;
                next_counter = SWEEP_START;
                next_done_state = 1'b1;
            end else begin
                next_state = SWEEPING;
                next_counter = counter + 11'd1;
                next_done_state = 1'b0;
            end

            // sum and largest sum update
            next_sum = sum - window[WINDOW_LEN-1] + cur_fft;
            // next_sum holds the sum of the window ending on counter:
            //   - (counter- WINDOW_LEN, counter]
            next_largest_sum = (next_sum > largest_sum) ? next_sum : largest_sum;
            next_largest_index = (next_sum > largest_sum) ? counter : largest_index;
        end
        default: begin // just go to IDLE
            next_state = IDLE;
            next_counter = SWEEP_START;
            next_sum = 21'd0;
            next_largest_sum = largest_sum;
            next_largest_index = largest_index;
            next_done_state = 1'b0;
        end
    endcase
end
    
// OUTPUT/STATE UPDATES --------------------------------
assign read_addr = counter[9:0]; // the current FFT index we are considering
assign read_enable = (state == SWEEPING); // whether or not to read from the BRAM
assign largest_bucket = (largest_sum > SUM_LOW_THRESHOLD) ? largest_index : 11'd0;
assign done = done_state;
always_ff @(posedge clk) begin
    if(start) begin // reset to initial values and enter SWEEPING mode
        state <= SWEEPING;
        // zero the starting points
        counter <= SWEEP_START;
        sum <= 21'd0;
        largest_sum <= 21'd0;
        largest_index <= 11'd0; // not a valid index
        // zero the window
        window[1] <= 16'd0;
        window[0] <= 16'd0;
        done_state <= 1'b0;
    end else begin
        state <= next_state;
        counter <= next_counter;
        sum <= next_sum;
        largest_sum <= next_largest_sum;
        largest_index <= next_largest_index;
        // slide the window over
        window[1] <= window[0];
        window[0] <= cur_fft;
        done_state <= next_done_state;
    end
end
endmodule
