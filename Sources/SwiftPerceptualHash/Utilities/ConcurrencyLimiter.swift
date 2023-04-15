//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 15/4/23.
//

import Foundation

/// Limits the number of concurrent tasks using the command buffer.
internal actor ConcurrencyLimiter {
    /// Number of actively running tasks using the command buffer.
    var parallelTaskCount: Int = 0
    
    /// Signals that a new task is about to use the command buffer. If
    /// `maxCommandBufferCount` tasks are already running, the call is
    /// suspended until the resource is available.
    /// - Parameter maxCommandBufferCount: The maximum number of
    /// tasks that can be run on parallel.
    func newRunningTask(maxCommandBufferCount: Int) async {
        while parallelTaskCount >= maxCommandBufferCount {
            await Task.yield()
        }
        parallelTaskCount += 1
    }
    /// Signals that a task using the command buffer has finished, so other
    /// threads can use the resource.
    func endRunningTask() {
        parallelTaskCount -= 1
    }
}
