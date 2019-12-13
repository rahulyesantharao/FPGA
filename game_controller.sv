`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////
// Game Controller Module - Runs the entire game, including Learn and Play
// modes.
//  - Takes in inputs from the outer level, including button presses
//    to interact with menus and the notes played by the user (on keyboard
//    and microphone).
//  - Outputs the state of the game, including score, current notes, and 
//    VGA mode, to be displayed by the VGA helper.
module game_controller
(
    input logic clk_in, // input clock
    input logic rst_in, // reset signal
    input logic game_on, // indicates whether the game is currently active
    input logic btnu, // up button (menu navigation)
    input logic btnd, // down button (menu navigation)
    input logic btnc, // center button (select)
    input logic [6:0] keyboard_note, // the note being played on the keyboard
    input logic [6:0] mic_note, // the note being sung into the mic
    input logic [1:0] game_type_in, // the current game type (play or learn)
    output logic [2:0] vga_mode, // the current VGA mode, to be fed to [pixel_helper]
    output logic [1:0] menu_select, // the current menu choice, for [pixel_helper]
    output logic [34:0] current_notes, // the current notes being played, for [pixel_helper]
    output logic [11:0] current_score, // the current score 
    output logic [11:0] current_max_score, // the maximum possible score
    output logic shifting_out, // a pulse to indicate when a new note is shifted in 
    // debug
    output logic [3:0] game_state_out, // the internal game state
    output logic [1:0] mode_choice_out, // the current mode choice
    output logic [1:0] song_choice_out, // the current song choice
    // song select
    input logic [7:0] song_select_read_note, // the note being read from the song BRAM
    output logic [9:0] song_select_current_addr, // the address to read from the song BRAM
    // custom song bit
    input logic custom_song_activated // whether or not a custom song exists, for the song menu
);
// Game FSM states
localparam STATE_IDLE = 4'd0;
localparam STATE_MODE_SELECT = 4'd1;
localparam STATE_SONG_SELECT = 4'd2;
localparam STATE_PLAY = 4'd3;
localparam STATE_LEARN = 4'd4;
localparam STATE_FINISH = 4'd5; // can reset back to IDLE with btnc

// Game types
localparam TYPE_PLAY = 2'd3;
localparam TYPE_LEARN = 2'd2;

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
localparam SONG_FINISH = 7'b111_1100;

// Scoring
localparam SCORE_INTERVAL = 24'd10_000_000;
localparam NOTE_LENGTH = 26'd25_000_000; // switch notes every quarter second

// State
logic [3:0] state = STATE_IDLE; 
logic [11:0] score = 12'd0; // player's current score
logic [11:0] max_score = 12'd0; // maximum possible score at the moment
logic [23:0] score_counter = 24'd0; // counter to track scoring intervals
logic [1:0] game_type; // learn/play
logic [MODE_BITS - 1:0] mode_choice = MODE_KEYBOARD; // WIP: for the singing stretch goal
logic [SONG_BITS - 1:0] song_choice = 2'd0; // menu choice of which song to play/learn
logic advance_note; // indicates that a new note is shifting in

// only used in learning mode
logic [6:0] old_input_note; // used to track length of current note being played
logic [25:0] old_input_note_counter;

// HELPER MODULES -----------
// mode menu
logic [MODE_BITS - 1:0] current_mode_choice;
menu #(.NUM_BITS(MODE_BITS), .BOTTOM_CHOICE(MODE_KEYBOARD)) 
    mode_menu(.clk_in(clk_in), .rst_in(rst_in), .btn_up(btnu), 
      .btn_down(btnd), .choice(current_mode_choice), .top_choice(MODE_MIC));

// song selection menu
logic [SONG_BITS - 1:0] current_song_choice;
menu #(.NUM_BITS(SONG_BITS), .BOTTOM_CHOICE(SONG_1)) 
    song_menu(.clk_in(clk_in), .rst_in(rst_in), .btn_up(btnu), 
      .btn_down(btnd), .choice(current_song_choice), 
      .top_choice((custom_song_activated ? SONG_4 : SONG_3)));

// song select module
logic song_start;
logic [34:0] song_notes;

song_select song_selector(.clk_in(clk_in), .rst_in(rst_in), .start(song_start), 
  .game_type_in(game_type), .song_choice(song_choice), .advance_note(advance_note), 
  .notes(song_notes), .shifting_out(shifting_out),.read_note_in(song_select_read_note), 
  .current_addr_out(song_select_current_addr));

// STATE TRANSITIONS ------------------------------------------
logic [3:0] next_state;
logic [11:0] next_score;
logic [11:0] next_max_score;
logic [23:0] next_score_counter;
logic [MODE_BITS - 1:0] next_mode_choice;
logic [SONG_BITS - 1:0] next_song_choice;
logic next_song_start;
logic [1:0] next_game_type;
logic next_advance_note;

// only used in learning mode
logic [6:0] next_old_input_note;
logic [25:0] next_old_input_note_counter;

logic [6:0] input_note;
assign input_note = (mode_choice == MODE_KEYBOARD) ? keyboard_note : mic_note;
always_comb begin
    if(game_on) begin // only track states if currently in play/learn mode
        next_game_type = game_type; // once the game is on, type is fixed
        next_old_input_note = input_note;
        case(state)
            STATE_IDLE: begin
                next_state = STATE_SONG_SELECT; 
                // hold these values until the next scoring period
                next_score = score; 
                next_max_score = max_score;
                // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice;
                next_song_choice = 2'd0;
                next_song_start = 1'b0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_MODE_SELECT: begin // WIP: used for singing stretch goal
                next_state = (btnc) ? STATE_SONG_SELECT : STATE_MODE_SELECT;
                // hold until the next scoring period
                next_score = score; 
                next_max_score = max_score;
                next_mode_choice = current_mode_choice; // keep changing with current choice
                next_song_choice = song_choice; // don't change
                // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_song_start = 1'b0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_SONG_SELECT: begin
                next_state = (btnc) ? 
                  ((game_type == TYPE_PLAY) ? STATE_PLAY : STATE_LEARN) : STATE_SONG_SELECT;
                // reset these values when the game/learning is started
                next_score = (btnc) ? 12'd0 : score; 
                next_max_score = (btnc) ? 12'd0 : max_score;
                next_mode_choice = mode_choice; // don't change
                next_song_choice = current_song_choice; // keep changing with current choice
                // signal when the song is about to start
                next_song_start = (btnc) ? 1'b1 : 1'b0; 
                // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_PLAY: begin
                if(song_notes[34:28] == SONG_FINISH) begin
                    // we have reached the end of the song, transition to the
                    // FINISH state
                    next_state = STATE_FINISH;
                    next_score = score;
                    next_max_score = max_score;
                    next_score_counter = 24'd0;
                end else begin
                    next_state = STATE_PLAY;
                    // update the score every SCORE_INTERVAL/10M seconds
                    if(score_counter < SCORE_INTERVAL - 24'd1) begin
                        next_score = score;
                        next_max_score = max_score;
                        next_score_counter = score_counter + 24'd1;
                    end else begin
                        // sample and check whether the input note is correct
                        next_score = score + 
                          ((input_note == song_notes[34:28]) ? 12'd1 : 12'd0);
                        next_max_score = max_score + 12'd1;
                        next_score_counter = 24'd0;
                    end
                end
                // maintain these values
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0; // don't restart the song once we have entered game mode
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_LEARN: begin
                if(song_notes[34:28] == SONG_FINISH) begin
                    // we have reached the end of the song, transition to the
                    // FINISH state
                    next_state = STATE_FINISH;
                    next_advance_note = 1'b0;
                    next_old_input_note_counter = 26'd0;
                end else begin
                    next_state = STATE_LEARN;
                    // advance to the next note if the played note is correct
                    // and has been held for the appropriate length
                    if((input_note == song_notes[34:28]) && (input_note == old_input_note)) begin
                        next_advance_note = (old_input_note_counter == NOTE_LENGTH - 26'd1) ?
                          1'b1 : 1'b0;
                        next_old_input_note_counter = 
                          (old_input_note_counter == NOTE_LENGTH - 26'd1) ? 
                            26'd0 : old_input_note_counter + 26'd1;
                    end else begin
                        next_advance_note = 1'b0;
                        next_old_input_note_counter = 26'd0;
                    end
                end
                // maintain these values
                next_score = score; // no scoring in learning mode
                next_max_score = max_score;
                next_score_counter = score_counter;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0; // don't restart the song once we have entered game mode
            end
            STATE_FINISH: begin
                // this state serves to reset state and signal the end to
                // top_level
                next_state = STATE_IDLE;
                next_score = score;
                next_max_score = max_score;
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
        endcase
    end else begin
        // game is turned off, switch back to initial state
        next_state = STATE_IDLE;
        next_score = score;
        next_max_score = max_score;
        next_score_counter = 24'd0;
        next_mode_choice = MODE_KEYBOARD;
        next_song_choice = 2'd0;
        next_song_start = 1'b0;
        next_game_type = game_type_in; // latch the game type
        next_advance_note = 1'b0;
        next_old_input_note = 7'd0;
        next_old_input_note_counter = 26'd0;
    end
end


// OUTPUT & STATE UPDATE -------------------------------------
// VGA helper signals
localparam MAIN_MENU = 3'b000;
localparam KEYBOARD_INSTRUCTIONS = 3'b001;
localparam SONG_INSTRUCTIONS = 3'b010;
localparam BASIC_SONG_MENU = 3'b011;
localparam CUSTOM_SONG_MENU = 3'b100;
localparam LEARN_MODE = 3'b101;
localparam GAME_MODE = 3'b110;

// a large multiplexer to decide what to display on the screen
assign vga_mode = (state == STATE_MODE_SELECT) ? MAIN_MENU : 
                    ((state == STATE_SONG_SELECT) ? (custom_song_activated ? CUSTOM_SONG_MENU : BASIC_SONG_MENU) : 
                        ((state == STATE_PLAY) ? GAME_MODE : 
                            ((state == STATE_LEARN) ? LEARN_MODE : MAIN_MENU)));

// make most of the state available to top_level
assign menu_select = (state == STATE_MODE_SELECT) ? current_mode_choice : current_song_choice;
assign current_notes = song_notes;
assign current_score = score;
assign current_max_score = max_score;
assign game_state_out = state;
assign mode_choice_out = mode_choice;
assign song_choice_out = song_choice;
always_ff @(posedge clk_in) begin
    if(rst_in) begin // reset to zeroed out values
        state <= STATE_IDLE;
        score <= 12'd0;
        max_score <= 12'd0;
        score_counter <= 24'd0;
        mode_choice <= MODE_KEYBOARD;
        song_choice <= 2'd0;
        song_start <= 1'b0;
        game_type <= TYPE_PLAY;
        advance_note <= 1'b0;
        old_input_note <= 7'd0;
        old_input_note_counter <= 26'd0;
    end else begin
        state <= next_state;
        score <= next_score;
        max_score <= next_max_score;
        score_counter <= next_score_counter;
        mode_choice <= next_mode_choice;
        song_choice <= next_song_choice;
        song_start <= next_song_start;
        game_type <= next_game_type;
        advance_note <= next_advance_note;
        old_input_note <= next_old_input_note;
        old_input_note_counter <= next_old_input_note_counter;
    end
end

endmodule


///////////////////////////////////////////////////////////////
// Song Select Module - Serves as an interface between the Game Controller
// Module and the song BRAM.
//    - Takes as input the song choice and signals to start the song
//      and advance notes, as well as the note read from the BRAM
//    - Outputs the shift register of active notes and the address to 
//      read from the BRAM
module song_select (
    input logic clk_in, // input clock
    input logic rst_in, // system reset
    input logic start,  // pulse to start outputting song addresses
    input logic [1:0] game_type_in, // current game type (play/learn)
    input logic [1:0] song_choice, // song index
    input logic advance_note, // pulse to indicate a note advance (only for learn mode)
    input logic [7:0] read_note_in, // the note read from the song BRAM (in top_level)
    output logic [34:0] notes, // the 5-note shift register, [34:28] is the current note
    output logic shifting_out, // a pulse to indicate a new note shifting in
    output logic [9:0] current_addr_out // the address to read from the song BRAM
);
// Constants ----------------------------------
localparam NOTE_LENGTH = 26'd25_000_000; // switch notes every half second

// Initial values for outputs
localparam INIT_NOTES = 35'd0;
localparam INIT_ADDR = 10'd0;

// Game types
localparam TYPE_PLAY = 2'd3;
localparam TYPE_LEARN = 2'd2;

// Special note indices
localparam END_NOTE = 7'b111_1100;
localparam REST = 7'b111_1111;

// STATE ----------------------------------
logic [34:0] current_notes = INIT_NOTES;
logic [25:0] counter = NOTE_LENGTH - 26'd1;
logic [9:0] current_addr = INIT_ADDR; // current address in the song BRAM
logic [3:0] start_counter = 4'd10; // a special register to deal with the startup routine
logic [1:0] game_type; // holds the type for the current song
logic shifting; // a pulse to indicate a note shifting in 
// a shift register to hold the shifting signal (so it can be properly synchronized to 65MHz).
logic [3:0] shifting_regs = 4'd0; 
logic end_notes = 1'b1; // a special state to fill the register with RESTs at the end
    
// BRAM Values -----------------------------------
logic [7:0] read_note;
// if the end of the song has been reached, only shift in rests.
assign read_note = end_notes ? REST : read_note_in; 
    
// STATE TRANSITIONS ----------------------
logic [34:0] next_notes;
logic [25:0] next_counter;
logic [9:0] next_addr;
logic [3:0] next_start_counter;
logic next_shifting;
logic next_end_notes;

always_comb begin
    // Startup routine: Quickly shift the first 5 notes into the register in
    // 10 cycles (2-cycle latency in song BRAM)
    if(start_counter < 4'd10) begin
      // Every other cycle, shift in a new note
      next_notes = (start_counter & 4'b1 == 4'b1) ? 
        {current_notes[27:0], read_note[6:0]} : current_notes;
      next_end_notes = (start_counter & 4'b1 == 4'b1) ? 
        ((read_note[6:0] == END_NOTE) ? 1'b1 : 1'b0) : 1'b0;
      next_addr = (start_counter & 4'b1 == 4'b1) ? current_addr + 10'd1 : current_addr;
      next_shifting = (start_counter & 4'b1 == 4'b1)? 1'b1 : 1'b0;
      // hold the regular counter and increment the startup counter
      next_counter = 26'd0;
      next_start_counter = start_counter + 4'd1;
    end
    else begin
        // Regular Operation
        case(game_type)
            TYPE_PLAY: begin // Play mode, automatically shift a new note every NOTE_LENGTH/100M seconds
                if(counter < NOTE_LENGTH - 26'd1) begin
                    next_notes = current_notes; // stay on same notes
                    next_end_notes = 1'b0;
                    next_counter = counter + 26'd1;
                    next_addr = current_addr;
                    next_shifting = 1'b0;
                end else begin
                    next_notes = {current_notes[27:0], read_note[6:0]}; // shift in new note
                    next_end_notes = (read_note[6:0] == END_NOTE) ? 1'b1 : 1'b0;
                    next_counter = 26'd0;
                    next_addr = current_addr + 10'd1;
                    next_shifting = 1'b1;
                end
            end
            TYPE_LEARN: begin // Learn mode, only shift in new notes when [advance_note] is high
                if(advance_note | current_notes[34:28] == END_NOTE) begin
                    next_notes = {current_notes[27:0], read_note[6:0]}; // shift in new note
                    next_end_notes = (read_note[6:0] == END_NOTE) ? 1'b1 : 1'b0;
                    next_addr = current_addr + 10'd1;
                    next_shifting = 1'b1;
                end else begin
                    next_notes = current_notes; // stay on same notes
                    next_end_notes = 1'b0;
                    next_addr = current_addr;
                    next_shifting = 1'b0;
                end
                next_counter = 26'd0; // don't use counter
            end
        endcase
        next_start_counter = (start_counter == 4'd11) ? 4'd0 : 4'd10; // 4'd11 is a sentinel to goto startup
    end
end
    
// OUTPUT & STATE UPDATE ------------------
assign notes = current_notes;
assign shifting_out = shifting;
assign current_addr_out = current_addr;
always_ff @(posedge clk_in) begin
    if(rst_in) begin // reset to initial values
        current_notes <= INIT_NOTES;
        counter <= NOTE_LENGTH - 26'd1;
        current_addr <= INIT_ADDR;
        start_counter <= 4'd10;
        game_type <= TYPE_PLAY;
        shifting <= 1'b0;
        shifting_regs <= 4'd0;
        end_notes <= 1'b1;
    end else if(start) begin
        current_notes <= INIT_NOTES;
        counter <= 26'd0;
        current_addr <= 250 * song_choice;
        start_counter <= 4'd11; // start sentinel value
        game_type <= game_type_in; // latch game type
        shifting <= 1'b0;
        shifting_regs <= 4'd0;
        end_notes <= 1'b0;
    end else begin
        current_notes <= next_notes;
        counter <= next_counter;
        current_addr <= next_addr;
        start_counter <= next_start_counter;
        game_type <= game_type; // only reset on start
        shifting <= |shifting_regs[3:0]; // shift high for 4 cycles, so it can sync to 65MHz
        end_notes <= next_end_notes | end_notes;
        shifting_regs[3:0] <= {shifting_regs[2:0], next_shifting};
    end 
end
endmodule
