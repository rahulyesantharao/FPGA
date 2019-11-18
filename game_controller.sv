module game_controller
#(
    // VGA Mode values
    parameter VGA_IDLE = 3'd0,
    parameter VGA_MODE_SELECT = 3'd0,
    parameter VGA_SONG_SELECT = 3'd1,
    parameter VGA_GAME_PLAY = 3'd2,
    parameter VGA_GAME_FINISH = 3'd3
)
(
    input logic clk_in,
    input logic rst_in,
    input logic game_on,
    input logic btnu,
    input logic btnd,
    input logic btnc,
    input logic [6:0] keyboard_note,
    input logic [6:0] mic_note,
    output logic [2:0] vga_mode,
    output logic [1:0] menu_select,
    output logic [6:0] current_note,
    output logic [11:0] current_score,
    // debug
    output logic [3:0] game_state_out,
    output logic [1:0] mode_choice_out,
    output logic [1:0] song_choice_out
);
// Game FSM states
localparam STATE_IDLE = 4'd0;
localparam STATE_MODE_SELECT = 4'd1;
localparam STATE_SONG_SELECT = 4'd2;
localparam STATE_PLAY = 4'd3;
localparam STATE_FINISH = 4'd4; // absorbing state, can't escape

// Game modes
localparam MODE_BITS = 2;
localparam MODE_KEYBOARD = 2'd0;
localparam MODE_MIC = 2'd1;

// Song choice
localparam SONG_BITS = 2;
localparam SONG_1 = 2'd0;
localparam SONG_2 = 2'd1;
localparam SONG_3 = 2'd2;
localparam SONG_4 = 2'd3;
localparam SONG_FINISH = 7'b111_1111;

// Scoring
localparam SCORE_INTERVAL = 24'd10_000_000;

// State
logic [3:0] state = STATE_IDLE;
logic [11:0] score = 12'd0;
logic [23:0] score_counter = 24'd0;
logic [MODE_BITS - 1:0] mode_choice = MODE_KEYBOARD;
logic [SONG_BITS - 1:0] song_choice;


// HELPER MODULES -----------
// mode menu
logic [MODE_BITS - 1:0] current_mode_choice;
menu #(.NUM_BITS(MODE_BITS), .BOTTOM_CHOICE(MODE_KEYBOARD), .TOP_CHOICE(MODE_MIC)) 
    mode_menu(.clk_in(clk_in), .rst_in(rst_in), .btn_up(btnu), .btn_down(btnd), .choice(current_mode_choice));

// song selection menu
logic [SONG_BITS - 1:0] current_song_choice;
menu #(.NUM_BITS(SONG_BITS), .BOTTOM_CHOICE(SONG_1), .TOP_CHOICE(SONG_4)) 
    song_menu(.clk_in(clk_in), .rst_in(rst_in), .btn_up(btnu), .btn_down(btnd), .choice(current_song_choice));

// song select module
logic song_start;
logic [6:0] song_note;
song_select song_selector(.clk_in(clk_in), .rst_in(rst_in), .start(song_start), .song_choice(song_choice), .note(song_note));

// STATE TRANSITIONS ------------------------------------------
logic [3:0] next_state;
logic [9:0] next_score;
logic [23:0] next_score_counter;
logic [MODE_BITS - 1:0] next_mode_choice;
logic [SONG_BITS - 1:0] next_song_choice;
logic next_song_start;

logic [6:0] input_note;
assign input_note = (mode_choice == MODE_KEYBOARD) ? keyboard_note : mic_note;
always_comb begin
    if(game_on) begin
        case(state)
            STATE_IDLE: begin
                next_state = STATE_SONG_SELECT; // skip over mode select
                // don't really matter
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0;
            end
            STATE_MODE_SELECT: begin
                next_state = (btnc) ? STATE_SONG_SELECT : STATE_MODE_SELECT;
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = current_mode_choice; // keep changing with current choice
                next_song_choice = song_choice; // don't change
                next_song_start = 1'b0;
            end
            STATE_SONG_SELECT: begin
                next_state = (btnc) ? STATE_PLAY : STATE_SONG_SELECT;
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice; // don't change
                next_song_choice = current_song_choice; // keep changing with current choice
                next_song_start = (btnc) ? 1'b1 : 1'b0; // if we are about to start playing, then send in the song choice
            end
            STATE_PLAY: begin
                if(song_note == SONG_FINISH) begin
                    next_state = STATE_FINISH;
                    next_score = score;
                    next_score_counter = 24'd0;
                end else begin
                    next_state = STATE_PLAY;
                    // update the score every SCORE_INTERVAL/10M seconds
                    if(score_counter < SCORE_INTERVAL - 24'd1) begin
                        next_score = score;
                        next_score_counter = score_counter + 24'd1;
                    end else begin
                        next_score = score + ((input_note == song_note) ? 12'd1 : 12'd0);
                        next_score_counter = 24'd0;
                    end
                end
                // maintain these values
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0; // don't restart the song once we have entered game mode
            end
            STATE_FINISH: begin // for now, absorbing state that displays score
                next_state = STATE_FINISH;
                next_score = score;
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0;
            end
        endcase
    end else begin
        // game is turned off, switch back to initial state
        next_state = STATE_IDLE;
        next_score = 12'd0;
        next_score_counter = 24'd0;
        next_mode_choice = MODE_KEYBOARD;
        next_song_choice = 2'd0;
        next_song_start = 1'b0;
    end
end


// OUTPUT & STATE UPDATE -------------------------------------
assign vga_mode = (state == STATE_MODE_SELECT) ? VGA_MODE_SELECT : 
                    ((state == STATE_SONG_SELECT) ? VGA_SONG_SELECT : 
                        ((state == STATE_PLAY) ? VGA_GAME_PLAY : 
                            ((state == STATE_FINISH) ? VGA_GAME_FINISH : VGA_IDLE)));
assign menu_select = (state == STATE_MODE_SELECT) ? current_mode_choice : current_song_choice;
assign current_note = song_note;
assign current_score = score;
assign game_state_out = state;
assign mode_choice_out = mode_choice;
assign song_choice_out = song_choice;
always_ff @(posedge clk_in) begin
    if(rst_in) begin
        state <= STATE_IDLE;
        score <= 10'd0;
        score_counter <= 24'd0;
        mode_choice <= MODE_KEYBOARD;
        song_choice <= 2'd0;
        song_start <= 1'b0;
    end else begin
        state <= next_state;
        score <= next_score;
        score_counter <= next_score_counter;
        mode_choice <= next_mode_choice;
        song_choice <= next_song_choice;
        song_start <= next_song_start;
    end
end

endmodule

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

// TODO: shift out five to start, and then start doing slow shifts
module song_select (
    input logic clk_in,
    input logic rst_in,
    input logic start,
    input logic [1:0] song_choice,
    output logic [6:0] note
);
    localparam NOTE_LENGTH = 26'd50_000_000; // switch notes every half second
    localparam INIT_NOTE = 8'd0;
    localparam INIT_ADDR = 10'd0;
    
    // STATE ----------------------------------
    logic [7:0] current_note = INIT_NOTE;
    logic [25:0] counter = NOTE_LENGTH - 26'd1;
    logic [9:0] current_addr = INIT_ADDR;
    
    // BROM -----------------------------------
    logic [7:0] read_note;
    song_rom my_songs(.clka(clk_in), .addra(current_addr), .douta(read_note));
    
    // STATE TRANSITIONS ----------------------
    logic [6:0] next_note;
    logic [25:0] next_counter;
    logic [9:0] next_addr;
    always_comb begin
        if(counter < NOTE_LENGTH - 26'd1) begin
            next_note = current_note;
            next_counter = counter + 26'd1;
            next_addr = current_addr;
        end else begin
            next_note = read_note[6:0];
            next_counter = 26'd0;
            next_addr = current_addr + 10'd1;
        end
    end
    
    // OUTPUT & STATE UPDATE ------------------
    assign note = current_note;
    always_ff @(posedge clk_in) begin
        if(rst_in) begin
            current_note <= INIT_NOTE;
            counter <= NOTE_LENGTH - 26'd1;
            current_addr <= INIT_ADDR;
        end else if(start) begin
            current_note <= INIT_NOTE;
            counter <= NOTE_LENGTH - 26'd1;
            current_addr <= 250 * song_choice;
        end else begin
            current_note <= next_note;
            counter <= next_counter;
            current_addr <= next_addr;
        end 
    end
endmodule