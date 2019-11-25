module fft_analyzer(
    input logic clk_104mhz,
    input logic vauxp3,
    input logic vauxn3,
    output logic hi,
    output logic lo
);
    // state
    localparam PULSE_COUNT = 21'd1_733_333;
    logic [20:0] pulse_counter = 21'd0;
    logic fft_pulse;
    assign fft_pulse = (pulse_counter == PULSE_COUNT - 21'd1) ? 1'b1 : 1'b0;
    always_ff @(posedge clk_104mhz) begin
        pulse_counter <= (pulse_counter == PULSE_COUNT - 21'd1) ? 21'd0 : pulse_counter + 21'd1;  
    end
    
    
    // ADC Conversion of Microphone
    wire [15:0] sample_reg;
    wire eoc, xadc_reset;
    mic_adc mic_adc_0 (
        .dclk_in(clk_104mhz),  // Master clock for DRP and XADC. 
        .di_in(0),             // DRP input info (0 becuase we don't need to write)
        .daddr_in(6'h13),      // The DRP register address for the third analog input register
        .den_in(1),            // DRP enable line high (we want to read)
        .dwe_in(0),            // DRP write enable low (never write)
        .drdy_out(),           // DRP ready signal (unused)
        .do_out(sample_reg),   // DRP output from register (the ADC data)
        .reset_in(xadc_reset), // reset line
        .vp_in(0),             // dedicated/built in analog channel on bank 0
        .vn_in(0),             // can't use this analog channel b/c of nexys 4 setup
        .vauxp3(vauxp3),         // The third analog auxiliary input channel
        .vauxn3(vauxn3),         // Choose this one b/c it's on JXADC header 1
        .channel_out(),        // Not useful in sngle channel mode
        .eoc_out(eoc),         // Pulses high on end of ADC conversion
        .alarm_out(),          // Not useful
        .eos_out(),            // End of sequence pulse, not useful
        .busy_out()            // High when conversion is in progress. unused.
    );
    assign xadc_reset = 1'b0;
    
    // Oversample this data, sums 16 input samples at a time and outputs them divided by 4 -> add two bits
    wire [13:0] osample16;
    wire done_osample16;
    oversample16 oversampler(
        .clk(clk_104mhz),
        .sample(sample_reg[15:4]),
        .eoc(eoc),
        .oversample(osample16),
        .done(done_osample16));
        
    
    // Create the frame BRAM that frames of digital data are written to
    wire fwe;
    reg [11:0] fhead = 0; // Frame head - a pointer to the write point, works as circular buffer
    wire [15:0] fsample;  // The sample data from the XADC, oversampled 15x
    wire [11:0] faddr;    // Frame address - The read address, controlled by bram_to_fft
    wire [15:0] fdata;    // Frame data - The read data, input into bram_to_fft
    frame_bram bram1 (
        .clka(clk_104mhz),
        .wea(fwe),
        .addra(fhead),
        .dina(fsample),
        .clkb(clk_104mhz),
        .addrb(faddr),
        .doutb(fdata));
    always @(posedge clk_104mhz) if (done_osample16) fhead <= fhead + 1; // Move the pointer every oversample
    assign fsample = {osample16, 2'b0}; // Pad the oversample with zeros to pretend it's 16 bits
    assign fwe = done_osample16; // Write only when we finish an oversample (every 104*16 clock cycles)
    
    // Read frame data at a chosen rate and send it to FFT
    wire last_missing; // All these are control lines to the FFT block design
    wire [31:0] frame_tdata;
    wire frame_tlast, frame_tready, frame_tvalid;
    bram_to_fft bram_to_fft_0 (
        .clk(clk_104mhz),
        .head(fhead),
        .addr(faddr),
        .data(fdata),
        .start(fft_pulse),
        .last_missing(last_missing),
        .frame_tdata(frame_tdata),
        .frame_tlast(frame_tlast),
        .frame_tready(frame_tready),
        .frame_tvalid(frame_tvalid)
    );
    
    // Perform the FFT!
    wire [23:0] magnitude_tdata; // This output bus has the FFT magnitude for the current index
    wire [11:0] magnitude_tuser; // This represents the current index being output, from 0 to 4096
    wire [11:0] scale_factor; // This input adjusts the scaling of the FFT, which can be tuned to the input magnitude.
    wire magnitude_tlast, magnitude_tvalid;
    fft_mag fft_mag_i(
        .clk(clk_104mhz),
        .event_tlast_missing(last_missing),
        .frame_tdata(frame_tdata),
        .frame_tlast(frame_tlast),
        .frame_tready(frame_tready),
        .frame_tvalid(frame_tvalid),
        .scaling(12'b1100_0001_1101),
        .magnitude_tdata(magnitude_tdata),
        .magnitude_tlast(magnitude_tlast),
        .magnitude_tuser(magnitude_tuser),
        .magnitude_tvalid(magnitude_tvalid));
        
    // Write the FFT to BRAM
    wire in_range = ~|magnitude_tuser[11:10]; // When 13 and 12 are 0, we're on indexes 0 to 1023
    wire [9:0] haddr; // The read port address
    wire [15:0] hdata; // The read port data
    fft_bram bram2 (
        .clka(clk_104mhz),
        .wea(in_range & magnitude_tvalid),  // Only save FFT output if in range and output is valid
        .addra(magnitude_tuser[9:0]),       // The FFT output index, 0 to 1023
        .dina(magnitude_tdata[15:0]),       // The actual FFT magnitude
        .clkb(clk_104mhz),  // input wire clkb used to be clk_65mhz
        .addrb(haddr),     // input wire [9 : 0] addrb
        .doutb(hdata)      // output wire [15 : 0] doutb
    );
    
    // Read from the FFT Bram and find the largest bucket
    wire [10:0] cur_big_index;
    wire index_calc;
    wire ignore;
    fft_sampler sampler(
        .clk(clk_104mhz),
        .start((magnitude_tuser[9:0] == 10'd1023)),
        .cur_fft(hdata),
        .read_addr(haddr),
        .read_enable(ignore),
        .largest_bucket(cur_big_index),
        .done(index_calc));


    // fft sensitivity timer
    logic timer_start, timer_done;
    timer fft_timer (
        .clk_104mhz(clk_104mhz),
        .start_timer(timer_start),
        .value(4'd1),
        .expired(timer_done)
    );
    
    // fft state
    localparam HILO_THRESHOLD = 11'h30;
    localparam STATE_TRACKING = 1'b1;
    localparam STATE_WAITING = 1'b0;
    localparam HILO_CYCLE_COUNT = 7'd45;
    
    logic state = STATE_TRACKING; // 1 = tracking, 0 = waiting for timer
    
    localparam LO_NOISE = 2'b01;
    localparam HI_NOISE = 2'b10;
    localparam NO_NOISE = 2'b00;
    logic [1:0] noise_state = NO_NOISE;
    logic [6:0] hilo_cycles=7'd0;
    
    // state transitions
    logic next_state;
    logic [1:0] next_noise_state;
    logic [6:0] next_hilo_cycles;
    always_comb begin
        case(state)
        STATE_WAITING: begin
            next_state = timer_done ? STATE_TRACKING : STATE_WAITING;
            next_noise_state = noise_state; // just hold the values steady
            next_hilo_cycles = 7'd0;
        end
        STATE_TRACKING: begin
            if(hilo_cycles == HILO_CYCLE_COUNT) begin
                next_state = STATE_WAITING;
                next_noise_state = noise_state;
                next_hilo_cycles = 7'd0;
            end else begin
                if(index_calc) begin // only update each time the fft is recalculated
                    next_state = STATE_TRACKING;
                    if(cur_big_index == 11'd0) begin // sentinel value for no noise
                        next_noise_state = NO_NOISE;
                    end else begin
                        if(cur_big_index > HILO_THRESHOLD) next_noise_state = HI_NOISE;
                        else next_noise_state = LO_NOISE;
                    end
                    next_hilo_cycles = (noise_state == next_noise_state) ? hilo_cycles + 7'd1 : 7'd0;
                end else begin
                    next_state = state;
                    next_noise_state = noise_state;
                    next_hilo_cycles = hilo_cycles;
                end
            end
        end
        endcase
    end
    
    // state updates
    assign timer_start = (hilo_cycles == HILO_CYCLE_COUNT) ? 1'b1 : 1'b0; 
    assign hi = (state == STATE_WAITING) ? noise_state[1] : 1'b0;
    assign lo = (state == STATE_WAITING) ? noise_state[0] : 1'b0; // only output when counting
    always_ff @(posedge clk_104mhz) begin
        state <= next_state;
        noise_state <= next_noise_state;
        hilo_cycles <= next_hilo_cycles;
    end
endmodule

module oversample16(
    input wire clk,
    input wire [11:0] sample,
    input wire eoc,
    output reg [13:0] oversample,
    output reg done
);
    reg [3:0] counter = 0;
    reg [15:0] accumulator = 0;

    always @(posedge clk) begin
        done <= 0;
        if (eoc) begin
            // Conversion has ended and we can read a new sample
            if (&counter) begin // If counter is full (16 accumulated)
                // Get final total, divide by 4 with (very limited) rounding.
                oversample <= (accumulator + sample + 2'b10) >> 2;
                done <= 1;
                // Reset accumulator
                accumulator <= 0;
            end
            else begin
                // Else add to accumulator as usual
                accumulator <= accumulator + sample;
                done <= 0;
            end
            counter <= counter + 1;
        end
    end
endmodule

module bram_to_fft(
    input wire clk,
    input wire [11:0] head,
    output reg [11:0] addr,
    input wire [15:0] data,
    input wire start,
    input wire last_missing,
    output reg [31:0] frame_tdata,
    output reg frame_tlast,
    input wire frame_tready,
    output reg frame_tvalid
    );
    
    // Get a signed version of the sample by subtracting half the max
    wire signed [15:0] data_signed = {1'b0, data} - (1 << 15);

    // SENDING LOGIC
    // Once our oversampling is done,
    // Start at the frame bram head and send all 4096 buckets of bram.
    // Hopefully every time this happens, the FFT core is ready
    reg sending = 0;
    reg [11:0] send_count = 0;


    // windowing coefficient
    wire [23:0] hann_coeff; // HANN LENGTH FIELD: len(HANN)
    hann my_hann(.n(send_count), .coeff(hann_coeff));
    wire signed [40:0] windowed_data; // HANN LENGTH FIELD (1 + len(HANN) + len(data_signed))
    assign windowed_data = hann_coeff * data_signed;
    always @(posedge clk) begin
        frame_tvalid <= 0; // Normally do not send
        frame_tlast <= 0; // Normally not the end of a frame
        if (!sending) begin
            if (start) begin // When a new sample shifts in
                addr <= head; // Start reading at the new head
                send_count <= 0; // Reset send_count
                sending <= 1; // Advance to next state
            end
        end
        else begin
            if (last_missing) begin
                // If core thought the frame ended
                sending <= 0; // reset to state 0
            end
            else begin
                frame_tdata <= {16'b0, (windowed_data >> 24)}; // HANN LENGTH FIELD: len(HANN)
                frame_tvalid <= 1; // Signal to fft a sample is ready
                if (frame_tready) begin // If the fft module was ready
                    addr <= addr + 1; // Switch to read next sample
                    send_count <= send_count + 1; // increment send_count 
                end
                if (&send_count) begin
                    // We're at last sample
                    frame_tlast <= 1; // Tell the core
                    if (frame_tready) sending <= 0; // Reset to state 0
                end
            end
        end
    end

endmodule
