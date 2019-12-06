`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2019 08:13:14 PM
// Design Name: 
// Module Name: UART_decoder
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


module UART_decoder(
    input [7:0] jb,
    input clk_100mhz,
    input reset,
    output logic [6:0] led
    );
        
    logic [7:0] val_out;
    logic valid;
    logic [6:0] note;
    logic [87:0] notes_played;
    
    MIDI_decoder my_MIDI (.byte_in(val_out), .valid_byte(valid),
                            .clk_100mhz(clk_100mhz), .reset(reset),
                            .note_out(note), .notes_played(notes_played));
                            
    key_press my_key_press (.clk_100mhz(clk_100mhz), .np(notes_played),
                            .note_index(led));
    
    logic UART_in;
    assign UART_in = jb[0];
    
    parameter CLK_CYCLES_PER_SECOND = 100000000;
    parameter UART_BITS_PER_SECOND = 31250;
    parameter CLK_CYCLES_PER_UART_BIT = 3200;
    parameter IDLE_SAMPLE = 200;
    parameter DELAY = 1600;
    
    parameter IDLE = 2'b00;
    parameter START_BIT = 2'b01;
    parameter SAMPLING_BITS = 2'b11;
    parameter STOP_BIT = 2'b10;
    
    logic [1:0] state = IDLE;
    logic [11:0] counter = 12'b0;
    logic [2:0] index;
    
    always_ff @(posedge clk_100mhz) begin
    
        if (reset) begin
        
            val_out <= 8'hFF;
            state <= IDLE;
            counter <= 12'b0;
        
        end else begin
        
            case (state)
            
                IDLE: begin
                
                    val_out <= val_out;
                    counter <= (counter == IDLE_SAMPLE - 1) ? 12'b0 : counter + 1;
                    state <= ((counter == IDLE_SAMPLE - 1) && ~UART_in) ? START_BIT : IDLE;
                    index <= 3'b0;
                    valid <= 0;
                
                end
                
                START_BIT: begin
                
                    val_out <= val_out;
                    counter <= (counter == DELAY - 1) ? 12'b0 : counter + 1;
                    state <= (counter == DELAY - 1) ? SAMPLING_BITS : START_BIT;
                    index <= 3'b0;
                    valid <= 0;
                
                end
                
                SAMPLING_BITS: begin
                
                    val_out[index] = (counter == CLK_CYCLES_PER_UART_BIT - 1) ? UART_in : val_out[index];
                    counter <= (counter == CLK_CYCLES_PER_UART_BIT - 1) ? 12'b0 : counter + 1;
                    state <= ((counter == CLK_CYCLES_PER_UART_BIT - 1) && index == 7) ? STOP_BIT : SAMPLING_BITS;
                    index <= (counter == CLK_CYCLES_PER_UART_BIT - 1) ? index + 1 : index;
                    valid <= 0;
                
                end
                
                STOP_BIT : begin
                
                    val_out <= val_out;
                    counter <= (counter == CLK_CYCLES_PER_UART_BIT - 1) ? 12'b0 : counter + 1;
                    state <= (counter == CLK_CYCLES_PER_UART_BIT - 1) ? IDLE : STOP_BIT;
                    index <= 3'b0;
                    valid <= (counter == CLK_CYCLES_PER_UART_BIT - 1) ? 1 : 0;
                
                end
            
            endcase
            
        end
    
    end
    
endmodule

module MIDI_decoder(
    input [7:0] byte_in,
    input valid_byte,
    input clk_100mhz,
    input reset,
    output logic [6:0] note_out,
    output logic valid,
    output logic [87:0] notes_played
    );
    
    parameter NOTE_ON = 8'h40;
    parameter NOTE_OFF = 8'h00;
    
    logic [6:0] last_note;
//    logic status;
//    assign status = (byte_in == NOTE_ON) || (byte_in == NOTE_OFF);
    
//    always_ff @(posedge clk_100mhz) begin
    
//        if (reset) begin
        
//           last_note <= 7'h7F;
//           note_out <= 7'h7F;
//           valid <= 0; 
            
//        end else begin
        
//            if (valid_byte) begin
            
//                last_note <= status ? last_note : byte_in[6:0];
//                note_out <= (byte_in == NOTE_OFF) ? 7'h7F : last_note;
//                valid <= status;
            
//            end else begin
            
//                last_note <= last_note;
//                note_out <= note_out;
//                valid <= 0;
            
//            end
        
//        end
    
//    end

    logic status;
    logic [6:0] last_note_out;
    assign status = (byte_in == NOTE_ON) || (byte_in == NOTE_OFF);
    
    always_ff @(posedge clk_100mhz) begin
    
        if (reset) begin
        
            last_note <= 7'h7F;
            note_out <= 7'h7F;
            valid <= 0;
            notes_played <= 88'b0;
        
        end else begin
        
            if (valid_byte) begin
            
                last_note <= status ? last_note : byte_in[6:0];
                note_out <= (byte_in == NOTE_ON) ? last_note : last_note_out;
                valid <= status;
                notes_played[last_note] <= status ? (byte_in == NOTE_ON) : notes_played[last_note];
            
            end else begin
            
                last_note <= last_note;
                note_out <= note_out;
                valid <= 0;
                notes_played <= notes_played;
            
            end
        
        end
        
        last_note_out <= note_out;
    
    end
        
endmodule

module key_press(
    input clk_100mhz,
    input [87:0] np,
    output logic [6:0] note_index
    );
    
    int sum;
    assign sum = np[0] + np[1] + np[2] + np[3] + np[4] + np[5] + np[6] + np[7] + np[8] + np[9] + np[10]
                + np[11] + np[12] + np[13] + np[14] + np[15] + np[16] + np[17] + np[18] + np[19] + np[20] + np[21]
                + np[22] + np[23] + np[24] + np[25] + np[26] + np[27] + np[28] + np[29] + np[30] + np[31] + np[32]
                + np[33] + np[34] + np[35] + np[36] + np[37] + np[38] + np[39] + np[40] + np[41] + np[42] + np[43]
                + np[44] + np[45] + np[46] + np[47] + np[48] + np[49] + np[50] + np[51] + np[52] + np[53] + np[54]
                + np[55] + np[56] + np[57] + np[58] + np[59] + np[60] + np[61] + np[62] + np[63] + np[64] + np[65]
                + np[66] + np[67] + np[68] + np[69] + np[70] + np[71] + np[72] + np[73] + np[74] + np[75] + np[76]
                + np[77] + np[78] + np[79] + np[80] + np[81] + np[82] + np[83] + np[84] + np[85] + np[86] + np[87];
                
    always @(posedge clk_100mhz) begin
    
        if (sum == 0) begin
        
            note_index <= 7'h7F;
        
        end else if (sum > 1) begin
        
            note_index <= 7'h7E;
        
        end else begin
        
            case (np)
            
                88'h0000000000000000000001 : note_index <= 7'd0;
                88'h0000000000000000000002 : note_index <= 7'd1;
                88'h0000000000000000000004 : note_index <= 7'd2;
                88'h0000000000000000000008 : note_index <= 7'd3;
                88'h0000000000000000000010 : note_index <= 7'd4;
                88'h0000000000000000000020 : note_index <= 7'd5;
                88'h0000000000000000000040 : note_index <= 7'd6;
                88'h0000000000000000000080 : note_index <= 7'd7;
                88'h0000000000000000000100 : note_index <= 7'd8;
                88'h0000000000000000000200 : note_index <= 7'd9;
                88'h0000000000000000000400 : note_index <= 7'd10;
                88'h0000000000000000000800 : note_index <= 7'd11;
                88'h0000000000000000001000 : note_index <= 7'd12;
                88'h0000000000000000002000 : note_index <= 7'd13;
                88'h0000000000000000004000 : note_index <= 7'd14;
                88'h0000000000000000008000 : note_index <= 7'd15;
                88'h0000000000000000010000 : note_index <= 7'd16;
                88'h0000000000000000020000 : note_index <= 7'd17;
                88'h0000000000000000040000 : note_index <= 7'd18;
                88'h0000000000000000080000 : note_index <= 7'd19;
                88'h0000000000000000100000 : note_index <= 7'd20;
                88'h0000000000000000200000 : note_index <= 7'd21;
                88'h0000000000000000400000 : note_index <= 7'd22;
                88'h0000000000000000800000 : note_index <= 7'd23;
                88'h0000000000000001000000 : note_index <= 7'd24;
                88'h0000000000000002000000 : note_index <= 7'd25;
                88'h0000000000000004000000 : note_index <= 7'd26;
                88'h0000000000000008000000 : note_index <= 7'd27;
                88'h0000000000000010000000 : note_index <= 7'd28;
                88'h0000000000000020000000 : note_index <= 7'd29;
                88'h0000000000000040000000 : note_index <= 7'd30;
                88'h0000000000000080000000 : note_index <= 7'd31;
                88'h0000000000000100000000 : note_index <= 7'd32;
                88'h0000000000000200000000 : note_index <= 7'd33;
                88'h0000000000000400000000 : note_index <= 7'd34;
                88'h0000000000000800000000 : note_index <= 7'd35;
                88'h0000000000001000000000 : note_index <= 7'd36;
                88'h0000000000002000000000 : note_index <= 7'd37;
                88'h0000000000004000000000 : note_index <= 7'd38;
                88'h0000000000008000000000 : note_index <= 7'd39;
                88'h0000000000010000000000 : note_index <= 7'd40;
                88'h0000000000020000000000 : note_index <= 7'd41;
                88'h0000000000040000000000 : note_index <= 7'd42;
                88'h0000000000080000000000 : note_index <= 7'd43;
                88'h0000000000100000000000 : note_index <= 7'd44;
                88'h0000000000200000000000 : note_index <= 7'd45;
                88'h0000000000400000000000 : note_index <= 7'd46;
                88'h0000000000800000000000 : note_index <= 7'd47;
                88'h0000000001000000000000 : note_index <= 7'd48;
                88'h0000000002000000000000 : note_index <= 7'd49;
                88'h0000000004000000000000 : note_index <= 7'd50;
                88'h0000000008000000000000 : note_index <= 7'd51;
                88'h0000000010000000000000 : note_index <= 7'd52;
                88'h0000000020000000000000 : note_index <= 7'd53;
                88'h0000000040000000000000 : note_index <= 7'd54;
                88'h0000000080000000000000 : note_index <= 7'd55;
                88'h0000000100000000000000 : note_index <= 7'd56;
                88'h0000000200000000000000 : note_index <= 7'd57;
                88'h0000000400000000000000 : note_index <= 7'd58;
                88'h0000000800000000000000 : note_index <= 7'd59;
                88'h0000001000000000000000 : note_index <= 7'd60;
                88'h0000002000000000000000 : note_index <= 7'd61;
                88'h0000004000000000000000 : note_index <= 7'd62;
                88'h0000008000000000000000 : note_index <= 7'd63;
                88'h0000010000000000000000 : note_index <= 7'd64;
                88'h0000020000000000000000 : note_index <= 7'd65;
                88'h0000040000000000000000 : note_index <= 7'd66;
                88'h0000080000000000000000 : note_index <= 7'd67;
                88'h0000100000000000000000 : note_index <= 7'd68;
                88'h0000200000000000000000 : note_index <= 7'd69;
                88'h0000400000000000000000 : note_index <= 7'd70;
                88'h0000800000000000000000 : note_index <= 7'd71;
                88'h0001000000000000000000 : note_index <= 7'd72;
                88'h0002000000000000000000 : note_index <= 7'd73;
                88'h0004000000000000000000 : note_index <= 7'd74;
                88'h0008000000000000000000 : note_index <= 7'd75;
                88'h0010000000000000000000 : note_index <= 7'd76;
                88'h0020000000000000000000 : note_index <= 7'd77;
                88'h0040000000000000000000 : note_index <= 7'd78;
                88'h0080000000000000000000 : note_index <= 7'd79;
                88'h0100000000000000000000 : note_index <= 7'd80;
                88'h0200000000000000000000 : note_index <= 7'd81;
                88'h0400000000000000000000 : note_index <= 7'd82;
                88'h0800000000000000000000 : note_index <= 7'd83;
                88'h1000000000000000000000 : note_index <= 7'd84;
                88'h2000000000000000000000 : note_index <= 7'd85;
                88'h4000000000000000000000 : note_index <= 7'd86;
                88'h8000000000000000000000 : note_index <= 7'd87;
                default : note_index <= 7'hFd;
                                            
            endcase
        
        end
    
    end
    
endmodule
