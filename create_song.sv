`timescale 1ns / 1ps

//create_song module outputs values in order to write to the song BRAM
//it takes in a 100MHz clock, an enable signal, a note_in from the keyboard,
//an 8-bit value to write to the BRAM, a write_enable signal to send to the BRAM, and an address_out to use in writing to the BRAM
module create_song(
    input clk_100mhz,
    input enable,
    input [6:0] note_in,
    output logic [7:0] value,
    output logic write_enable,
    output logic [9:0] address_out
    );
    
    //this is the byte that indicates a song has just ended in the song BRAM
    parameter END_SIGNAL = 8'b01111100;
    
    //record a note every 0.25 seconds
    parameter CYCLES_PER_NOTE = 25000000;
    
    logic [24:0] counter = 25'b0;
    logic prev_enable;
    
    //first address available in BRAM, last address available
    parameter START_ADDRESS = 753;
    parameter MAX_ADDRESS = 997;
    
    //value to indicate if we should write now
    logic write_now;
    assign write_now = (counter == CYCLES_PER_NOTE - 1);
    
    //value to indicate if we have maxed out on memory
    logic maxed;
    
    //address to write to
    logic [9:0] address;
    assign maxed = (address == MAX_ADDRESS - 1);

    assign address_out = address;
    
    //check if user is currently playing multiple notes, which is not allowed and will turn into a blank note in the recording
    logic bad_note;
    assign bad_note = (note_in == 7'h7E);
    
    always_ff @(posedge clk_100mhz) begin
        
        //if we have just enabled song-creation, go to START_ADDRESS, reset counter, and set write_enable to 0
        if (enable && ~prev_enable) begin
        
            address <= START_ADDRESS;
            counter <= 25'b0;
            write_enable <= 0;
            value <= {1'b0, note_in};
        
        //if song-creation is enabled, then set write_enable high when counter has reached CYCLES_PER_NOTE - 1;
        //increment counter, or reset to 0 when it has reached CYCLES_PER_NOTE - 1;
        //increment address when we should write a new value and we have not maxed out on memory;
        //write the value of the note passed in, or a blank (8'h7F) when an invalid note is passed in
        end else if (enable) begin
        
            write_enable <= maxed ? 0 : write_now;
            counter <= write_now ? 25'b0 : counter + 1;
            address <= (write_now & ~maxed) ? address + 1 : address; 
            value <= bad_note ? {8'h7F} : {1'b0, note_in};
        
        //if we have just disabled song-creation, write END_SIGNAL to the next address
        end else if (prev_enable && ~enable) begin
        
            write_enable <= 1;
            address <= address + 1;
            value <= END_SIGNAL;
        
        //otherwise, if song-creation is not enabled, set write_enable to 0
        end else begin
        
            write_enable <= 0;
            
        end
        
        prev_enable <= enable;
    
    end
    
endmodule
