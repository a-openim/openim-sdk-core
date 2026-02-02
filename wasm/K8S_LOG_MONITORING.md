# Kubernetes 环境下 WASM SDK 日志监控指南

## 前提条件
- 已安装 kubectl 并配置好 kubeconfig
- 有访问 Kubernetes 集群的权限
- 了解基本的 kubectl 命令

## 1. 查找相关 Pod

### 查找所有 OpenIM 相关的 Pod
```bash
# 查看所有命名空间中的 OpenIM Pod
kubectl get pods -A | grep openim

# 查看特定命名空间中的 Pod
kubectl get pods -n <namespace> | grep openim

# 查看包含 WASM 的 Pod
kubectl get pods -A | grep -i wasm
```

### 查找运行 WASM SDK 的 Pod
```bash
# 查看所有 Pod 的标签
kubectl get pods -A --show-labels

# 根据标签查找
kubectl get pods -l app=openim-wasm -A
kubectl get pods -l component=wasm -A
```

## 2. 实时监控日志

### 基础日志查看
```bash
# 查看特定 Pod 的日志
kubectl logs -f <pod-name> -n <namespace>

# 查看所有容器的日志（如果 Pod 有多个容器）
kubectl logs -f <pod-name> -n <namespace> --all-containers

# 查看最近 100 行日志
kubectl logs --tail=100 <pod-name> -n <namespace>

# 查看最近 1 小时的日志
kubectl logs --since=1h <pod-name> -n <namespace>
```

### 过滤特定错误
```bash
# 实时监控 index out of range 错误
kubectl logs -f <pod-name> -n <namespace> | grep "index out of range"

# 监控所有 WASM 相关错误
kubectl logs -f <pod-name> -n <namespace> | grep -E "(ERROR|WARN).*wasm"

# 监控特定函数的调用
kubectl logs -f <pod-name> -n <namespace> | grep -E "getFriendApplicationList|getGroupApplicationList"
```

### 使用 OperationID 追踪
```bash
# 追踪特定 operationID 的所有日志
kubectl logs <pod-name> -n <namespace> | grep "e8a1e76f-f364-4304-a07c-47fa8a506f41"

# 实时追踪特定 operationID
kubectl logs -f <pod-name> -n <namespace> | grep --line-buffered "e8a1e76f-f364-4304-a07c-47fa8a506f41"
```

## 3. 多 Pod 日志监控

### 监控所有相关 Pod
```bash
# 监控所有命名空间中的 OpenIM Pod
kubectl logs -f -l app=openim -A --all-containers | grep "index out of range"

# 监控特定命名空间中的所有 Pod
kubectl logs -f -n <namespace> --all-containers | grep "index out of range"

# 使用 stern 工具（推荐，需要先安装）
stern openim -n <namespace> | grep "index out of range"
```

### 安装 stern（推荐工具）
```bash
# macOS
brew install stern

# Linux
wget https://github.com/stern/stern/releases/download/v1.25.0/stern_1.25.0_linux_amd64.tar.gz
tar -xzf stern_1.25.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/

# 使用 stern 监控
stern openim -n <namespace> --tail 100
stern openim -n <namespace> | grep "index out of range"
```

## 4. 日志导出和分析

### 导出日志到文件
```bash
# 导出特定 Pod 的日志
kubectl logs <pod-name> -n <namespace> > /tmp/pod-logs.txt

# 导出所有相关 Pod 的日志
kubectl logs -l app=openim -n <namespace> --all-containers > /tmp/all-logs.txt

# 导出最近 1 小时的日志
kubectl logs --since=1h <pod-name> -n <namespace> > /tmp/recent-logs.txt
```

### 分析导出的日志
```bash
# 统计错误数量
grep -c "index out of range" /tmp/all-logs.txt

# 提取所有 operationID
grep -oP 'operationID:\K[^,]+' /tmp/all-logs.txt | sort -u

# 提取特定 operationID 的完整日志
for opid in $(grep "index out of range" /tmp/all-logs.txt | grep -oP 'operationID:\K[^,]+' | sort -u); do
    echo "=== OperationID: $opid ==="
    grep "$opid" /tmp/all-logs.txt
    echo ""
done > /tmp/error-analysis.txt
```

## 5. 使用 kubectl 插件

### 安装 kubectl-logs（增强的日志查看）
```bash
# 安装
kubectl krew install logs

# 使用
kubectl logs <pod-name> -n <namespace> --filter="index out of range"
```

### 安装 kubectl-view-allocations（查看资源使用）
```bash
kubectl krew install view-allocations
kubectl view-allocations
```

## 6. 创建监控脚本

### 创建 `monitor-wasm-logs.sh`
```bash
#!/bin/bash

NAMESPACE="${1:-default}"
POD_PATTERN="${2:-openim}"

echo "=== Monitoring WASM SDK logs in namespace: $NAMESPACE ==="
echo "=== Pod pattern: $POD_PATTERN ==="
echo ""

# 获取所有匹配的 Pod
PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

if [ -z "$PODS" ]; then
    echo "No pods found matching pattern: $POD_PATTERN"
    exit 1
fi

echo "Found pods:"
echo "$PODS"
echo ""

# 监控所有 Pod 的日志
for pod in $PODS; do
    echo "=== Monitoring pod: $pod ==="
    kubectl logs -f $pod -n $NAMESPACE | grep --line-buffered -E "(asyncCallWithCallback|asyncCallWithOutCallback|SyncCall|index out of range)" &
done

# 等待所有后台进程
wait
```

使用方法：
```bash
chmod +x monitor-wasm-logs.sh
./monitor-wasm-logs.sh <namespace> <pod-pattern>
```

### 创建 `analyze-wasm-errors.sh`
```bash
#!/bin/bash

NAMESPACE="${1:-default}"
POD_PATTERN="${2:-openim}"
SINCE="${3:-1h}"

echo "=== Analyzing WASM SDK errors in namespace: $NAMESPACE ==="
echo "=== Pod pattern: $POD_PATTERN ==="
echo "=== Time range: last $SINCE ==="
echo ""

# 获取所有匹配的 Pod
PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

if [ -z "$PODS" ]; then
    echo "No pods found matching pattern: $POD_PATTERN"
    exit 1
fi

# 收集所有日志
echo "Collecting logs..."
ALL_LOGS="/tmp/wasm-logs-$(date +%Y%m%d-%H%M%S).txt"
for pod in $PODS; do
    echo "=== Logs from pod: $pod ===" >> $ALL_LOGS
    kubectl logs --since=$SINCE $pod -n $NAMESPACE >> $ALL_LOGS
    echo "" >> $ALL_LOGS
done

# 分析错误
echo ""
echo "=== Error Analysis ==="
echo ""

# 统计错误数量
ERROR_COUNT=$(grep -c "index out of range" $ALL_LOGS)
echo "Total 'index out of range' errors: $ERROR_COUNT"
echo ""

# 提取所有 operationID
echo "=== OperationIDs with errors ==="
grep "index out of range" $ALL_LOGS | grep -oP 'operationID:\K[^,]+' | sort -u
echo ""

# 显示每个错误的详细信息
echo "=== Detailed Error Information ==="
for opid in $(grep "index out of range" $ALL_LOGS | grep -oP 'operationID:\K[^,]+' | sort -u); do
    echo "=== OperationID: $opid ==="
    grep "$opid" $ALL_LOGS | grep -E "(asyncCallWithCallback|asyncCallWithOutCallback|SyncCall|index out of range)"
    echo ""
done

echo "Logs saved to: $ALL_LOGS"
```

使用方法：
```bash
chmod +x analyze-wasm-errors.sh
./analyze-wasm-errors.sh <namespace> <pod-pattern> <time-range>
```

## 7. 使用 Kubernetes Dashboard

如果安装了 Kubernetes Dashboard：

1. 访问 Dashboard UI
2. 导航到 Workloads → Pods
3. 选择要查看的 Pod
4. 点击 "Logs" 标签
5. 使用搜索框过滤日志

## 8. 使用日志聚合系统

### 如果使用 ELK Stack
```bash
# 通过 Kibana 查询
{
  "query": {
    "bool": {
      "must": [
        { "match": { "kubernetes.namespace_name": "<namespace>" } },
        { "match": { "message": "index out of range" } }
      ]
    }
  }
}
```

### 如果使用 Loki + Grafana
```logql
{namespace="<namespace>", pod=~"openim.*"} |= "index out of range"
```

## 9. 设置告警

### 使用 Prometheus Alertmanager
创建告警规则 `wasm-sdk-alerts.yaml`:
```yaml
groups:
- name: wasm-sdk-errors
  rules:
  - alert: WASMIndexOutOfRangeError
    expr: |
      count_over_time({namespace="openim", pod=~".*"} |= "index out of range"[5m]) > 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "WASM SDK index out of range error detected"
      description: "Detected {{ $value }} index out of range errors in the last 5 minutes"
```

应用告警规则：
```bash
kubectl apply -f wasm-sdk-alerts.yaml -n <namespace>
```

## 10. 实用命令速查

```bash
# 查看最近的错误
kubectl logs --tail=100 <pod-name> -n <namespace> | grep ERROR

# 查看特定时间段的日志
kubectl logs --since-time="2026-02-02T11:00:00Z" --until-time="2026-02-02T12:00:00Z" <pod-name> -n <namespace>

# 查看上一个容器的日志（如果容器重启了）
kubectl logs --previous <pod-name> -n <namespace>

# 查看所有 Pod 的日志并过滤
kubectl logs -l app=openim -n <namespace> --all-containers | grep "index out of range"

# 使用 stern 实时监控多个 Pod
stern openim -n <namespace> | grep "index out of range"

# 导出日志并分析
kubectl logs <pod-name> -n <namespace> > /tmp/logs.txt && grep "index out of range" /tmp/logs.txt
```

## 11. 故障排查流程

当遇到 "index out of range" 错误时：

1. **识别错误发生的 Pod**
   ```bash
   kubectl logs -l app=openim -n <namespace> --all-containers | grep "index out of range" | tail -1
   ```

2. **提取 OperationID**
   ```bash
   kubectl logs <pod-name> -n <namespace> | grep "index out of range" | grep -oP 'operationID:\K[^,]+' | tail -1
   ```

3. **查看完整调用链**
   ```bash
   kubectl logs <pod-name> -n <namespace> | grep "<operation-id>"
   ```

4. **分析参数信息**
   ```bash
   kubectl logs <pod-name> -n <namespace> | grep "<operation-id>" | grep "funcFieldsNum\|argumentsLen\|hasCallback"
   ```

5. **导出日志进行深入分析**
   ```bash
   kubectl logs <pod-name> -n <namespace> > /tmp/pod-logs.txt
   ```

## 12. 性能优化

### 减少日志量
```bash
# 只查看错误日志
kubectl logs <pod-name> -n <namespace> | grep ERROR

# 只查看特定时间段的日志
kubectl logs --since=10m <pod-name> -n <namespace>

# 使用 tail 限制输出
kubectl logs --tail=50 <pod-name> -n <namespace>
```

### 使用 grep 高效过滤
```bash
# 使用 --line-buffered 实时过滤
kubectl logs -f <pod-name> -n <namespace> | grep --line-buffered "index out of range"

# 使用多个过滤条件
kubectl logs <pod-name> -n <namespace> | grep -E "ERROR.*index out of range"
```

## 13. 常见问题

### Q: 如何查看所有命名空间的日志？
```bash
kubectl logs -f -A --all-containers | grep "index out of range"
```

### Q: 如何查看特定时间之前的日志？
```bash
kubectl logs --since-time="2026-02-02T10:00:00Z" <pod-name> -n <namespace>
```

### Q: 如何查看容器重启前的日志？
```bash
kubectl logs --previous <pod-name> -n <namespace>
```

### Q: 如何同时查看多个 Pod 的日志？
```bash
# 使用 stern（推荐）
stern openim -n <namespace>

# 或者使用 kubectl 并行
kubectl get pods -n <namespace> -o name | xargs -I {} kubectl logs -f {} -n <namespace> &
```

## 14. 推荐工具

1. **stern** - 多 Pod 日志实时监控
2. **kubectl-krew** - kubectl 插件管理器
3. **k9s** - 终端 UI 管理工具
4. **Lens** - Kubernetes GUI 管理工具
5. **ELK Stack** - 企业级日志分析
6. **Loki + Grafana** - 轻量级日志聚合

## 15. 最佳实践

1. **使用标签选择器**而不是硬编码 Pod 名称
2. **设置合理的日志级别**（生产环境使用 INFO，调试时使用 DEBUG）
3. **定期清理旧日志**避免磁盘空间不足
4. **使用日志轮转**配置
5. **设置日志保留策略**
6. **使用结构化日志**便于查询和分析
7. **配置日志聚合系统**用于长期存储和分析
8. **设置告警规则**及时发现问题
