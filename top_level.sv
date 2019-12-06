// Top level module
// TODO: figure out what inputs to use, uncomment appropriately in xdc
module top_level(
  input clk_100mhz,
  input [15:0] sw,
  input btnc, btnu, btnd, btnr, btnl,
  input vauxp3,
  input vauxn3,
  input vn_in,
  input vp_in,
  input [7:0] jb,
  output logic [15:0] led,
  output logic ca, cb, cc, cd, ce, cf, cg, dp,
  output logic [7:0] an,
  output logic aud_pwm,
  output logic aud_sd,
  output[3:0] vga_r,
output[3:0] vga_b,
output[3:0] vga_g,
output vga_hs,
output vga_vs
);

// setup clocks
wire clk_104mhz, clk_65mhz;
clk_wiz_0 clockgen(
    .clk_in1(clk_100mhz),
    .clk_out1(clk_104mhz),
    .clk_out2(clk_65mhz));

// debounce reset
logic reset;
debounce btnr_debounce(.clk_in(clk_100mhz), .noisy_in(btnr), .clean_out(reset));

// synchronize switches
logic [15:0] sync_sw;
synchronize sw0_sync(.clk_in(clk_100mhz), .unsync_in(sw[0]), .sync_out(sync_sw[0]));
synchronize sw1_sync(.clk_in(clk_100mhz), .unsync_in(sw[1]), .sync_out(sync_sw[1]));
synchronize sw2_sync(.clk_in(clk_100mhz), .unsync_in(sw[2]), .sync_out(sync_sw[2]));
synchronize sw3_sync(.clk_in(clk_100mhz), .unsync_in(sw[3]), .sync_out(sync_sw[3]));
synchronize sw4_sync(.clk_in(clk_100mhz), .unsync_in(sw[4]), .sync_out(sync_sw[4]));
synchronize sw5_sync(.clk_in(clk_100mhz), .unsync_in(sw[5]), .sync_out(sync_sw[5]));
synchronize sw6_sync(.clk_in(clk_100mhz), .unsync_in(sw[6]), .sync_out(sync_sw[6]));
synchronize sw7_sync(.clk_in(clk_100mhz), .unsync_in(sw[7]), .sync_out(sync_sw[7]));

// debounce buttons
logic db_btnc, db_btnu, db_btnd, db_btnl;
debounce btnc_debounce(.rst_in(reset), .clk_in(clk_100mhz), .noisy_in(btnc), .clean_out(db_btnc));
debounce btnu_debounce(.rst_in(reset), .clk_in(clk_100mhz), .noisy_in(btnu), .clean_out(db_btnu));
debounce btnd_debounce(.rst_in(reset), .clk_in(clk_100mhz), .noisy_in(btnd), .clean_out(db_btnd));
debounce btnl_debounce(.rst_in(reset), .clk_in(clk_100mhz), .noisy_in(btnl), .clean_out(db_btnl));

// 7-segment display
wire [31:0] seg_data;
wire [6:0] segments;
assign {cg, cf, ce, cd, cb, cc, ca} = segments[6:0];
display_8hex seven_seg_display(.clk_in(clk_100mhz), .data_in(seg_data), .seg_out(segments), .strobe_out(an));
assign dp = 1'b1;

// game controller
localparam VGA_IDLE = 3'd0;
localparam VGA_MODE_SELECT = 3'd0;
localparam VGA_SONG_SELECT = 3'd1;
localparam VGA_GAME_PLAY = 3'd2;
localparam VGA_GAME_FINISH = 3'd3;

// edge detectors of up/down buttons
logic old_db_btnd;
logic rising_btnd;
logic old_db_btnu;
logic rising_btnu;
logic old_db_btnc;
logic rising_btnc;

assign rising_btnd = db_btnd & !old_db_btnd;
assign rising_btnu = db_btnu & !old_db_btnu;
assign rising_btnc = db_btnc & !old_db_btnc;

always_ff @(posedge clk_100mhz)begin
    if (reset) begin
        old_db_btnd <= 1'b0;
        old_db_btnu <= 1'b0;
        old_db_btnc <= 1'b0;
    end else begin
        old_db_btnd <= db_btnd;
        old_db_btnu <= db_btnu;
        old_db_btnc <= db_btnc;
    end
end

////// TOP LEVEL FSM ///////////////////////////////////////
// forward declaration of fft stuff
logic rising_lo;
logic rising_hi;
// top level menu
// jacobp - use correct order
localparam TYPE_KEYBOARD = 2'd0;
localparam TYPE_4 = 2'd1;
localparam TYPE_LEARN = 2'd2;
localparam TYPE_PLAY = 2'd3;
// mode menu
logic [1:0] current_type_choice;
menu #(.BOTTOM_CHOICE(TYPE_KEYBOARD), .TOP_CHOICE(TYPE_PLAY)) 
    mode_menu(.clk_in(clk_100mhz), .rst_in(reset), .btn_up(rising_btnu | rising_hi), .btn_down(rising_btnd | rising_lo), .choice(current_type_choice));

logic [3:0] game_state;
localparam GAME_STATE_FINISH = 4'd5;
// state
localparam STATE_MENU = 1'd0;
localparam STATE_TYPE = 1'd1; // absorbing, for now
logic [1:0] current_type;
logic state;
always_ff @(posedge clk_100mhz) begin
    if(reset) begin
        state <= STATE_MENU;
        current_type <= TYPE_PLAY;
    end else begin
        case(state)
            STATE_MENU: begin
              // jacobp - if btnc seems broken, change this back to `db_btnc`
               state <= (db_btnc) ? STATE_TYPE : STATE_MENU;
               current_type <= current_type_choice; // just keep tracking 
            end
            STATE_TYPE: begin
                // absorbing
                state <= (game_state == GAME_STATE_FINISH) ? STATE_MENU : STATE_TYPE;
                current_type <= current_type;
            end
        endcase
    end
end
    
////////////////////////////////////////////////////

// game controller
logic [2:0] game_vga_mode;
logic [1:0] game_menu_pos;
logic [34:0] game_current_notes;
logic [11:0] game_current_score;
logic [11:0] game_current_max_score;
logic is_game_on;
assign is_game_on = (state == STATE_TYPE && (current_type == TYPE_PLAY || current_type == TYPE_LEARN)) ? 1'b1 : 1'b0;

// debug
logic [1:0] mode_choice;
logic [1:0] song_choice;
logic new_note_shifting_in;

logic [6:0] user_note_out;
UART_decoder my_note(.jb(jb), .clk_100mhz(clk_100mhz), .reset(db_btnl), .led(user_note_out));

game_controller #(
    .VGA_IDLE(VGA_IDLE),
    .VGA_MODE_SELECT(VGA_MODE_SELECT),
    .VGA_SONG_SELECT(VGA_SONG_SELECT),
    .VGA_GAME_PLAY(VGA_GAME_PLAY),
    .VGA_GAME_FINISH(VGA_GAME_FINISH))
my_game (
    .clk_in(clk_100mhz),
    .rst_in(reset),
    .game_on(is_game_on),
    .btnu(rising_hi | rising_btnu),
    .btnd(rising_lo | rising_btnd),
    // jacobp - if btnc seems broken, change this back to `db_btnc`
    .btnc(db_btnc),
    //.keyboard_note(sync_sw[6:0]),
    .keyboard_note(user_note_out),
    .mic_note(7'b0),
    .game_type_in(current_type),
    .vga_mode(game_vga_mode),
    .menu_select(game_menu_pos),
    .current_notes(game_current_notes),
    .current_score(game_current_score),
    .current_max_score(game_current_max_score),
    .game_state_out(game_state),
    .mode_choice_out(mode_choice),
    .song_choice_out(song_choice),
    .shifting_out(new_note_shifting_in)
);

// FFT Analyzer
logic fft_hi, fft_lo;
fft_analyzer fft_in(
    .clk_104mhz(clk_104mhz),
    .vauxp3(vauxp3),
    .vauxn3(vauxn3),
    .hi(fft_hi),
    .lo(fft_lo)
);

// synchronize fft lo/hi back to main clock
logic fft_sync_hi, fft_sync_lo;
synchronize sync_fft_hi(
    .clk_in(clk_100mhz),
    .unsync_in(fft_hi),
    .sync_out(fft_sync_hi)
);
synchronize sync_fft_lo(
    .clk_in(clk_100mhz),
    .unsync_in(fft_lo),
    .sync_out(fft_sync_lo)
);

// edge detectors of hi/lo buttons
logic old_sync_lo;
logic old_sync_hi;

assign rising_lo = fft_sync_lo & !old_sync_lo;
assign rising_hi = fft_sync_hi & !old_sync_hi;

always_ff @(posedge clk_100mhz)begin
    if (reset) begin
        old_sync_lo <= 1'b0;
        old_sync_hi  <= 1'b0;
    end else begin
        old_sync_lo <= fft_sync_lo;
        old_sync_hi <= fft_sync_hi;
    end
end


localparam MAIN_MENU = 3'b000;
localparam KEYBOARD_INSTRUCTIONS = 3'b001;
localparam SONG_INSTRUCTIONS = 3'b010;

logic [2:0] full_vga_mode;
assign full_vga_mode = (is_game_on) ? 
  game_vga_mode : ((state == STATE_MENU) ? 
    MAIN_MENU : ((current_type == TYPE_KEYBOARD) ? 
      KEYBOARD_INSTRUCTIONS : SONG_INSTRUCTIONS));
// VGA OUTPUT
logic [6:0] sync65_user_note;
logic [2:0] sync65_full_vga_mode;
logic [1:0] sync65_game_menu_pos;
logic [34:0] sync65_game_current_notes;
logic sync65_new_note_shifting_in;
logic [1:0] sync65_current_type_choice;
synchronize3 sync_full_vga_mode(
    .clk_in(clk_65mhz),
    .unsync_in(full_vga_mode),
    .sync_out(sync65_full_vga_mode)
);
synchronize2 sync_game_menu_pos(
    .clk_in(clk_65mhz),
    .unsync_in(game_menu_pos),
    .sync_out(sync65_game_menu_pos)
);
synchronize35 sync_game_current_notes(
    .clk_in(clk_65mhz),
    .unsync_in(game_current_notes),
    .sync_out(sync65_game_current_notes)
);
synchronize sync_new_note_shifting_in(
    .clk_in(clk_65mhz),
    .unsync_in(new_note_shifting_in),
    .sync_out(sync65_new_note_shifting_in)
);
synchronize2 sync_current_type_choice(
    .clk_in(clk_65mhz),
    .unsync_in(current_type_choice),
    .sync_out(sync65_current_type_choice)
);
synchronize7 sync_user_note(
    .clk_in(clk_65mhz),
    .unsync_in(user_note_out),
    .sync_out(sync65_user_note)
);
    

wire [10:0] hcount;    // pixel on current line
wire [9:0] vcount;     // line number
wire hsync, vsync;
wire [11:0] pixel;
reg [11:0] rgb;
wire blank_ignore;
xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
  .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank_ignore));
  
localparam BASIC_SONG_MENU = 3'b011;
wire phsync,pvsync,pblank;
// jacobp - try making game_vga_mode, game_menu_pos, current_type_choice,
// game_current_notes into the sync65 versions
pixel_helper ph(.clk_65mhz(clk_65mhz), .screen(sync65_full_vga_mode), .selection((sync65_full_vga_mode == BASIC_SONG_MENU) ? sync65_game_menu_pos : sync65_current_type_choice),
            .notes(sync65_game_current_notes), .new_note(sync65_new_note_shifting_in), .learning_note(sync65_game_current_notes[34:28]), .user_note(sync65_user_note),
            .hcount_in(hcount),.vcount_in(vcount),
            .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank_ignore),
            .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(pixel));

reg b,hs,vs;

always_ff @(posedge clk_65mhz) begin
        hs <= phsync;
        vs <= pvsync;
        b <= pblank;
        rgb <= pixel;
    end

// the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;
//////



// DEBUGGING OUTPUT
// segment display
assign seg_data[31:28] = game_state;
assign seg_data[27:16] = game_current_score;
assign seg_data[15:12] = 4'd0;
assign seg_data[11:0] = game_current_max_score;
//assign seg_data[31:28] = game_state;
//assign seg_data[27:24] = {current_type, song_choice};
//assign seg_data[27:24] = {2'b0, current_type};
//assign seg_data[27:24] = {2'b0, mode_choice};
//assign seg_data[27:24] = {2'b0, song_choice};
//assign seg_data[23:16] = 8'd0; // {1'b0, game_current_notes[34:28]};
//assign seg_data[15:12] = 4'd0;
//assign seg_data[11:8] = {1'b0, game_vga_mode}; // {1'b0, game_current_notes[27:21]};
//assign seg_data[7:0] = {1'b0, game_current_notes[20:14]};
//assign seg_data[7:4] = {3'b0, fft_sync_hi};
//assign seg_data[3:0] = {3'b0, fft_sync_lo};
//assign seg_data[15:12] = 4'b0;
//assign seg_data[11:0] = (game_vga_mode == VGA_SONG_SELECT) ? {10'b0, game_menu_pos} : game_current_score;
// leds

localparam GAME_MODE = 3'b110;
localparam LEARN_MODE = 3'b101;
assign led = (game_vga_mode == GAME_MODE || game_vga_mode == LEARN_MODE) ? {1'b0, user_note_out, game_current_notes[34:28]} : 15'b0;

endmodule

module synchronize #(parameter NSYNC=3) (
    input clk_in,
    input unsync_in,
    output reg sync_out
);
reg [NSYNC-2:0] sync;
always_ff @(posedge clk_in) begin
    {sync_out, sync} <= {sync[NSYNC-2:0], unsync_in};
end
endmodule

module synchronize3 (
    input clk_in,
    input [2:0] unsync_in,
    output reg [2:0] sync_out
);
reg [8:0] sync;
always_ff @(posedge clk_in) begin
    {sync_out[2:0], sync[8:0]} <= {sync[8:0], unsync_in[2:0]};
end
endmodule

module synchronize2 (
    input clk_in,
    input [1:0] unsync_in,
    output reg [1:0] sync_out
);
reg [5:0] sync;
always_ff @(posedge clk_in) begin
    {sync_out[1:0], sync[5:0]} <= {sync[5:0], unsync_in[1:0]};
end
endmodule

module synchronize7 (
    input clk_in,
    input [6:0] unsync_in,
    output reg [6:0] sync_out
);
reg [20:0] sync;
always_ff @(posedge clk_in) begin
    {sync_out[6:0], sync[20:0]} <= {sync[20:0], unsync_in[6:0]};
end
endmodule

module synchronize35 (
    input clk_in,
    input [34:0] unsync_in,
    output reg [34:0] sync_out
);
reg [104:0] sync;
always_ff @(posedge clk_in) begin
    {sync_out[34:0], sync[104:0]} <= {sync[104:0], unsync_in[34:0]};
end
endmodule

module debounce (
    input rst_in,
    input clk_in,
    input noisy_in,
    output reg clean_out
);

reg [19:0] count;
reg new_input;

always_ff @(posedge clk_in) begin
    if(rst_in) begin
        new_input <= noisy_in;
        clean_out <= noisy_in;
        count <= 20'd0;
    end else if(noisy_in != new_input) begin
        new_input <= noisy_in;
        count <= 20'd0;
    end else if(count == 20'd1_000_000) begin
        clean_out <= new_input;
    end else begin
        count <= count + 20'd1;
    end
end
endmodule

// display module for 7-segment display                                        
module display_8hex(
input clk_in,                 // system clock
input [31:0] data_in,         // 8 hex numbers, msb first
output reg [6:0] seg_out,     // seven segment display output
output reg [7:0] strobe_out   // digit strobe
);
localparam bits = 13;

reg [bits:0] counter = 0;  // clear on power up
wire [6:0] segments[15:0]; // 16 7 bit memorys
assign segments[0]  = 7'b100_0000;  // inverted logic
assign segments[1]  = 7'b111_1001;  // gfedcba
assign segments[2]  = 7'b010_0010;
assign segments[3]  = 7'b011_0000;
assign segments[4]  = 7'b001_1001;
assign segments[5]  = 7'b001_0100;
assign segments[6]  = 7'b000_0100;
assign segments[7]  = 7'b111_1000;
assign segments[8]  = 7'b000_0000;
assign segments[9]  = 7'b001_1000;
assign segments[10] = 7'b000_1000;
assign segments[11] = 7'b000_0101;
assign segments[12] = 7'b100_0110;
assign segments[13] = 7'b010_0001;
assign segments[14] = 7'b000_0110;
assign segments[15] = 7'b000_1110;

always_ff @(posedge clk_in) begin
    // Here I am using a counter and select 3 bits which provides
    // a reasonable refresh rate starting the left most digit
    // and moving left.
    counter <= counter + 1;
    case (counter[bits:bits-2])
        3'b000: begin  // use the MSB 4 bits
            seg_out <= segments[data_in[31:28]];
            strobe_out <= 8'b0111_1111;
        end
        3'b001: begin
            seg_out <= segments[data_in[27:24]];
            strobe_out <= 8'b1011_1111;
        end
        3'b010: begin
            seg_out <= segments[data_in[23:20]];
            strobe_out <= 8'b1101_1111;
        end
        3'b011: begin
            seg_out <= segments[data_in[19:16]];
            strobe_out <= 8'b1110_1111;
        end
        3'b100: begin
            seg_out <= segments[data_in[15:12]];
            strobe_out <= 8'b1111_0111;
        end
        3'b101: begin
            seg_out <= segments[data_in[11:8]];
            strobe_out <= 8'b1111_1011;
        end
        3'b110: begin
            seg_out <= segments[data_in[7:4]];
            strobe_out <= 8'b1111_1101;
        end
        3'b111: begin
            seg_out <= segments[data_in[3:0]];
            strobe_out <= 8'b1111_1110;
        end
    endcase
end
endmodule
