
import numpy as np
import os

def main():
    NUM_TESTS = 500
    LANES = 8 # 8 elements per vector to match vec_mac_engine LANES=8

    # Generate random INT8 vectors
    # Size: 500x8
    vec_a = np.random.randint(-128, 127, size=(NUM_TESTS, LANES), dtype=np.int8)
    vec_b = np.random.randint(-128, 127, size=(NUM_TESTS, LANES), dtype=np.int8)
    
    # Generate random INT32 biases
    bias = np.random.randint(-10000, 10000, size=(NUM_TESTS,), dtype=np.int32)

    expected_outputs = []

    os.makedirs("../../sim/golden", exist_ok=True)

    with open("../../sim/golden/test_vectors_a.txt", "w") as fa, \
         open("../../sim/golden/test_vectors_b.txt", "w") as fb, \
         open("../../sim/golden/test_bias.txt", "w") as fbias, \
         open("../../sim/golden/expected_outputs.txt", "w") as fout:

        for i in range(NUM_TESTS):
            a = vec_a[i]
            b = vec_b[i]
            bi = bias[i]

            # 1. Hardware behavior: Dot product -> Add Bias -> ReLU
            dot_prod = np.dot(a.astype(np.int32), b.astype(np.int32))
            biased = dot_prod + bi
            result = max(0, biased) # ReLU
            expected_outputs.append(result)

            # 2. Pack 8 INT8s into a 64-bit hex string for Verilog
            # Pack order: a[7], a[6] ... a[0] (so a[0] is at the LSB position)
            hex_a = "".join(f"{x & 0xFF:02x}" for x in reversed(a))
            hex_b = "".join(f"{x & 0xFF:02x}" for x in reversed(b))

            fa.write(f"{hex_a}\n")
            fb.write(f"{hex_b}\n")
            fbias.write(f"{bi & 0xFFFFFFFF:08x}\n")
            fout.write(f"{result & 0xFFFFFFFF:08x}\n")

    print(f"Generated {NUM_TESTS} test vectors in sim/golden/")

if __name__ == "__main__":
    main()
