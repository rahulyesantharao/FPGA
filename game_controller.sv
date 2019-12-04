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
    input logic [1:0] game_type_in,
    output logic [2:0] vga_mode,
    output logic [1:0] menu_select,
    output logic [34:0] current_notes,
    output logic [11:0] current_score,
    output logic shifting_out,
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
localparam STATE_LEARN = 4'd4;
localparam STATE_FINISH = 4'd5; // can reset back to IDLE with btnc

// Game types
localparam TYPE_PLAY = 2'd0;
localparam TYPE_LEARN = 2'd1;

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
localparam NOTE_LENGTH = 26'd50_000_000; // switch notes every half second

// State
logic [3:0] state = STATE_IDLE;
logic [11:0] score = 12'd0;
logic [23:0] score_counter = 24'd0;
logic [1:0] game_type;
logic [MODE_BITS - 1:0] mode_choice = MODE_KEYBOARD;
logic [SONG_BITS - 1:0] song_choice;
logic advance_note;

// only used in learning mode
logic [6:0] old_input_note;
logic [25:0] old_input_note_counter;

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
logic [34:0] song_notes;
song_select song_selector(.clk_in(clk_in), .rst_in(rst_in), .start(song_start), .game_type_in(game_type), .song_choice(song_choice), .advance_note(advance_note), .notes(song_notes), .shifting_out(shifting_out));

// STATE TRANSITIONS ------------------------------------------
logic [3:0] next_state;
logic [9:0] next_score;
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
    if(game_on) begin
        next_game_type = game_type; // once the game is on, type is fixed
        next_old_input_note = input_note;
        case(state)
            STATE_IDLE: begin
                next_state = (btnc) ? STATE_IDLE : STATE_SONG_SELECT; // skip over mode select
                // don't really matter
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_MODE_SELECT: begin
                next_state = (btnc) ? STATE_SONG_SELECT : STATE_MODE_SELECT;
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = current_mode_choice; // keep changing with current choice
                next_song_choice = song_choice; // don't change
                next_song_start = 1'b0;
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_SONG_SELECT: begin
                next_state = (btnc) ? ((game_type == TYPE_PLAY) ? STATE_PLAY : STATE_LEARN) : STATE_SONG_SELECT;
                next_score = 10'd0; // just zero these out until they are needed
                next_score_counter = 24'd0;
                next_mode_choice = mode_choice; // don't change
                next_song_choice = current_song_choice; // keep changing with current choice
                next_song_start = (btnc) ? 1'b1 : 1'b0; // if we are about to start playing, then send in the song choice
                next_advance_note = 1'b0;
                next_old_input_note_counter = 26'd0;
            end
            STATE_PLAY: begin
                if(song_notes[34:28] == SONG_FINISH) begin
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
                        next_score = score + ((input_note == song_notes[34:28]) ? 12'd1 : 12'd0);
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
                    next_state = STATE_FINISH;
                    next_advance_note = 1'b0;
                    next_old_input_note_counter = 26'd0;
                end else begin
                    next_state = STATE_LEARN;
                    // advance to the next note if the played note is correct
                    if((input_note == song_notes[34:28]) && (input_note == old_input_note)) begin
                        if(old_input_note_counter == NOTE_LENGTH - 26'd1) begin
                            next_advance_note = 1'b1;
                            next_old_input_note_counter = 26'd0;
                        end else begin
                            next_advance_note = 1'b0;
                            next_old_input_note_counter = old_input_note_counter + 26'd1;
                        end
                    end else begin
                        next_advance_note = 1'b0;
                        next_old_input_note_counter = 26'd0;
                    end
                end
                // maintain these values
                next_score = score; // no scoring in learning mode
                next_score_counter = score_counter;
                next_mode_choice = mode_choice;
                next_song_choice = song_choice;
                next_song_start = 1'b0; // don't restart the song once we have entered game mode
            end
            STATE_FINISH: begin // btnc starts over
                next_state = (btnc) ? STATE_IDLE : STATE_FINISH;
                next_score = score;
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
        next_score = 12'd0;
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
localparam MAIN_MENU = 3'b000;
    localparam KEYBOARD_INSTRUCTIONS = 3'b001;
    localparam SONG_INSTRUCTIONS = 3'b010;
    localparam BASIC_SONG_MENU = 3'b011;
    localparam CUSTOM_SONG_MENU = 3'b100;
    localparam LEARN_MODE = 3'b101;
    localparam GAME_MODE = 3'b110;

assign vga_mode = (state == STATE_MODE_SELECT) ? VGA_MODE_SELECT : 
                    ((state == STATE_SONG_SELECT) ? BASIC_SONG_MENU : 
                        ((state == STATE_PLAY) ? GAME_MODE : 
                            ((state == STATE_LEARN) ? LEARN_MODE : MAIN_MENU)));
assign menu_select = (state == STATE_MODE_SELECT) ? current_mode_choice : current_song_choice;
assign current_notes = song_notes;
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
        game_type <= TYPE_PLAY;
        advance_note <= 1'b0;
        old_input_note <= 7'd0;
        old_input_note_counter <= 26'd0;
    end else begin
        state <= next_state;
        score <= next_score;
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


// TODO: shift out five to start, and then start doing slow shifts
module song_select (
    input logic clk_in,
    input logic rst_in,
    input logic start,
    input logic [1:0] game_type_in,
    input logic [1:0] song_choice,
    input logic advance_note,
    output logic [34:0] notes,
    output logic shifting_out
);
    localparam NOTE_LENGTH = 26'd50_000_000; // switch notes every half second
    localparam INIT_NOTES = 35'd0;
    localparam INIT_ADDR = 10'd0;
    
    // Game types
    localparam TYPE_PLAY = 2'd0;
    localparam TYPE_LEARN = 2'd1;

    // STATE ----------------------------------
    logic [34:0] current_notes = INIT_NOTES;
    logic [25:0] counter = NOTE_LENGTH - 26'd1;
    logic [9:0] current_addr = INIT_ADDR;
    logic [3:0] start_counter = 4'd10; // 10 = stable value, 11 -> 0 in one cycle, 0*2 -> 4*2+1 read start values
    logic [1:0] game_type;
    logic shifting;
    
    // BROM -----------------------------------
    logic [7:0] read_note;
    song_rom my_songs(.clka(clk_in), .addra(current_addr), .douta(read_note));
    
    // STATE TRANSITIONS ----------------------
    logic [34:0] next_notes;
    logic [25:0] next_counter;
    logic [9:0] next_addr;
    logic [3:0] next_start_counter;
    logic next_shifting;
    always_comb begin
        if(start_counter < 4'd10) begin
          if(start_counter & 4'b1 == 4'b1) begin
            next_notes = {current_notes[27:0], read_note[6:0]}; // shift in new note
            next_addr = current_addr + 10'd1;
            next_shifting = 1'b1;
          end else begin
            next_notes = current_notes; // wait for the next note to be read
            next_addr = current_addr;
            next_shifting = 1'b0;
          end
          next_counter = 26'd0;
          next_start_counter = start_counter + 4'd1;
        end
        else begin
            case(game_type)
                TYPE_PLAY: begin
                    if(counter < NOTE_LENGTH - 26'd1) begin
                        next_notes = current_notes; // stay on same notes
                        next_counter = counter + 26'd1;
                        next_addr = current_addr;
                        next_shifting = 1'b0;
                    end else begin
                        next_notes = {current_notes[27:0], read_note[6:0]}; // shift in new note
                        next_counter = 26'd0;
                        next_addr = current_addr + 10'd1;
                        next_shifting = 1'b1;
                    end
                end
                TYPE_LEARN: begin
                    if(advance_note) begin
                        next_notes = {current_notes[27:0], read_note[6:0]}; // shift in new note
                        next_addr = current_addr + 10'd1;
                        next_shifting = 1'b1;
                    end else begin
                        next_notes = current_notes; // stay on same notes
                        next_addr = current_addr;
                        next_shifting = 1'b0;
                    end
                    next_counter = 26'd0; // don't use counter
                end
            endcase
            next_start_counter = (start_counter == 4'd11) ? 4'd0 : 4'd10;
        end
    end
    
    // OUTPUT & STATE UPDATE ------------------
    assign notes = current_notes;
    assign shifting_out = shifting;
    always_ff @(posedge clk_in) begin
        if(rst_in) begin
            current_notes <= INIT_NOTES;
            counter <= NOTE_LENGTH - 26'd1;
            current_addr <= INIT_ADDR;
            start_counter <= 4'd10;
            game_type <= TYPE_PLAY;
            shifting <= 1'b0;
        end else if(start) begin
            current_notes <= INIT_NOTES;
            counter <= 26'd0;
            current_addr <= 250 * song_choice;
            start_counter <= 4'd11; // start sentinel value
            game_type <= game_type_in; // latch game type
            shifting <= 1'b0;
        end else begin
            current_notes <= next_notes;
            counter <= next_counter;
            current_addr <= next_addr;
            start_counter <= next_start_counter;
            game_type <= game_type; // only reset on start
            shifting <= next_shifting;
        end 
    end
endmodule
