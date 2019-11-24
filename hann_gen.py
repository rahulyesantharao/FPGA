import math

n_bits = 12
out_bits = 24

L = (2**n_bits)
N = L-1 # n in [0,N]

def hann(n):
    assert(0 <= n <= N)
    c = math.sin(math.pi * n / N)
    print((2**out_bits) * c**2)
    return int((2 ** out_bits) * c**2)

tab="    "
if __name__ == '__main__':
    with open('hann.sv', 'w') as f:
        f.write('{}module hann(input logic [{}:0] n, output logic [{}:0] coeff);\n'.format(0*tab, n_bits-1, out_bits-1))
        f.write('{}always_comb begin\n'.format(1*tab))
        f.write('{}case(n)\n'.format(2*tab))
        for n in range(L):
            f.write("{}{}'d{}: coeff = {}'d{};\n".format(3*tab, n_bits, n, out_bits, hann(n)))
        f.write('{}endcase\n'.format(2*tab))
        f.write('{}end\n'.format(1*tab))
        f.write('{}endmodule\n'.format(0*tab))
