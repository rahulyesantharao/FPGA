
//Top level module (should not need to change except to uncomment ADC module)

module keyboard(   input clk_100mhz,
                    input [9:0] sw,
                    input vauxp3,
                    input vauxn3,
                    input vn_in,
                    input vp_in,
                    input reset,
                    input enable,
                    output logic aud_pwm,
                    output logic aud_sd
    );  
    parameter SAMPLE_COUNT = 763;//gets approximately (will generate audio at approx 131,072 Hz sample rate).
    
    logic [15:0] sample_counter;
    logic [11:0] adc_data;
    logic [11:0] sampled_adc_data;
    logic sample_trigger;
    logic adc_ready;
    logic [7:0] recorder_data;             
    logic [7:0] vol_out;
    logic pwm_val; //pwm signal (HI/LO)
    
    assign aud_sd = 1;
    //assign led = sw; //just to look pretty 
    assign sample_trigger = (sample_counter == SAMPLE_COUNT);

    always_ff @(posedge clk_100mhz)begin
        if (sample_counter == SAMPLE_COUNT)begin
            sample_counter <= 16'b0;
        end else begin
            sample_counter <= sample_counter + 16'b1;
        end
        if (sample_trigger) begin
            sampled_adc_data <= {~adc_data[11],adc_data[10:0]}; //convert to signed. incoming data is offset binary
            //https://en.wikipedia.org/wiki/Offset_binary
        end
    end
    
    logic [31:0] phase_step;
 
    recorder myrec( .clk_in(clk_100mhz),.rst_in(0),
                    .ready_in(sample_trigger),
                    .data_out(recorder_data), .sw(sw));   
                                                                                            
    volume_control vc (.vol_in(sw[9:7]),
                       .signal_in(recorder_data), .signal_out(vol_out));
    pwm (.clk_in(clk_100mhz), .rst_in(reset), .level_in({~vol_out[7],vol_out[6:0]}), .pwm_out(pwm_val));
    assign aud_pwm = (pwm_val & enable) ? 1'bZ : 1'b0; 
    
endmodule





///////////////////////////////////////////////////////////////////////////////
//
// Record/playback
//
///////////////////////////////////////////////////////////////////////////////


module recorder(
  input logic clk_in,              // 100MHz system clock
  input logic rst_in,               // 1 to reset to initial state
  input logic ready_in,             // 1 when data is available
  input logic [9:0] sw,
  output logic signed [7:0] data_out       // 8-bit PCM data to headphone
); 
    logic [7:0] tone;
    logic [31:0] freq;
    
    freq_lut find_freq (.note_index(sw[6:0] - 7'd9), .clk_in(clk_in), .freq(freq));
    
    sine_generator  out_tone (   .clk_in(clk_in), .rst_in(rst_in), 
                                 .step_in(ready_in), .freq(freq), .sine(1'b1), .amp_out(tone));
    
    always_ff @(posedge clk_in)begin
        data_out = tone; //send tone immediately to output
    end                            
endmodule                              


//Volume Control
module volume_control (input [2:0] vol_in, input signed [7:0] signal_in, output logic signed[7:0] signal_out);
    logic [2:0] shift;
    assign shift = 3'd7 - vol_in;
    assign signal_out = signal_in>>>shift;
endmodule

//PWM generator for audio generation!
module pwm (input clk_in, input rst_in, input [7:0] level_in, output logic pwm_out);
    logic [7:0] count;
    assign pwm_out = count<level_in;
    always_ff @(posedge clk_in)begin
        if (rst_in)begin
            count <= 8'b0;
        end else begin
            count <= count+8'b1;
        end
    end
endmodule




//Sine Wave Generator
module sine_generator ( input clk_in, input rst_in, //clock and reset
                        input step_in, //trigger a phase step (rate at which you run sine generator)
                        input [31:0] freq, //desired frequency in Hz
                        input logic sine,
                        output logic [31:0] phase_stepping,
                        output logic [7:0] amp_out); //output phase   
                        
    parameter table_num = 64;
    parameter log_pulse_rate = 17;
                        
    //parameter PHASE_INCR = 32'b1000_0000_0000_0000_0000_0000_0000_0000>>5; //1/64th of 48 khz is 750 Hz
    
    logic [31:0] phase_incr;
    
    assign phase_incr = ((freq << (32 - log_pulse_rate)) - (freq >> log_pulse_rate));
    assign phase_stepping = phase_incr;
    
    logic [7:0] divider;
    logic [31:0] phase;
    logic [7:0] amp_sine;
    logic [7:0] amp;
    
    assign amp = amp_sine;
    
    assign amp_out = {~amp[7],amp[6:0]};
    sine_lut lut_1(.clk_in(clk_in), .phase_in(phase[31:26]), .amp_out(amp_sine));
    
    always_ff @(posedge clk_in)begin
        if (rst_in)begin
            divider <= 8'b0;
            phase <= 32'b0;
        end else if (step_in)begin
            phase <= phase+phase_incr;
        end
    end
endmodule

module freq_lut(input [6:0] note_index, input clk_in, output logic[31:0] freq);
    always_ff @(posedge clk_in) begin
        case(note_index)
            7'd0: freq <= 32'd27;
            7'd1: freq <= 32'd29;
            7'd2: freq <= 32'd31;
            7'd3: freq <= 32'd33;
            7'd4: freq <= 32'd35;
            7'd5: freq <= 32'd37;
            7'd6: freq <= 32'd39;
            7'd7: freq <= 32'd41;
            7'd8: freq <= 32'd44;
            7'd9: freq <= 32'd46;
            7'd10: freq <= 32'd49;
            7'd11: freq <= 32'd52;
            7'd12: freq <= 32'd55;
            7'd13: freq <= 32'd58;
            7'd14: freq <= 32'd62;
            7'd15: freq <= 32'd65;
            7'd16: freq <= 32'd69;
            7'd17: freq <= 32'd73;
            7'd18: freq <= 32'd78;
            7'd19: freq <= 32'd82;
            7'd20: freq <= 32'd87;
            7'd21: freq <= 32'd92;
            7'd22: freq <= 32'd98;
            7'd23: freq <= 32'd104;
            7'd24: freq <= 32'd110;
            7'd25: freq <= 32'd117;
            7'd26: freq <= 32'd123;
            7'd27: freq <= 32'd131;
            7'd28: freq <= 32'd139;
            7'd29: freq <= 32'd147;
            7'd30: freq <= 32'd156;
            7'd31: freq <= 32'd165;
            7'd32: freq <= 32'd175;
            7'd33: freq <= 32'd185;
            7'd34: freq <= 32'd196;
            7'd35: freq <= 32'd208;
            7'd36: freq <= 32'd220;
            7'd37: freq <= 32'd233;
            7'd38: freq <= 32'd247;
            7'd39: freq <= 32'd262;
            7'd40: freq <= 32'd277;
            7'd41: freq <= 32'd294;
            7'd42: freq <= 32'd311;
            7'd43: freq <= 32'd330;
            7'd44: freq <= 32'd349;
            7'd45: freq <= 32'd370;
            7'd46: freq <= 32'd392;
            7'd47: freq <= 32'd415;
            7'd48: freq <= 32'd440;
            7'd49: freq <= 32'd466;
            7'd50: freq <= 32'd494;
            7'd51: freq <= 32'd523;
            7'd52: freq <= 32'd554;
            7'd53: freq <= 32'd587;
            7'd54: freq <= 32'd622;
            7'd55: freq <= 32'd659;
            7'd56: freq <= 32'd698;
            7'd57: freq <= 32'd740;
            7'd58: freq <= 32'd784;
            7'd59: freq <= 32'd831;
            7'd60: freq <= 32'd880;
            7'd61: freq <= 32'd932;
            7'd62: freq <= 32'd988;
            7'd63: freq <= 32'd1046;
            7'd64: freq <= 32'd1109;
            7'd65: freq <= 32'd1175;
            7'd66: freq <= 32'd1245;
            7'd67: freq <= 32'd1319;
            7'd68: freq <= 32'd1397;
            7'd69: freq <= 32'd1480;
            7'd70: freq <= 32'd1568;
            7'd71: freq <= 32'd1661;
            7'd72: freq <= 32'd1760;
            7'd73: freq <= 32'd1865;
            7'd74: freq <= 32'd1976;
            7'd75: freq <= 32'd2093;
            7'd76: freq <= 32'd2217;
            7'd77: freq <= 32'd2349;
            7'd78: freq <= 32'd2489;
            7'd79: freq <= 32'd2637;
            7'd80: freq <= 32'd2794;
            7'd81: freq <= 32'd2960;
            7'd82: freq <= 32'd3136;
            7'd83: freq <= 32'd3322;
            7'd84: freq <= 32'd3520;
            7'd85: freq <= 32'd3729;
            7'd86: freq <= 32'd3951;
            7'd87: freq <= 32'd4186;
            7'd118: freq <= 32'd0;
            default: freq <= 32'd0;
        endcase  
    end
endmodule

//6bit sine lookup, 8bit depth
module sine_lut(input[5:0] phase_in, input clk_in, output logic[7:0] amp_out);
  always_ff @(posedge clk_in)begin
    case(phase_in)
      6'd0: amp_out<=8'd128;
      6'd1: amp_out<=8'd140;
      6'd2: amp_out<=8'd152;
      6'd3: amp_out<=8'd165;
      6'd4: amp_out<=8'd176;
      6'd5: amp_out<=8'd188;
      6'd6: amp_out<=8'd198;
      6'd7: amp_out<=8'd208;
      6'd8: amp_out<=8'd218;
      6'd9: amp_out<=8'd226;
      6'd10: amp_out<=8'd234;
      6'd11: amp_out<=8'd240;
      6'd12: amp_out<=8'd245;
      6'd13: amp_out<=8'd250;
      6'd14: amp_out<=8'd253;
      6'd15: amp_out<=8'd254;
      6'd16: amp_out<=8'd255;
      6'd17: amp_out<=8'd254;
      6'd18: amp_out<=8'd253;
      6'd19: amp_out<=8'd250;
      6'd20: amp_out<=8'd245;
      6'd21: amp_out<=8'd240;
      6'd22: amp_out<=8'd234;
      6'd23: amp_out<=8'd226;
      6'd24: amp_out<=8'd218;
      6'd25: amp_out<=8'd208;
      6'd26: amp_out<=8'd198;
      6'd27: amp_out<=8'd188;
      6'd28: amp_out<=8'd176;
      6'd29: amp_out<=8'd165;
      6'd30: amp_out<=8'd152;
      6'd31: amp_out<=8'd140;
      6'd32: amp_out<=8'd128;
      6'd33: amp_out<=8'd115;
      6'd34: amp_out<=8'd103;
      6'd35: amp_out<=8'd90;
      6'd36: amp_out<=8'd79;
      6'd37: amp_out<=8'd67;
      6'd38: amp_out<=8'd57;
      6'd39: amp_out<=8'd47;
      6'd40: amp_out<=8'd37;
      6'd41: amp_out<=8'd29;
      6'd42: amp_out<=8'd21;
      6'd43: amp_out<=8'd15;
      6'd44: amp_out<=8'd10;
      6'd45: amp_out<=8'd5;
      6'd46: amp_out<=8'd2;
      6'd47: amp_out<=8'd1;
      6'd48: amp_out<=8'd0;
      6'd49: amp_out<=8'd1;
      6'd50: amp_out<=8'd2;
      6'd51: amp_out<=8'd5;
      6'd52: amp_out<=8'd10;
      6'd53: amp_out<=8'd15;
      6'd54: amp_out<=8'd21;
      6'd55: amp_out<=8'd29;
      6'd56: amp_out<=8'd37;
      6'd57: amp_out<=8'd47;
      6'd58: amp_out<=8'd57;
      6'd59: amp_out<=8'd67;
      6'd60: amp_out<=8'd79;
      6'd61: amp_out<=8'd90;
      6'd62: amp_out<=8'd103;
      6'd63: amp_out<=8'd115;
    endcase
  end
endmodule