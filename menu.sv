// In general, the menu should deal with 2-bit indices
// A selection menu; continuously outputs the current choice
module menu
#(
    parameter NUM_BITS = 2,
    parameter BOTTOM_CHOICE = 2'd0,
    parameter TOP_CHOICE = 2'd3
)
(
    input logic clk_in,
    input logic rst_in,
    input logic btn_up,
    input logic btn_down,
    output logic [NUM_BITS - 1:0] choice
);
    // current selection
    logic [NUM_BITS - 1:0] current_selection = BOTTOM_CHOICE;
    
    // state transition
    logic [NUM_BITS - 1:0] next_selection;
    always_comb begin
        case({btn_up, btn_down})
            2'b10: next_selection = (current_selection < TOP_CHOICE) ? current_selection + 1 : current_selection;
            2'b01: next_selection = (current_selection > BOTTOM_CHOICE) ? current_selection - 1 : current_selection;
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

