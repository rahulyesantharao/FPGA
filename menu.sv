`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////
// Menu Module - Provides the state machine for all menus in the system
//   In general, the menu deals with 2-bit indices, and continuously
//   outputs the current choice.
module menu
#(
    parameter NUM_BITS = 2, // the number of bits in the choices
    parameter BOTTOM_CHOICE = 2'd0 // the lowest choice number in the menu
)
(
    input logic clk_in, // input clock
    input logic rst_in, // system reset
    input logic btn_up, // up control
    input logic btn_down, // down control
    input logic [1:0] top_choice, // the highest possible choice in the menu
    output logic [NUM_BITS - 1:0] choice // the current choice in the menu
);
    // current selection
    logic [NUM_BITS - 1:0] current_selection = BOTTOM_CHOICE;
    
    // state transition
    logic [NUM_BITS - 1:0] next_selection;
    always_comb begin
        case({btn_up, btn_down})
            2'b10: next_selection = (current_selection > BOTTOM_CHOICE) ? current_selection - 1 : top_choice;
            2'b01: next_selection = (current_selection < top_choice) ? current_selection + 1 : BOTTOM_CHOICE;
            default: next_selection = current_selection; // if they hit both buttons or neither, don't change
        endcase
    end
    
    // output/state updates
    assign choice = current_selection;
    always_ff @(posedge clk_in) begin
        if(rst_in) begin
            current_selection <= BOTTOM_CHOICE;
        end else begin
            current_selection <= next_selection;
        end
    end
endmodule

