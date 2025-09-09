

import Foundation
import Metal

class Renderer: ObservableObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    let counterSampleBuffer: MTLCounterSampleBuffer

    // Constants for the experiment
    let bufferElementCount = 1024 * 1024 * 8 // 128 MB buffer of uints
    var iterationsPerThread = 4096

    private var dataBuffer: MTLBuffer

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "RendererError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is not supported on this device."])
        }

        guard let timestampCounterSet = device.counterSets?.first(where: { $0.name == "timestamp" }) else {
            throw NSError(domain: "RendererError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device does not support GPU timestamps."])
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        let library = device.makeDefaultLibrary()!
        let function = library.makeFunction(name: "stride_test")!
        self.pipelineState = try device.makeComputePipelineState(function: function)

        let sampleCount = 18 // Test 9 strides, 2 samples each (start/end)
        let counterDescriptor = MTLCounterSampleBufferDescriptor()
        counterDescriptor.counterSet = timestampCounterSet
        counterDescriptor.storageMode = .shared
        counterDescriptor.sampleCount = sampleCount
        self.counterSampleBuffer = try device.makeCounterSampleBuffer(descriptor: counterDescriptor)

        self.dataBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * bufferElementCount, options: .storageModeShared)!
    }

    func runExperiment() -> String {
        var resultsLog = ""
        var cpuTimestamp: UInt64 = 0
        var gpuTimestamp: UInt64 = 0
        
        (cpuTimestamp, gpuTimestamp) = device.sampleTimestamps()

        var machTimebaseInfo = mach_timebase_info()
        mach_timebase_info(&machTimebaseInfo)
        let nanoSecondsPerMachTick = Double(machTimebaseInfo.numer) / Double(machTimebaseInfo.denom)
        let cpuNanos = Double(cpuTimestamp) * nanoSecondsPerMachTick
        let cpuNanosPerGpuTick = gpuTimestamp > 0 ? (cpuNanos / Double(gpuTimestamp)) : 0

        print("--- Starting Experiment ---")
        resultsLog += String(format: "CPU Nanos per GPU Tick: %.4f\n\n", cpuNanosPerGpuTick)
        resultsLog += "Stride (Bytes) | GPU Ticks      | Time (ms)\n"
        resultsLog += "----------------------------------------------\n"
        
        for i in 0...8 {
            var stride = 1 << i
            let strideBytes = stride * MemoryLayout<UInt32>.stride

            let commandBuffer = commandQueue.makeCommandBuffer()!
            
            // --- FIX ---
            // Create a Compute Pass Descriptor to manage the sampling
            let computePassDescriptor = MTLComputePassDescriptor()
            
            // Tell the descriptor where to store the start and end timestamps for this pass
            let attachment = computePassDescriptor.sampleBufferAttachments[0]!
            attachment.sampleBuffer = counterSampleBuffer
            attachment.startOfEncoderSampleIndex = i * 2
            attachment.endOfEncoderSampleIndex = i * 2 + 1
            
            // Create the command encoder USING the descriptor
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(descriptor: computePassDescriptor)!
            // No more explicit sampleCounters() calls are needed!
            
            commandEncoder.setComputePipelineState(pipelineState)

            let resultBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared)!
            
            commandEncoder.setBuffer(dataBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(resultBuffer, offset: 0, index: 1)
            commandEncoder.setBytes(&stride, length: MemoryLayout<UInt32>.stride, index: 2)
            commandEncoder.setBytes(&iterationsPerThread, length: MemoryLayout<UInt32>.stride, index: 3)

            let threadCount = 1024
            let threadsPerGroup = MTLSize(width: threadCount, height: 1, depth: 1)
            let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
            
            commandEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
            
            commandEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            let resolvedBuffer = resolveCounterData(sampleCount: i * 2 + 2)
            let timestamps = resolvedBuffer.contents().bindMemory(to: UInt64.self, capacity: 2)
            
            let startTicks = timestamps[i * 2]
            let endTicks = timestamps[i * 2 + 1]

            if startTicks == 0 || endTicks == 0 { continue }
            
            let deltaTicks = endTicks - startTicks
            let deltaNanos = Double(deltaTicks) * cpuNanosPerGpuTick
            let deltaMillis = deltaNanos / 1_000_000.0

            let logLine = String(format: "%-16d | %-14llu | %.4f\n", strideBytes, deltaTicks, deltaMillis)
            print(logLine, terminator: "")
            resultsLog += logLine
        }

        return resultsLog
    }

    private func resolveCounterData(sampleCount: Int) -> MTLBuffer {
        let size = sampleCount * MemoryLayout<UInt64>.stride
        let buffer = device.makeBuffer(length: size, options: .storageModeShared)!
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        blitEncoder.resolveCounters(counterSampleBuffer,
                                    range: 0..<sampleCount,
                                    destinationBuffer: buffer,
                                    destinationOffset: 0)
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return buffer
    }
}
