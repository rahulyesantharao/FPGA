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
    input UART_in,
    input clk_100mhz,
    input reset,
    output logic [7:0] val_out,
    output logic valid
    );
    
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
                    valid <= 1;
                
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
                    valid <= 1;
                
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
    output logic valid
    );
    
    parameter NOTE_ON = 7'b0100000;
    parameter NOTE_OFF = 7'b0000000;
    
    logic [6:0] last_note;
    logic status;
    assign status = (byte_in == NOTE_ON) || (byte_in == NOTE_OFF);
    
    always_ff @(posedge clk_100mhz) begin
    
        if (reset) begin
        
           last_note <= 7'h7F;
           note_out <= 7'h7F;
           valid <= 0; 
            
        end else begin
        
            if (valid_byte) begin
            
                last_note <= status ? last_note : byte_in[6:0];
                note_out <= (byte_in == NOTE_OFF) ? 7'h7F : last_note;
                valid <= status;
            
            end else begin
            
                last_note <= last_note;
                note_out <= note_out;
                valid <= 0;
            
            end
        
        end
    
    end
    
endmodule
