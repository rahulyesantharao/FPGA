// TODO: convert into a RAM, instead of ROM
module song_bram_wrapper(
  input logic clka,
  input logic [9:0] addra,
  output logic [7:0] douta
);
    song_rom my_songs(.clka(clka), .addra(addra), .douta(douta));
endmodule
