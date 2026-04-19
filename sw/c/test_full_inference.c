/* test_full_inference.c - Full MNIST inference with UART input */
#include <stdint.h>
#include "cop_mmio.h"

#define RESULT_ADDR    0x00001F00
#define PRED_CLASS     (*(volatile uint32_t*)(RESULT_ADDR + 0x00))
#define PRED_SCORE     (*(volatile uint32_t*)(RESULT_ADDR + 0x04))
#define INFER_COUNT    (*(volatile uint32_t*)(RESULT_ADDR + 0x08))
#define UART_TIMEOUT   500000

void run_inference(void) {
    COP_IN_BASE   = 0;
    COP_WT_BASE   = 0;
    COP_OUT_BASE  = 0;
    COP_BIAS_BASE = 0;
    COP_ROWS      = 10;
    COP_COLS      = 784;
    COP_RELU_EN   = 0;
    COP_START     = 1;
    cop_wait();
}

void main(void) {
    uint32_t count = 0;
    while (1) {
        uint32_t timeout = UART_TIMEOUT;
        while (!UART_RX_STATUS && timeout > 0) timeout--;

        run_inference();
        count++;

        PRED_CLASS  = count;          // placeholder
        PRED_SCORE  = 0xFFFFFFFF;     // sentinel
        INFER_COUNT = count;
    }
}
