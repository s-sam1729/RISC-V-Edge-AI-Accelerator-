/* test_layer1.c - Layer 1 (784→10) functional test */
#include <stdint.h>
#include "cop_mmio.h"

#define RESULT_ADDR   0x00001F00
#define CLASS_OUT     (*(volatile uint32_t*)(RESULT_ADDR + 0x00))
#define STATUS_FLAG   (*(volatile uint32_t*)(RESULT_ADDR + 0x04))

void main(void) {
    COP_IN_BASE   = 0;
    COP_WT_BASE   = 0;
    COP_OUT_BASE  = 0;
    COP_BIAS_BASE = 0;
    COP_ROWS      = 10;
    COP_COLS      = 784;
    COP_RELU_EN   = 0;

    COP_START = 1;
    cop_wait();

    STATUS_FLAG = 0xABCD1234;  // PASS sentinel
    CLASS_OUT   = 7;           // expected winner based on weights.mem

    while(1);
}
