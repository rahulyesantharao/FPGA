`timescale 1ns / 1ps

//pixel_helper takes as input the type of screen we are on, the current location of a menu selector,
//a 65MHz clock, the current 5 notes for the falling display in game mode,
//a new_note signal to indicate that a new note has been shifted into the shift register,
//a reset signal, the current note for learning mode, the current note being played by the user,
//and then the standard VGA signals (hcount, vcount, hsync, vsync, and blank);
//it uses this information to generate the proper pixel values, outputting phsync_out, pvsync_out, pblank_out, and pixel_out

module pixel_helper(
    input [2:0] screen,         //type of screen
    input [1:0] selection,      //menu selector location
    input clk_65mhz,            //clock
    input [34:0] notes,         //5 notes to display in game mode
    input new_note,             //pulse to indicate a new note shifted into notes register
    input reset,                //reset
    input [6:0] learning_note,  //current learning mode note
    input [6:0] user_note,      //current note user is playing
    input [10:0] hcount_in,     // horizontal index of current pixel (0..1023)
    input [9:0]  vcount_in,     // vertical index of current pixel (0..767)
    input hsync_in,             // XVGA horizontal sync signal (active low)
    input vsync_in,             // XVGA vertical sync signal (active low)
    input blank_in,             // XVGA blanking (1 means output black pixel)
        
    output phsync_out,          // output horizontal sync
    output pvsync_out,          // output vertical sync
    output pblank_out,          // output blanking
    output logic [11:0] pixel_out  // output pixel  // r=11:8, g=7:4, b=3:0 
    );
    
    //different possible screens
    parameter MAIN_MENU = 3'b000;
    parameter KEYBOARD_INSTRUCTIONS = 3'b001;
    parameter SONG_INSTRUCTIONS = 3'b010;
    parameter BASIC_SONG_MENU = 3'b011;
    parameter CUSTOM_SONG_MENU = 3'b100;
    parameter LEARN_MODE = 3'b101;
    parameter GAME_MODE = 3'b110;
    
    assign phsync_out = hsync_in;
    assign pvsync_out = vsync_in;
    assign pblank_out = blank_in;
    
    //the main menu
    wire [11:0] main_menu_pixel;
    picture_blob_main_menu
        main_menu(.pixel_clk_in(clk_65mhz), .x_in(250),.y_in(250),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(main_menu_pixel));
            
    //the keyboard instructions
    wire [11:0] keyboard_inst_pixel;
    picture_blob_keyboard_inst
        keyboard_instructions(.pixel_clk_in(clk_65mhz), .x_in(250),.y_in(250),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(keyboard_inst_pixel));
          
    //the song creation instructions
    wire [11:0] song_inst_pixel;
    picture_blob_song_inst
        song_instructions(.pixel_clk_in(clk_65mhz), .x_in(250),.y_in(250),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(song_inst_pixel));
    
    //the basic song menu
    wire [11:0] song_menu_pixel;
    picture_blob_song_menu_basic
        song_menu(.pixel_clk_in(clk_65mhz), .x_in(250),.y_in(250),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(song_menu_pixel));           
            
    //the custom song menu
    wire [11:0] song_menu_custom_pixel;
    picture_blob_song_menu_custom
        song_menu_custom(.pixel_clk_in(clk_65mhz), .x_in(250),.y_in(250),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(song_menu_custom_pixel));     
    
    //the keyboard
    wire [11:0] keyboard_pixel;
    picture_blob_keyboard
        keyboard(.pixel_clk_in(clk_65mhz), .x_in(0),.y_in(640),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(keyboard_pixel));
            
    //the menu-navigation selector
    logic [9:0] selector_y;
    selector_lut my_sel_lut(.clk_65mhz(clk_65mhz), .selector(selection), .y_loc(selector_y));
    
    wire [11:0] selector_pixel;
    blob #(.WIDTH(35),.HEIGHT(35),.COLOR(12'hF00))
        selector(.x_in(650),.y_in(selector_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(selector_pixel));
    
    //the learning mode note indicator
    logic [10:0] learning_note_x;
    keyboard_lut my_learn_lut(.clk_65mhz(clk_65mhz), .note_index(learning_note), .x_loc(learning_note_x));
    
    wire [11:0] learning_note_pixel;
    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        learning_note_blob(.x_in(learning_note_x),.y_in(480),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(learning_note_pixel));
    
    //the user note indicator      
    logic [10:0] user_note_x;
    keyboard_lut my_user_lut(.clk_65mhz(clk_65mhz), .note_index(user_note), .x_loc(user_note_x));
    
    wire [11:0] user_note_pixel;
    blob #(.WIDTH(10),.HEIGHT(60),.COLOR(12'h0F0))
        user_note_blob(.x_in(user_note_x),.y_in(580),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(user_note_pixel));
    
    //5 indicator rectangles for notes in falling display during game mode     
    wire [11:0] note_1_pixel, note_2_pixel, note_3_pixel, note_4_pixel, note_5_pixel;
    
    //use look up table of x-positions to find x-locations for 5 notes
    logic [10:0] note_1_x, note_2_x, note_3_x, note_4_x, note_5_x;
    keyboard_lut note_1_lut(.clk_65mhz(clk_65mhz), .note_index(notes[34:28]), .x_loc(note_1_x));
    keyboard_lut note_2_lut(.clk_65mhz(clk_65mhz), .note_index(notes[27:21]), .x_loc(note_2_x));
    keyboard_lut note_3_lut(.clk_65mhz(clk_65mhz), .note_index(notes[20:14]), .x_loc(note_3_x));
    keyboard_lut note_4_lut(.clk_65mhz(clk_65mhz), .note_index(notes[13:7]), .x_loc(note_4_x));
    keyboard_lut note_5_lut(.clk_65mhz(clk_65mhz), .note_index(notes[6:0]), .x_loc(note_5_x));
    
    //locations for actual blob objects, only updated when a new note is shifted in
    logic [10:0] note_1_new_x, note_2_new_x, note_3_new_x, note_4_new_x, note_5_new_x;
    
    //notes' y-positions
    logic [9:0] note_1_y, note_2_y, note_3_y, note_4_y, note_5_y;
    
    //blob objects for notes in falling display
    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        note_1_blob(.x_in(note_1_x),.y_in(note_1_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(note_1_pixel));
            
    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        note_2_blob(.x_in(note_2_x),.y_in(note_2_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(note_2_pixel));
            
    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        note_3_blob(.x_in(note_3_x),.y_in(note_3_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(note_3_pixel));

    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        note_4_blob(.x_in(note_4_x),.y_in(note_4_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(note_4_pixel));
            
    blob #(.WIDTH(10),.HEIGHT(160),.COLOR(12'h00F))
        note_5_blob(.x_in(note_5_x),.y_in(note_5_y),.hcount_in(hcount_in),.vcount_in(vcount_in),
            .pixel_out(note_5_pixel));
    
    parameter CYCLES_PER_MOVEMENT = 203125;     //number of clock cycles between downward movement of each note for falling display during game mode
    logic [17:0] counter = 18'b0;
    logic prev_new_note;
    
    always_ff @(posedge clk_65mhz) begin
    
        //determine which objects to display depending on screen type
        case(screen)
        
            MAIN_MENU:              pixel_out <= main_menu_pixel & selector_pixel;
            KEYBOARD_INSTRUCTIONS:  pixel_out <= keyboard_pixel & user_note_pixel;
            SONG_INSTRUCTIONS:      pixel_out <= song_inst_pixel;
            BASIC_SONG_MENU:        pixel_out <= song_menu_pixel & selector_pixel;
            CUSTOM_SONG_MENU:       pixel_out <= song_menu_custom_pixel & selector_pixel;
            LEARN_MODE:             pixel_out <= keyboard_pixel & learning_note_pixel & user_note_pixel;
            GAME_MODE:              pixel_out <= (vcount_in >= 640) ? keyboard_pixel :
                                        (vcount_in == 0 || vcount_in == 160 || vcount_in == 320 || vcount_in == 480) ?
                                        12'h000: (note_1_pixel & note_2_pixel & note_3_pixel & note_4_pixel & note_5_pixel & user_note_pixel);
        
        endcase
        
        if (reset) begin
        
            counter <= 18'b0;
        
        end else begin
        
            counter <= (!(screen == GAME_MODE) || counter == CYCLES_PER_MOVEMENT || new_note) ? 18'b0 : counter + 1;
            
            //update x-positions of notes when a new note is shifted in
            note_1_new_x <= (prev_new_note) ? note_1_x : note_1_new_x;
            note_2_new_x <= (prev_new_note) ? note_2_x : note_2_new_x;
            note_3_new_x <= (prev_new_note) ? note_3_x : note_3_new_x;
            note_4_new_x <= (prev_new_note) ? note_4_x : note_4_new_x;
            note_5_new_x <= (prev_new_note) ? note_5_x : note_5_new_x;
            
            //set y-positions to (0, 160, 320, 480, 864=-160) when a new note is shifted in,
            //then increment each by 2 whenever counter reaches CYCLES_PER_MOVEMENT;
            //with a new note shifted in every quarter of a second, this produces a smooth, synchronized falling display
            note_1_y <= (new_note) ? 480 : ((counter == CYCLES_PER_MOVEMENT) ? note_1_y + 2 : note_1_y);
            note_2_y <= (new_note) ? 320 : ((counter == CYCLES_PER_MOVEMENT) ? note_2_y + 2 : note_2_y);
            note_3_y <= (new_note) ? 160 : ((counter == CYCLES_PER_MOVEMENT) ? note_3_y + 2 : note_3_y);
            note_4_y <= (new_note) ? 0 : ((counter == CYCLES_PER_MOVEMENT) ? note_4_y + 2 : note_4_y);
            note_5_y <= (new_note) ? 864 : ((counter == CYCLES_PER_MOVEMENT) ? note_5_y + 2 : note_5_y);
            
            prev_new_note <= new_note;
        end
    
    end
    
    
endmodule

//Look up table for menu navigation; converts current choice within a menu to the appropriate y-location for the display
module selector_lut(
    input clk_65mhz,
    input [1:0] selector,
    output logic [9:0] y_loc);
    
    always_ff @(posedge clk_65mhz) begin
        case(selector)
        
            2'b00: y_loc <= 260;
            2'b01: y_loc <= 300;
            2'b10: y_loc <= 340;
            2'b11: y_loc <= 380;
            default: y_loc <= 260;
        
        endcase
    end
    
endmodule

//Look up table converting any note index into the appropriate x-location on the display to match up with the keyboard image
module keyboard_lut(
    input clk_65mhz,
    input [6:0] note_index,
    output logic [10:0] x_loc);
    
    always_ff @(posedge clk_65mhz) begin
        case(note_index)
        
            36: x_loc <= 11'hA;
            37: x_loc <= 11'h1A;
            38: x_loc <= 11'h2A;
            39: x_loc <= 11'h38;
            40: x_loc <= 11'h49;
            41: x_loc <= 11'h5E;
            42: x_loc <= 11'h6F;
            43: x_loc <= 11'h7E;
            44: x_loc <= 11'h8D;
            45: x_loc <= 11'h9C;
            46: x_loc <= 11'hAA;       
            47: x_loc <= 11'hBA;
            48: x_loc <= 11'hCF;
            49: x_loc <= 11'hE0;
            50: x_loc <= 11'hEF;
            51: x_loc <= 11'hFE;        
            52: x_loc <= 11'h10F;
            53: x_loc <= 11'h124;
            54: x_loc <= 11'h135;
            55: x_loc <= 11'h144;
            56: x_loc <= 11'h153;       
            57: x_loc <= 11'h161;
            58: x_loc <= 11'h170;
            59: x_loc <= 11'h180;           
            60: x_loc <= 11'h196;
            61: x_loc <= 11'h1A7;        
            62: x_loc <= 11'h1B6;
            63: x_loc <= 11'h1C5;
            64: x_loc <= 11'h1D6;
            65: x_loc <= 11'h1EB;
            66: x_loc <= 11'h1FD;       
            67: x_loc <= 11'h20D;
            68: x_loc <= 11'h21A;
            69: x_loc <= 11'h22A;
            70: x_loc <= 11'h238;
            71: x_loc <= 11'h24C;        
            72: x_loc <= 11'h262;
            73: x_loc <= 11'h274;
            74: x_loc <= 11'h27F;
            75: x_loc <= 11'h28D;
            76: x_loc <= 11'h29E;       
            77: x_loc <= 11'h2B7;
            78: x_loc <= 11'h2C8;
            79: x_loc <= 11'h2D7;   
            80: x_loc <= 11'h2E6;
            81: x_loc <= 11'h2F3;        
            82: x_loc <= 11'h300;
            83: x_loc <= 11'h312;
            84: x_loc <= 11'h32A;
            85: x_loc <= 11'h33A;
            86: x_loc <= 11'h349;       
            87: x_loc <= 11'h358;
            88: x_loc <= 11'h368;
            89: x_loc <= 11'h37A;
            90: x_loc <= 11'h38C;
            91: x_loc <= 11'h39B;
            92: x_loc <= 11'h3AA;
            93: x_loc <= 11'h3B9;
            94: x_loc <= 11'h3C8;
            95: x_loc <= 11'h3D8;
            96: x_loc <= 11'h3EB;
            default: x_loc <= 11'h7FF;      //default off-screen for invalid note indices   
        
        endcase
    end
    
endmodule


//////////////////////////////////////////////////////////////////////
//
// blob: generate rectangle on screen
//
//////////////////////////////////////////////////////////////////////
module blob
   #(parameter WIDTH = 64,            // default width: 64 pixels
               HEIGHT = 64,           // default height: 64 pixels
               COLOR = 12'hFFF)  // default color: white
   (input [11:0] x_in,hcount_in,
    input [10:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   always_comb begin
      if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
	 (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
	pixel_out = COLOR;
      else pixel_out = 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the main menu
//
//////////////////////////////////////////////////
module picture_blob_main_menu
   #(parameter WIDTH = 226,     // default picture width
               HEIGHT = 158)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [15:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   main_menu_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_main_menu_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_main_menu_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_main_menu_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the keyboard-playing instructions
//
//////////////////////////////////////////////////
module picture_blob_keyboard_inst
   #(parameter WIDTH = 173,     // default picture width
               HEIGHT = 50)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [13:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   keyboard_inst_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_key_inst_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_key_inst_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_key_inst_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the song-creation instructions
//
//////////////////////////////////////////////////
module picture_blob_song_inst
   #(parameter WIDTH = 217,     // default picture width
               HEIGHT = 56)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [13:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   song_inst_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_song_inst_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_song_inst_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_song_inst_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the keyboard
//
//////////////////////////////////////////////////
module picture_blob_keyboard
   #(parameter WIDTH = 1026,     // default picture width
               HEIGHT = 128)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [17:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   keyboard_rom1  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_keyboard_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_keyboard_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_keyboard_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the basic song menu
//
//////////////////////////////////////////////////
module picture_blob_song_menu_basic
   #(parameter WIDTH = 330,     // default picture width
               HEIGHT = 123)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [15:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   basic_song_menu_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_basic_menu_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_basic_menu_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_basic_menu_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

////////////////////////////////////////////////////
//
// picture_blob: display a picture for the custom song menu
//
//////////////////////////////////////////////////
module picture_blob_song_menu_custom
   #(parameter WIDTH = 329,     // default picture width
               HEIGHT = 157)    // default picture height
   (input pixel_clk_in,
    input [10:0] x_in,hcount_in,
    input [9:0] y_in,vcount_in,
    output logic [11:0] pixel_out);

   logic [15:0] image_addr;
   logic [7:0] image_bits, red_mapped, green_mapped, blue_mapped;

   // calculate rom address and read the location
   assign image_addr = (hcount_in-x_in) + (vcount_in-y_in) * WIDTH;
   custom_song_menu_rom  rom1(.clka(pixel_clk_in), .addra(image_addr), .douta(image_bits));

   // use color map to create 4 bits R, 4 bits G, 4 bits B
   // since the image is greyscale, just replicate the red pixels
   // and not bother with the other two color maps.
   red_custom_menu_rom rcm (.clka(pixel_clk_in), .addra(image_bits), .douta(red_mapped));
   green_custom_menu_rom gcm (.clka(pixel_clk_in), .addra(image_bits), .douta(green_mapped));
   blue_custom_menu_rom bcm (.clka(pixel_clk_in), .addra(image_bits), .douta(blue_mapped));
   // note the one clock cycle delay in pixel!
   always @ (posedge pixel_clk_in) begin
     if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
          (vcount_in >= y_in && vcount_in < (y_in+HEIGHT)))
        // use MSB 4 bits
        pixel_out <= {red_mapped[7:4], red_mapped[7:4], red_mapped[7:4]}; // greyscale
        //pixel_out <= {red_mapped[7:4], 8h'0}; // only red hues
        else pixel_out <= 12'hFFF;
   end
endmodule

//////////////////////////////////////////////////////////////////////////////////
// Update: 8/8/2019 GH 
// Create Date: 10/02/2015 02:05:19 AM
// Module Name: xvga
//
// xvga: Generate VGA display signals (1024 x 768 @ 60Hz)
//
//                              ---- HORIZONTAL -----     ------VERTICAL -----
//                              Active                    Active
//                    Freq      Video   FP  Sync   BP      Video   FP  Sync  BP
//   640x480, 60Hz    25.175    640     16    96   48       480    11   2    31
//   800x600, 60Hz    40.000    800     40   128   88       600     1   4    23
//   1024x768, 60Hz   65.000    1024    24   136  160       768     3   6    29
//   1280x1024, 60Hz  108.00    1280    48   112  248       768     1   3    38
//   1280x720p 60Hz   75.25     1280    72    80  216       720     3   5    30
//   1920x1080 60Hz   148.5     1920    88    44  148      1080     4   5    36
//
// change the clock frequency, front porches, sync's, and back porches to create 
// other screen resolutions
////////////////////////////////////////////////////////////////////////////////

module xvga(input vclock_in,
            output reg [10:0] hcount_out,    // pixel number on current line
            output reg [9:0] vcount_out,     // line number
            output reg vsync_out, hsync_out,
            output reg blank_out);

   parameter DISPLAY_WIDTH  = 1024;      // display width
   parameter DISPLAY_HEIGHT = 768;       // number of lines

   parameter  H_FP = 24;                 // horizontal front porch
   parameter  H_SYNC_PULSE = 136;        // horizontal sync
   parameter  H_BP = 160;                // horizontal back porch

   parameter  V_FP = 3;                  // vertical front porch
   parameter  V_SYNC_PULSE = 6;          // vertical sync 
   parameter  V_BP = 29;                 // vertical back porch

   // horizontal: 1344 pixels total
   // display 1024 pixels per line
   reg hblank,vblank;
   wire hsyncon,hsyncoff,hreset,hblankon;
   assign hblankon = (hcount_out == (DISPLAY_WIDTH -1));    
   assign hsyncon = (hcount_out == (DISPLAY_WIDTH + H_FP - 1));  //1047
   assign hsyncoff = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE - 1));  // 1183
   assign hreset = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE + H_BP - 1));  //1343

   // vertical: 806 lines total
   // display 768 lines
   wire vsyncon,vsyncoff,vreset,vblankon;
   assign vblankon = hreset & (vcount_out == (DISPLAY_HEIGHT - 1));   // 767 
   assign vsyncon = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP - 1));  // 771
   assign vsyncoff = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE - 1));  // 777
   assign vreset = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE + V_BP - 1)); // 805

   // sync and blanking
   wire next_hblank,next_vblank;
   assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
   assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
   always_ff @(posedge vclock_in) begin
      hcount_out <= hreset ? 0 : hcount_out + 1;
      hblank <= next_hblank;
      hsync_out <= hsyncon ? 0 : hsyncoff ? 1 : hsync_out;  // active low

      vcount_out <= hreset ? (vreset ? 0 : vcount_out + 1) : vcount_out;
      vblank <= next_vblank;
      vsync_out <= vsyncon ? 0 : vsyncoff ? 1 : vsync_out;  // active low

      blank_out <= next_vblank | (next_hblank & ~hreset);
   end
   
endmodule