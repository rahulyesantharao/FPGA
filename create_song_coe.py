import random

songs = [
    [127, 127, 127, 127, 76, 76, 74, 74, 72, 72, 74, 74, 76, 127, 76, 127, 76, 76, 127, 127, 74, 127, 74, 127, 74, 74, 127, 127, 76, 127, 79, 127, 79, 79, 127, 127, 76, 76, 74, 74, 72, 72, 74, 74, 76, 127, 76, 127, 76, 127, 76, 127, 74, 127, 74, 127, 76, 76, 74, 74, 72, 72, 127, 127],
    [127, 127, 127, 127, 76, 76, 71, 72, 74, 74, 72, 71, 69, 127, 69, 72, 76, 127, 74, 72, 71, 71, 127, 72, 74, 74, 76, 76, 72, 72, 69, 127, 69, 69, 127, 127, 127, 74, 74, 77, 81, 81, 79, 77, 76, 76, 127, 72, 76, 76, 74, 72, 71, 71, 71, 72, 74, 74, 76, 76, 72, 72, 69, 127, 69, 69, 127, 127],
    [127, 127, 127, 127, 72, 72, 127, 72, 72, 127, 72, 72, 72, 127, 127, 127, 127, 127, 72, 71, 71, 69, 71, 71, 72, 74, 74, 74, 76, 76, 127, 76, 76, 127, 76, 76, 76, 127, 127, 127, 127, 127, 76, 74, 74, 72, 74, 74, 76, 77, 77, 127, 79, 79, 79, 127, 127, 127, 72, 72, 72, 127, 127, 127, 127, 127, 81, 79, 79, 77, 76, 76, 76, 74, 74, 74, 72, 72, 72, 127, 127, 127]
]

MAX_LEN = 250
END_SONG = 0b1111100
PADDING = 127

with open('../6.111-fp/final_songs.coe', 'w') as f:
    f.write('memory_initialization_radix=2;\n')
    f.write('memory_initialization_vector=\n')
    for song in songs:
        songlen = len(song)
        padding = MAX_LEN - songlen - 1
        assert(padding > 0)
        # write song
        for i in range(songlen):
            f.write('{:08b},\n'.format(song[i]))
        # write song end signal
        f.write('{:08b},\n'.format(END_SONG))
        # pad
        for i in range(padding):
            f.write('{:08b},\n'.format(PADDING))
    # empty space for custom
    for i in range(MAX_LEN-1):
        f.write('{:08b},\n'.format(PADDING))
    f.write('{:08b};'.format(END_SONG))

