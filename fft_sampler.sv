module fft_sampler(
  input logic clk,
  input logic start,
  input logic [15:0] cur_fft,
  output logic [9:0] read_addr,
  output logic read_enable,
  output logic [10:0] largest_bucket,
  output logic done
);

    localparam IDLE = 2'd0;
    localparam SWEEPING = 2'd1;
    
    localparam LOW_THRESHOLD = 11'd8;
    localparam NUM_BUCKETS = 11'd1024;
    localparam WINDOW_LEN = 2;
    
    logic [1:0] state = IDLE;
    logic [10:0] counter = 11'd0;
    logic [15:0] window [WINDOW_LEN-1:0];
    logic [20:0] sum = 21'd0;
    logic [20:0] largest_sum = 21'd0;
    logic [10:0] largest_index = 11'd0;
    
    // state transitions
    logic [1:0] next_state;
    logic [10:0] next_counter;
    logic [20:0] next_sum;
    logic [20:0] next_largest_sum;
    logic [10:0] next_largest_index;
    
    always_comb begin
      case(state)
        IDLE: begin
          next_state = IDLE;
          next_counter = 11'd0;
          next_sum = 21'd0;
          next_largest_sum = largest_sum;
          next_largest_index = largest_index; // just hold values
        end
        SWEEPING: begin
          // state and counter update
          if(counter == NUM_BUCKETS - 11'd1) begin
            next_state = IDLE;
            next_counter = 11'd0;
          end else begin
            next_state = SWEEPING;
            next_counter = counter + 11'd1;
          end
    
          // sum and largest sum update
          next_sum = sum - window[WINDOW_LEN-1] + cur_fft;
          // next_sum holds the sum of the window ending on counter:
          //   - (counter- WINDOW_LEN, counter]
          next_largest_sum = ((next_sum > largest_sum) || (counter < LOW_THRESHOLD)) ? next_sum : largest_sum;
          next_largest_index = ((next_sum > largest_sum) || (counter < LOW_THRESHOLD)) ? counter : largest_index;
        end
        default: begin // just go to IDLE
          next_state = IDLE;
          next_counter = 11'd0;
          next_sum = 21'd0;
          next_largest_sum = largest_sum;
          next_largest_index = largest_index;
        end
      endcase
    end
    
    // might have to add a one cycle delay
    assign read_addr = counter[9:0];
    assign read_enable = (state == SWEEPING);
    assign largest_bucket = largest_index;
    assign done = (state == IDLE);
    always_ff @(posedge clk) begin
      if(start) begin
        state <= SWEEPING;
        // zero the starting points
        counter <= 11'd0;
        sum <= 21'd0;
        largest_sum <= 21'd0;
        largest_index <= 11'd0; // not a valid index
        // zero the window
//        window[3] <= 16'd0;
//        window[2] <= 16'd0;
        window[1] <= 16'd0;
        window[0] <= 16'd0;
      end else begin
        state <= next_state;
        counter <= next_counter;
        sum <= next_sum;
        largest_sum <= next_largest_sum;
        largest_index <= next_largest_index;
        // slide the window over
//        window[3] <= window[2];
//        window[2] <= window[1];
        window[1] <= window[0];
        window[0] <= cur_fft;
      end
    end
endmodule
