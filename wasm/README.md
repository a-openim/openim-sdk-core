# WASM SDK 日志监控工具使用指南

## 概述

本目录包含用于调试和监控 WASM SDK "index out of range" 错误的工具和文档。

## 文件说明

### 1. [`caller.go`](openim-sdk-core/wasm/event_listener/caller.go) - 已添加日志的源代码
在以下函数中添加了详细的调试日志：
- [`asyncCallWithCallback()`](openim-sdk-core/wasm/event_listener/caller.go:64)
- [`asyncCallWithOutCallback()`](openim-sdk-core/wasm/event_listener/caller.go:157)
- [`SyncCall()`](openim-sdk-core/wasm/event_listener/caller.go:243)
- [`ErrHandle()`](openim-sdk-core/wasm/event_listener/caller.go:333)

### 2. [`quick-monitor.sh`](openim-sdk-core/wasm/quick-monitor.sh) - 快速监控脚本
一个便捷的命令行工具，用于在 Kubernetes 环境中监控 WASM SDK 日志。

### 3. [`DEBUG_LOGGING_ADDED.md`](openim-sdk-core/wasm/DEBUG_LOGGING_ADDED.md) - 日志添加说明
详细说明了添加的日志内容和预期输出。

### 4. [`LOG_MONITORING_GUIDE.md`](openim-sdk-core/wasm/LOG_MONITORING_GUIDE.md) - 通用日志监控指南
包含各种日志过滤和监控技巧。

### 5. [`K8S_LOG_MONITORING.md`](openim-sdk-core/wasm/K8S_LOG_MONITORING.md) - Kubernetes 日志监控指南
专门针对 Kubernetes 环境的详细日志监控指南。

## 快速开始

### 1. 列出所有相关 Pod

```bash
# 使用默认命名空间
./quick-monitor.sh list

# 指定命名空间
./quick-monitor.sh -n openim list

# 指定 Pod 模式
./quick-monitor.sh -n openim -p wasm list
```

### 2. 实时监控错误

```bash
# 监控默认命名空间
./quick-monitor.sh monitor

# 监控特定命名空间
./quick-monitor.sh -n openim monitor

# 监控特定 Pod
./quick-monitor.sh -n openim -p wasm monitor
```

### 3. 分析最近的错误

```bash
# 分析最近 1 小时的错误（默认）
./quick-monitor.sh -n openim analyze

# 分析最近 24 小时的错误
./quick-monitor.sh -n openim -t 24h analyze

# 分析最近 30 分钟的错误
./quick-monitor.sh -n openim -t 30m analyze
```

### 4. 追踪特定 OperationID

```bash
# 追踪特定操作的完整日志
./quick-monitor.sh -n openim trace e8a1e76f-f364-4304-a07c-47fa8a506f41
```

### 5. 导出日志

```bash
# 导出所有日志
./quick-monitor.sh -n openim export

# 导出最近 2 小时的日志
./quick-monitor.sh -n openim -t 2h export
```

## 使用 kubectl 直接监控

### 查找 Pod

```bash
# 查看所有 OpenIM Pod
kubectl get pods -A | grep openim

# 查看特定命名空间的 Pod
kubectl get pods -n openim
```

### 实时监控日志

```bash
# 监控特定 Pod
kubectl logs -f <pod-name> -n openim | grep "index out of range"

# 监控所有 OpenIM Pod
kubectl logs -f -l app=openim -n openim --all-containers | grep "index out of range"
```

### 查看特定 OperationID 的日志

```bash
# 查看特定操作的日志
kubectl logs <pod-name> -n openim | grep "e8a1e76f-f364-4304-a07c-47fa8a506f41"
```

### 导出日志

```bash
# 导出 Pod 日志到文件
kubectl logs <pod-name> -n openim > /tmp/pod-logs.txt

# 导出最近 1 小时的日志
kubectl logs --since=1h <pod-name> -n openim > /tmp/recent-logs.txt
```

## 使用 stern（推荐）

### 安装 stern

```bash
# macOS
brew install stern

# Linux
wget https://github.com/stern/stern/releases/download/v1.25.0/stern_1.25.0_linux_amd64.tar.gz
tar -xzf stern_1.25.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/
```

### 使用 stern 监控

```bash
# 监控所有 OpenIM Pod
stern openim -n openim

# 监控并过滤错误
stern openim -n openim | grep "index out of range"

# 监控特定 Pod
stern openim-wasm -n openim
```

## 日志分析示例

### 1. 快速定位错误

```bash
# 查找最近的 index out of range 错误
kubectl logs -l app=openim -n openim --all-containers | grep "index out of range" | tail -20
```

### 2. 提取 OperationID

```bash
# 提取所有有错误的 OperationID
kubectl logs -l app=openim -n openim --all-containers | grep "index out of range" | grep -oP 'operationID:\K[^,]+' | sort -u
```

### 3. 追踪完整调用链

```bash
# 对每个 OperationID 追踪完整调用
for opid in $(kubectl logs -l app=openim -n openim --all-containers | grep "index out of range" | grep -oP 'operationID:\K[^,]+' | sort -u); do
    echo "=== OperationID: $opid ==="
    kubectl logs -l app=openim -n openim --all-containers | grep "$opid"
    echo ""
done
```

## 日志内容说明

### 函数入口日志
```
asyncCallWithCallback operationID=xxx funcFieldsNum=2 argumentsLen=2 hasCallback=true
```

- `operationID`: 唯一的操作标识符
- `funcFieldsNum`: 函数期望的参数数量
- `argumentsLen`: 实际传递的参数数量
- `hasCallback`: 是否有回调函数

### 参数处理日志
```
asyncCallWithCallback processing arg operationID=xxx argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2
```

- `argIndex`: 参数索引（从 0 开始）
- `paramIndex`: 函数参数索引（考虑回调偏移）

### 错误日志
```
asyncCallWithCallback index out of range operationID=xxx argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
```

当 `paramIndex >= funcFieldsNum` 时触发，表示尝试访问超出范围的参数。

## 故障排查流程

### 步骤 1: 识别错误

```bash
./quick-monitor.sh -n openim analyze
```

### 步骤 2: 提取 OperationID

从分析结果中复制有错误的 OperationID。

### 步骤 3: 追踪完整调用链

```bash
./quick-monitor.sh -n openim trace <operation-id>
```

### 步骤 4: 分析参数信息

查看日志中的以下信息：
- `funcFieldsNum`: 函数期望多少个参数
- `argumentsLen`: 实际传递了多少个参数
- `hasCallback`: 是否有回调函数
- `argIndex` 和 `paramIndex`: 哪个参数导致问题

### 步骤 5: 导出日志进行深入分析

```bash
./quick-monitor.sh -n openim export
```

## 常见问题

### Q: 如何查看所有命名空间的日志？

```bash
kubectl logs -f -A --all-containers | grep "index out of range"
```

### Q: 如何查看容器重启前的日志？

```bash
kubectl logs --previous <pod-name> -n openim
```

### Q: 如何同时监控多个 Pod？

使用 stern 工具：
```bash
stern openim -n openim | grep "index out of range"
```

### Q: 如何设置日志级别？

在 WASM SDK 初始化时设置：
```javascript
const sdk = new OpenIMSDK({
    logLevel: 'debug', // 或 'trace'
    // ... 其他配置
});
```

## 推荐工具

1. **stern** - 多 Pod 日志实时监控（强烈推荐）
2. **kubectl** - Kubernetes 命令行工具
3. **quick-monitor.sh** - 本项目提供的便捷脚本
4. **k9s** - 终端 UI 管理工具
5. **Lens** - Kubernetes GUI 管理工具

## 最佳实践

1. **使用标签选择器**而不是硬编码 Pod 名称
2. **设置合理的日志级别**（生产环境 INFO，调试时 DEBUG）
3. **定期清理旧日志**避免磁盘空间不足
4. **使用 stern**进行多 Pod 监控
5. **导出日志**进行深入分析
6. **设置告警**及时发现问题

## 下一步

1. 重新构建 WASM SDK 以包含新的日志
2. 部署到 Kubernetes 环境
3. 使用 `quick-monitor.sh` 监控日志
4. 分析日志找出根本原因
5. 修复问题并验证

## 获取帮助

```bash
# 查看脚本帮助
./quick-monitor.sh --help

# 查看详细文档
cat K8S_LOG_MONITORING.md
cat LOG_MONITORING_GUIDE.md
cat DEBUG_LOGGING_ADDED.md
```

## 联系方式

如有问题，请查看项目文档或提交 Issue。
