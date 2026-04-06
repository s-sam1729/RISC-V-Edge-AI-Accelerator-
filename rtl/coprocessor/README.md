# INT8 Quantisation Strategy & Weight Format Spec

## Quantisation Scheme
- Symmetric per-tensor INT8 quantisation (no zero-point)
- Signed range: [-128, 127]
- Scale: `scale = max(|W|) / 127.0`
- Quantised value: `W_q = round(W_float / scale)`

## Weight Format

### weights_layer1.mem (loaded by weight_bram.v via $readmemh)
- 32-bit hex words, one per line
- 4 INT8 values packed per word, little-endian
- Row-major order: weights[row][col]

### bias_layer1.mem (loaded by bias_bram.v via $readmemh)
- 32-bit hex words, one per line
- One INT32 bias per word

### weights.h (included by RISC-V C firmware)
- Declares INT8 weight array, INT32 bias array
- Declares float scale factors for dequantisation