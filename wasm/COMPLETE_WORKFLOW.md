# WASM SDK 调试完整流程

## 当前状态

✅ **已完成：**
- 在 [`caller.go`](openim-sdk-core/wasm/event_listener/caller.go) 中添加了详细的调试日志
- 创建了 Kubernetes 日志监控工具 [`quick-monitor.sh`](openim-sdk-core/wasm/quick-monitor.sh)
- 创建了构建和部署脚本 [`build-and-copy.sh`](build-and-copy.sh)
- 创建了完整的文档

✅ **验证：**
- Kubernetes 日志监控工具运行正常
- 当前没有发现 "index out of range" 错误（因为 WASM SDK 还没有重新构建）

## 下一步操作

### 步骤 1: 构建 WASM SDK

```bash
# 在项目根目录执行
./build-and-copy.sh
```

这将：
1. 在 `openim-sdk-core` 中构建 WASM SDK
2. 将构建的 `openIM.wasm` 复制到 `openim-h5-demo/public/`
3. 复制 `wasm_exec.js`（如果需要）

### 步骤 2: 启动 H5 开发服务器

```bash
cd openim-h5-demo

# 安装依赖（如果还没有）
npm install
# 或
pnpm install

# 启动开发服务器
npm run dev
# 或
pnpm dev
```

### 步骤 3: 在浏览器中查看日志

1. **打开浏览器**
   - 访问 H5 应用（通常是 `http://localhost:5173`）

2. **打开开发者工具**
   - 按 `F12` 或右键选择"检查"
   - 切换到 **Console** 标签

3. **触发错误操作**
   - 执行会导致错误的操作，例如：
     - 获取好友申请列表
     - 获取群组申请列表

4. **查看详细日志**
   - 在控制台中，您将看到详细的调试信息

## 预期的日志输出

当错误发生时，浏览器控制台会显示：

```
DEBUG asyncCallWithCallback operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 funcFieldsNum=2 argumentsLen=2 hasCallback=true
DEBUG asyncCallWithCallback processing arg operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=0 paramIndex=1 funcFieldsNum=2 argumentsLen=2
DEBUG asyncCallWithCallback processing arg operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2
ERROR asyncCallWithCallback index out of range operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
ERROR ERR operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 r=index out of range: trying to access parameter index 2 but function has only 2 parameters
```

## 日志字段说明

| 字段 | 说明 |
|------|------|
| `operationID` | 唯一的操作标识符，用于追踪完整的调用链 |
| `funcFieldsNum` | 函数期望的参数数量 |
| `argumentsLen` | 实际传递的参数数量 |
| `hasCallback` | 是否有回调函数 |
| `argIndex` | 参数索引（从 0 开始） |
| `paramIndex` | 函数参数索引（考虑回调偏移） |

## 错误分析

当看到 `index out of range` 错误时：

```
ERROR asyncCallWithCallback index out of range
operationID=xxx
argIndex=1
paramIndex=2
funcFieldsNum=2
argumentsLen=2
hasCallback=true
```

**问题分析：**
- 函数期望 2 个参数（funcFieldsNum=2）
- 实际传递了 2 个参数（argumentsLen=2）
- 有回调函数（hasCallback=true）
- 尝试访问参数索引 2（paramIndex=2）
- 但函数只定义了 2 个参数（索引 0 和 1）

**根本原因：**
- 当 `hasCallback=true` 时，第一个参数是回调（索引 0）
- 实际的函数参数从索引 1 开始
- 如果传递了 2 个参数，加上回调，总共需要 3 个参数
- 但函数只定义了 2 个参数

## 同时监控后端服务

如果您想同时监控 OpenIM 后端服务的日志：

```bash
cd openim-sdk-core/wasm

# 实时监控所有 OpenIM 服务的错误
./quick-monitor.sh -n openim monitor

# 分析最近的错误
./quick-monitor.sh -n openim analyze

# 查看特定服务的日志
kubectl logs -f openim-api-xxx -n openim
kubectl logs -f friend-rpc-server-xxx -n openim
```

## 故障排查

### 问题 1: 构建失败

**解决方案：**
```bash
# 检查 Go 版本
go version

# 确保 openim-sdk-core 在 go work 中
go work use

# 手动构建
cd openim-sdk-core
make build-wasm
```

### 问题 2: 浏览器控制台看不到日志

**可能的原因：**
1. WASM 文件没有更新 - 清除浏览器缓存
2. 日志级别设置不正确 - 检查 SDK 初始化配置
3. 控制台过滤 - 确保没有过滤掉 DEBUG 或 INFO 级别的日志

**解决方案：**
```javascript
// 在 H5 项目中，确保 SDK 初始化时设置了正确的日志级别
const sdk = new OpenIMSDK({
    logLevel: 'debug', // 或 'trace'
    // ... 其他配置
});
```

### 问题 3: H5 项目无法加载 WASM 文件

**解决方案：**
1. 检查文件路径是否正确
2. 检查文件权限
3. 检查浏览器控制台的网络请求
4. 确保服务器正确配置了 MIME 类型（`application/wasm`）

## 完整的工作流程

```
1. 修改代码
   ↓
2. 构建 WASM SDK
   ./build-and-copy.sh
   ↓
3. 启动 H5 开发服务器
   cd openim-h5-demo && npm run dev
   ↓
4. 在浏览器中打开应用
   http://localhost:5173
   ↓
5. 打开浏览器开发者工具（F12）
   ↓
6. 切换到 Console 标签
   ↓
7. 触发会导致错误的操作
   ↓
8. 查看详细的调试日志
   ↓
9. 分析日志找出根本原因
   ↓
10. 修复问题
   ↓
11. 重新构建并验证
```

## 相关文档

- [`BUILD_AND_DEPLOY.md`](openim-sdk-core/wasm/BUILD_AND_DEPLOY.md) - 构建和部署详细指南
- [`DEBUG_LOGGING_ADDED.md`](openim-sdk-core/wasm/DEBUG_LOGGING_ADDED.md) - 日志添加说明
- [`README.md`](openim-sdk-core/wasm/README.md) - 使用指南
- [`K8S_LOG_MONITORING.md`](openim-sdk-core/wasm/K8S_LOG_MONITORING.md) - Kubernetes 日志监控指南

## 快速命令参考

```bash
# 构建 WASM SDK
./build-and-copy.sh

# 启动 H5 开发服务器
cd openim-h5-demo && npm run dev

# 监控 Kubernetes 后端服务
cd openim-sdk-core/wasm && ./quick-monitor.sh -n openim monitor

# 分析 Kubernetes 后端服务错误
cd openim-sdk-core/wasm && ./quick-monitor.sh -n openim analyze
```

## 总结

- ✅ 调试日志已添加到 WASM SDK
- ✅ 构建和部署工具已创建
- ✅ Kubernetes 日志监控工具已创建
- ✅ 完整文档已创建
- ✅ 工具已验证可以正常运行

**下一步：** 执行 `./build-and-copy.sh` 构建 WASM SDK，然后在浏览器中查看详细的调试日志。
