# Fix ActionController::Live Threading Issues (Instead of Removing Threading)

## Problem
ActionController::Live is causing segmentation faults due to thread state sharing issues introduced in PR #52731. The complex threading implementation is creating connection state corruption and memory issues.

## Root Cause Analysis
PR #52731 introduced:
1. **Complex thread pool executor** (`Concurrent::CachedThreadPool`) instead of simple `Thread.new`
2. **Execution state sharing** (`ActiveSupport::IsolatedExecutionState.share_with(t1)`) that corrupts database connections
3. **Overly complex thread management** that leads to "double concurrent PG#close" issues
4. **Thread state leakage** causing segmentation faults during garbage collection

## Solution: Fix Threading Instead of Removing It
**We will NOT remove threading** because ActionController::Live needs it for non-blocking streaming. Instead, we'll fix the specific threading bugs while maintaining the non-blocking architecture.

## Implementation Plan

### 1. Restore Proper Threading Architecture
**Keep the threading but fix the bugs:**
```ruby
def new_controller_thread # :nodoc:
  # FIXED: Use simple Thread.new instead of complex thread pool to avoid state sharing issues
  Thread.new do
    t2 = Thread.current
    t2.abort_on_exception = true
    yield
  end
end
```

### 2. Fix Execution State Sharing Issues
**Remove the problematic execution state sharing:**
```ruby
# REMOVED: This was causing connection corruption
# ActiveSupport::IsolatedExecutionState.share_with(t1)

# REMOVED: This was clearing execution state incorrectly
# ActiveSupport::IsolatedExecutionState.clear
```

### 3. Maintain Thread Locals Copying (Safely)
**Keep thread locals copying but ensure proper cleanup:**
```ruby
# Copy thread locals from main thread to worker thread
locals.each { |k, v| t2[k] = v }

# Ensure proper cleanup to prevent memory leaks
clean_up_thread_locals(locals, t2)
```

### 4. Preserve Non-Blocking Streaming
**Maintain the core functionality that makes ActionController::Live work:**
- Actions execute in separate threads
- Main server thread stays free to handle other requests
- Streaming doesn't block the server
- Multiple clients can stream simultaneously

## Benefits of This Approach

1. **Fixes segmentation faults** by eliminating execution state corruption
2. **Maintains non-blocking streaming** that ActionController::Live provides
3. **Simplifies thread management** by removing complex thread pool executor
4. **Preserves server responsiveness** for handling multiple requests
5. **Eliminates connection state sharing** that was causing double-free issues

## What We're NOT Doing

❌ **Removing threading entirely** - This would break ActionController::Live's purpose
❌ **Keeping complex thread pool executor** - This was the source of the bugs
❌ **Sharing execution state between threads** - This caused connection corruption
❌ **Breaking non-blocking streaming** - This is the core feature of Live

## What We ARE Doing

✅ **Fixing specific threading bugs** while keeping threading architecture
✅ **Simplifying thread management** to prevent state sharing issues
✅ **Maintaining non-blocking streaming** for real-time applications
✅ **Preserving server responsiveness** for multiple concurrent requests
✅ **Eliminating connection corruption** that caused segmentation faults

## Expected Outcome

- ActionController::Live works with proper threading
- No more segmentation faults related to thread state sharing
- Non-blocking streaming functionality preserved
- Server remains responsive during streaming operations
- Database connections properly isolated between threads

## Files Modified

- `actionpack/lib/action_controller/metal/live.rb` - Restore threading while fixing bugs
- Documentation updates to reflect threading is maintained but fixed

## Current Status

🔄 **Implementation In Progress**: Restoring proper threading while fixing specific bugs
✅ **Root Cause Identified**: Complex execution state sharing in PR #52731
✅ **Solution Approach**: Fix threading bugs instead of removing threading
✅ **Architecture Preserved**: Non-blocking streaming maintained

## Next Steps

1. **Test the restored threading** to ensure it works without the bugs
2. **Verify streaming functionality** is preserved
3. **Run existing tests** to ensure no regressions
4. **Submit PR** with threading fixes instead of threading removal

## Key Insight

The issue wasn't that ActionController::Live shouldn't use threading - it's that PR #52731 introduced overly complex threading that corrupted execution state. The solution is to **simplify and fix the threading**, not remove it entirely.

ActionController::Live needs threading to provide non-blocking streaming, which is its entire purpose. By fixing the specific bugs while maintaining the threading architecture, we get the best of both worlds: reliable streaming without segmentation faults.
