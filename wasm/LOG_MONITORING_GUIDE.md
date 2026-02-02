# WASM SDK 日志监控指南

## 问题
由于服务太多，日志量很大，需要有效的方法来过滤和监控 WASM SDK 的特定错误日志。

## 解决方案

### 1. 使用 OperationID 过滤日志

每个 WASM SDK 调用都有唯一的 `operationID`，可以用它来追踪特定的调用链：

```bash
# 过滤特定 operationID 的所有日志
grep "e8a1e76f-f364-4304-a07c-47fa8a506f41" /path/to/logs/*.log

# 实时监控特定 operationID
tail -f /path/to/logs/*.log | grep "e8a1e76f-f364-4304-a07c-47fa8a506f41"
```

### 2. 过滤 WASM SDK 相关日志

```bash
# 过滤所有 WASM SDK 日志
grep "wasm" /path/to/logs/*.log

# 过滤特定函数的日志
grep "getFriendApplicationListAsRecipient\|getFriendApplicationListAsApplicant\|getGroupApplicationListAsRecipient\|getGroupApplicationListAsApplicant" /path/to/logs/*.log

# 过滤 index out of range 错误
grep "index out of range" /path/to/logs/*.log
```

### 3. 使用多条件过滤

```bash
# 同时过滤多个条件
grep -E "(asyncCallWithCallback|asyncCallWithOutCallback|SyncCall)" /path/to/logs/*.log | grep "index out of range"

# 过滤错误级别的日志
grep "ERROR.*index out of range" /path/to/logs/*.log

# 过滤 DEBUG 级别的日志（查看详细调用过程）
grep "DEBUG.*asyncCallWithCallback" /path/to/logs/*.log
```

### 4. 实时监控特定错误

```bash
# 实时监控 index out of range 错误
tail -f /path/to/logs/*.log | grep --line-buffered "index out of range"

# 实时监控所有 WASM SDK 错误
tail -f /path/to/logs/*.log | grep --line-buffered -E "(ERROR|WARN).*wasm"
```

### 5. 使用 jq 处理 JSON 格式日志（如果日志是 JSON 格式）

```bash
# 提取特定字段
cat /path/to/logs/*.log | jq 'select(.operationID == "e8a1e76f-f364-4304-a07c-47fa8a506f41")'

# 提取错误日志
cat /path/to/logs/*.log | jq 'select(.level == "ERROR") | select(.msg | contains("index out of range"))'

# 提取特定函数的调用日志
cat /path/to/logs/*.log | jq 'select(.msg | contains("asyncCallWithCallback"))'
```

### 6. 创建日志过滤脚本

创建 `filter_wasm_logs.sh`:

```bash
#!/bin/bash

LOG_DIR="/path/to/logs"
OPERATION_ID="$1"

if [ -z "$OPERATION_ID" ]; then
    echo "Usage: $0 <operation_id>"
    echo "Example: $0 e8a1e76f-f364-4304-a07c-47fa8a506f41"
    exit 1
fi

echo "=== Filtering logs for operationID: $OPERATION_ID ==="
echo ""

echo "=== All logs for this operation ==="
grep "$OPERATION_ID" $LOG_DIR/*.log

echo ""
echo "=== Error logs for this operation ==="
grep "$OPERATION_ID" $LOG_DIR/*.log | grep "ERROR"

echo ""
echo "=== Debug logs for this operation ==="
grep "$OPERATION_ID" $LOG_DIR/*.log | grep "DEBUG"

echo ""
echo "=== Index out of range errors ==="
grep "$OPERATION_ID" $LOG_DIR/*.log | grep "index out of range"
```

使用方法：
```bash
chmod +x filter_wasm_logs.sh
./filter_wasm_logs.sh e8a1e76f-f364-4304-a07c-47fa8a506f41
```

### 7. 使用 awk 进行高级过滤

```bash
# 提取特定时间段的日志
awk '/2026-02-02 11:17:42/,/2026-02-02 11:17:43/' /path/to/logs/*.log

# 提取包含特定字段的日志行
awk '/asyncCallWithCallback.*funcFieldsNum=2.*argumentsLen=2/' /path/to/logs/*.log

# 统计错误出现次数
grep -c "index out of range" /path/to/logs/*.log
```

### 8. 浏览器控制台过滤（如果是前端 WASM）

在浏览器开发者工具的 Console 中：

```javascript
// 过滤特定 operationID 的日志
console.log.bind(console, '[FILTER]');

// 或者使用 console.filter (如果支持)
console.filter = function(pattern) {
    const originalLog = console.log;
    console.log = function(...args) {
        if (args.some(arg => String(arg).includes(pattern))) {
            originalLog.apply(console, args);
        }
    };
};

// 使用过滤器
console.filter('e8a1e76f-f364-4304-a07c-47fa8a506f41');
```

### 9. Docker/Kubernetes 环境下的日志监控

```bash
# 查看 Pod 日志
kubectl logs -f <pod-name> | grep "index out of range"

# 查看所有相关 Pod 的日志
kubectl logs -l app=openim-wasm -f --all-containers | grep "wasm"

# 使用 stern 工具（推荐）
stern openim-wasm --tail 100 | grep "index out of range"
```

### 10. 设置日志级别

在 WASM SDK 配置中设置日志级别为 DEBUG：

```javascript
// 在初始化 SDK 时设置
const sdk = new OpenIMSDK({
    logLevel: 'debug', // 或 'trace' 获取更详细的日志
    // ... 其他配置
});
```

## 推荐的监控策略

### 快速定位错误
```bash
# 1. 查找最近的 index out of range 错误
grep "index out of range" /path/to/logs/*.log | tail -20

# 2. 提取这些错误的 operationID
grep "index out of range" /path/to/logs/*.log | grep -oP 'operationID:\K[^,]+' | sort -u

# 3. 对每个 operationID 追踪完整调用链
for opid in $(grep "index out of range" /path/to/logs/*.log | grep -oP 'operationID:\K[^,]+' | sort -u); do
    echo "=== OperationID: $opid ==="
    grep "$opid" /path/to/logs/*.log
    echo ""
done
```

### 实时监控新错误
```bash
# 持续监控新的 index out of range 错误
tail -f /path/to/logs/*.log | grep --line-buffered "index out of range" | while read line; do
    echo "=== New Error Detected ==="
    echo "$line"
    # 提取 operationID
    opid=$(echo "$line" | grep -oP 'operationID:\K[^,]+')
    echo "=== Full Call Trace for $opid ==="
    grep "$opid" /path/to/logs/*.log | tail -50
    echo ""
done
```

## 日志分析示例

当你看到以下错误时：

```
2026-02-02 11:17:42.808 ERROR [operationID:e8a1e76f-f364-4304-a07c-47fa8a506f41] asyncCallWithCallback index out of range argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
```

使用以下命令查看完整调用链：

```bash
grep "e8a1e76f-f364-4304-a07c-47fa8a506f41" /path/to/logs/*.log
```

这将显示：
1. 函数入口日志（包含 funcFieldsNum, argumentsLen, hasCallback）
2. 每个参数的处理日志（包含 argIndex, paramIndex）
3. 错误发生时的详细上下文
4. 错误处理器的日志

## 工具推荐

1. **grep** - 基础文本过滤
2. **awk** - 高级文本处理
3. **jq** - JSON 日志处理
4. **stern** - Kubernetes 日志监控
5. **lnav** - 日志查看和分析工具
6. **elasticsearch/kibana** - 企业级日志分析平台

## 注意事项

1. 确保日志级别设置为 DEBUG 或 TRACE 以获取详细信息
2. 使用 `--line-buffered` 参数在实时监控时避免延迟
3. 对于生产环境，考虑使用日志聚合系统（如 ELK Stack）
4. 定期清理旧日志以避免磁盘空间不足
5. 考虑将关键错误发送到告警系统
