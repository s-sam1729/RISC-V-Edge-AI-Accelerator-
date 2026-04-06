#include <stdint.h>
#include <stdio.h>

// --- Coprocessor MMIO Map ---
#define COP_BASE       0xC0000000
volatile uint32_t* COP_START      = (uint32_t*)(COP_BASE + 0x00);
volatile uint32_t* COP_STATUS     = (uint32_t*)(COP_BASE + 0x04);
volatile uint32_t* COP_IN_BASE    = (uint32_t*)(COP_BASE + 0x08);
volatile uint32_t* COP_WT_BASE    = (uint32_t*)(COP_BASE + 0x0C);
volatile uint32_t* COP_OUT_BASE   = (uint32_t*)(COP_BASE + 0x10);
volatile uint32_t* COP_LAYER_ROWS = (uint32_t*)(COP_BASE + 0x14);
volatile uint32_t* COP_LAYER_COLS = (uint32_t*)(COP_BASE + 0x18);
volatile uint32_t* COP_BIAS_BASE  = (uint32_t*)(COP_BASE + 0x1C);
volatile uint32_t* COP_CYCLE_CNT  = (uint32_t*)(COP_BASE + 0x20);

// BRAM Pointers (Assuming BRAMs are mapped into CPU address space for initialization)
// Note: Adjust these base addresses based on your top_fpga.v decoder
volatile int8_t* INPUT_BRAM  = (int8_t*)(0xC1000000); 
volatile int8_t* WEIGHT_BRAM = (int8_t*)(0xC2000000);
volatile int32_t* OUTPUT_BRAM = (int32_t*)(0xC3000000);
volatile int32_t* BIAS_BRAM   = (int32_t*)(0xC4000000);

#define VECTOR_LEN 128

// --- Software Fallback ---
int32_t sw_dot_product(int8_t* a, int8_t* b, int32_t bias, int len) {
    int32_t acc = 0;
    for (int i = 0; i < len; i++) {
        acc += a[i] * b[i];
    }
    acc += bias;
    return (acc < 0) ? 0 : acc; // ReLU
}

int main() {
    printf("Starting Dot Product Benchmark (Length %d)...\n", VECTOR_LEN);

    // 1. Initialize BRAM with dummy data
    for (int i = 0; i < VECTOR_LEN; i++) {
        INPUT_BRAM[i] = 2;   // Example activation
        WEIGHT_BRAM[i] = 3;  // Example weight
    }
    BIAS_BRAM[0] = 10;

    // 2. Software Execution
    // Note: We can't read the exact cycle count of the SW loop without a CPU cycle CSR,
    // so in a real bare-metal environment, you'd read the RISC-V 'mcycle' register here.
    int32_t sw_result = sw_dot_product((int8_t*)INPUT_BRAM, (int8_t*)WEIGHT_BRAM, BIAS_BRAM[0], VECTOR_LEN);
    printf("Software Result: %d\n", sw_result);

    // 3. Hardware Execution
    *COP_IN_BASE    = 0;
    *COP_WT_BASE    = 0;
    *COP_OUT_BASE   = 0;
    *COP_BIAS_BASE  = 0;
    *COP_LAYER_ROWS = 1;            // 1 Neuron
    *COP_LAYER_COLS = VECTOR_LEN;   // Vector length
    
    *COP_START = 1; // Trigger hardware
    
    // Hardware hazard padding (to absorb the 1-cycle pipeline slip)
    __asm__ volatile("nop\n\tnop\n\tnop");

    // Poll for completion (Bit 1 of STATUS is 'done')
    while ((*COP_STATUS & 0x02) == 0); 
    
    int32_t hw_result = OUTPUT_BRAM[0];
    uint32_t hw_cycles = *COP_CYCLE_CNT;

    printf("Hardware Result: %d\n", hw_result);
    printf("Hardware Cycles: %u\n", hw_cycles);
    
    if (sw_result == hw_result) {
        printf("Verification PASSED!\n");
    } else {
        printf("Verification FAILED!\n");
    }

    return 0;
}