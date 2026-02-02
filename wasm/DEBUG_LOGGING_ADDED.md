# WASM Index Out of Range Debug Logging

## Summary
Added comprehensive debug logging to [`caller.go`](openim-sdk-core/wasm/event_listener/caller.go) to help diagnose the "index out of range [2] with length 2" error occurring in WASM SDK calls.

## Error Context
The error was occurring in multiple functions:
- `getFriendApplicationListAsRecipient`
- `getFriendApplicationListAsApplicant`
- `getGroupApplicationListAsRecipient`
- `getGroupApplicationListAsApplicant`

## Changes Made

### 1. [`asyncCallWithCallback()`](openim-sdk-core/wasm/event_listener/caller.go:64) Function
Added logging at key points:
- **Line 91-94**: Log function entry with operationID, expected parameter count, actual argument count, and callback status
- **Line 97-98**: Log when an empty argument is appended
- **Line 106-110**: Log each argument being processed with index information
- **Line 111-119**: Add bounds check before accessing function parameters with detailed error logging

### 2. [`asyncCallWithOutCallback()`](openim-sdk-core/wasm/event_listener/caller.go:157) Function
Added similar logging:
- **Line 177-179**: Log function entry with parameter and argument counts
- **Line 184-187**: Log each argument being processed
- **Line 188-194**: Add bounds check with detailed error logging

### 3. [`SyncCall()`](openim-sdk-core/wasm/event_listener/caller.go:243) Function
Added logging:
- **Line 252**: Added `ctx` variable for logging
- **Line 270-273**: Log function entry with parameter and argument counts
- **Line 280-284**: Log each argument being processed
- **Line 285-293**: Add bounds check with detailed error logging

### 4. [`ErrHandle()`](openim-sdk-core/wasm/event_listener/caller.go:333) Function
Enhanced error logging:
- **Line 336-338**: Extract operationID for better error context
- **Line 341-353**: Added operationID to all error logs

## What the Logs Will Show

When the error occurs, you'll now see:

1. **Function Entry Log**:
   ```
   asyncCallWithCallback operationID=xxx funcFieldsNum=2 argumentsLen=2 hasCallback=true
   ```

2. **Argument Processing Log** (for each argument):
   ```
   asyncCallWithCallback processing arg operationID=xxx argIndex=0 paramIndex=1 funcFieldsNum=2 argumentsLen=2
   asyncCallWithCallback processing arg operationID=xxx argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2
   ```

3. **Error Log** (if bounds check fails):
   ```
   asyncCallWithCallback index out of range operationID=xxx argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
   ```

4. **Error Handler Log**:
   ```
   ERR operationID=xxx r=index out of range: trying to access parameter index 2 but function has only 2 parameters
   ```

## Root Cause Analysis

The error "index out of range [2] with length 2" suggests:
- The function expects 2 parameters (length 2)
- Code is trying to access parameter index 2 (which would be the 3rd parameter, 0-indexed)
- This happens when `hasCallback=true` and `temp = i + 1` where `i=1`, making `temp=2`

The issue is likely in the logic at line 95:
```go
if funcFieldsNum-len(r.arguments) > 1 {
    r.arguments = append(r.arguments, js.Value{})
}
```

This condition may not be correctly handling the case where a callback is present.

## Next Steps

1. **Rebuild the WASM SDK** to include the new logging
2. **Reproduce the error** to see the detailed logs
3. **Analyze the logs** to understand:
   - Which function is being called
   - How many parameters it expects
   - How many arguments are being passed
   - Whether a callback is present
   - Which argument index is causing the issue

## Expected Log Output Example

```
2026-02-02 11:17:42.808 DEBUG [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] asyncCallWithCallback funcFieldsNum=2 argumentsLen=2 hasCallback=true
2026-02-02 11:17:42.808 DEBUG [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] asyncCallWithCallback processing arg argIndex=0 paramIndex=1 funcFieldsNum=2 argumentsLen=2
2026-02-02 11:17:42.808 DEBUG [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] asyncCallWithCallback processing arg argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2
2026-02-02 11:17:42.808 ERROR [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] asyncCallWithCallback index out of range argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
2026-02-02 11:17:42.808 ERROR [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] ERR r=index out of range: trying to access parameter index 2 but function has only 2 parameters
```
