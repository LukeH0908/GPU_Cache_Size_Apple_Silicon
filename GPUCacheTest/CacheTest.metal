//
//  CacheTest.metal
//  GPUCacheTest
//
//  Created by Luke He on 8/19/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void stride_test(device const uint *inBuffer [[buffer(0)]],
                        device atomic_uint *outBuffer [[buffer(1)]],
                        constant uint &stride [[buffer(2)]],
                        constant uint &iterations [[buffer(3)]],
                        uint tid [[thread_position_in_grid]])
{
    uint accumulator = 0;
    
    // We make each thread do a lot of reads to ensure the memory access
    // cost dominates the kernel launch overhead.
    for (uint i = 0; i < iterations; ++i) {
        // Calculate the index using the stride
        uint index = (tid + i) * stride;
        
        // Read the value from the input buffer
        accumulator += inBuffer[index];
    }
    
    // Write a result to the output buffer. Using an atomic operation
    // ensures the compiler cannot optimize away the entire loop.
    atomic_fetch_add_explicit(outBuffer, accumulator, memory_order_relaxed);
}
