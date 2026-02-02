# WASM SDK 构建和部署指南

## 项目架构

```
a-openim-all/
├── openim-sdk-core/          # WASM SDK 源代码（已添加调试日志）
├── openim-h5-demo/          # H5 前端项目（使用 WASM SDK）
└── open-im-server/           # 后端服务（运行在 Kubernetes 中）
```

## 构建和部署步骤

### 步骤 1: 构建 WASM SDK

在 `openim-sdk-core` 目录中执行：

```bash
cd openim-sdk-core

# 构建 WASM SDK
make build-wasm

# 或者直接使用 go build
GOOS=js GOARCH=wasm go build -trimpath -ldflags "-s -w" -o _output/bin/openIM.wasm wasm/cmd/main.go
```

构建完成后，WASM 文件位于：
- `_output/bin/openIM.wasm`

### 步骤 2: 复制 WASM 文件到 H5 项目

```bash
# 复制 WASM 文件
cp openim-sdk-core/_output/bin/openIM.wasm openim-h5-demo/public/

# 复制 wasm_exec.js（如果需要）
cp $(go env GOROOT)/misc/wasm/wasm_exec.js openim-h5-demo/public/
```

### 步骤 3: 在浏览器中查看日志

1. **启动 H5 开发服务器**

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

2. **打开浏览器开发者工具**

   - 在浏览器中打开 H5 应用（通常是 `http://localhost:5173` 或类似地址）
   - 按 `F12` 或右键选择"检查"打开开发者工具
   - 切换到 **Console** 标签

3. **触发错误操作**

   执行会导致错误的操作，例如：
   - 获取好友申请列表
   - 获取群组申请列表

4. **查看详细日志**

   在控制台中，您将看到类似以下的详细日志：

   ```
   DEBUG asyncCallWithCallback operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 funcFieldsNum=2 argumentsLen=2 hasCallback=true
   DEBUG asyncCallWithCallback processing arg operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=0 paramIndex=1 funcFieldsNum=2 argumentsLen=2
   DEBUG asyncCallWithCallback processing arg operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2
   ERROR asyncCallWithCallback index out of range operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 argIndex=1 paramIndex=2 funcFieldsNum=2 argumentsLen=2 hasCallback=true
   ERROR ERR operationID=e8a1e76f-f364-4304-a07c-47fa8a506f41 r=index out of range: trying to access parameter index 2 but function has only 2 parameters
   ```

## 快速构建脚本

创建一个便捷的构建脚本 `build-and-copy.sh`：

```bash
#!/bin/bash

set -e

echo "=========================================="
echo "WASM SDK 构建和部署脚本"
echo "=========================================="

# 1. 构建 WASM SDK
echo ""
echo "[1/3] 构建 WASM SDK..."
cd openim-sdk-core
make build-wasm

if [ $? -ne 0 ]; then
    echo "❌ WASM SDK 构建失败"
    exit 1
fi

echo "✅ WASM SDK 构建成功"

# 2. 复制文件到 H5 项目
echo ""
echo "[2/3] 复制 WASM 文件到 H5 项目..."
cd ..

# 复制 WASM 文件
cp openim-sdk-core/_output/bin/openIM.wasm openim-h5-demo/public/

# 复制 wasm_exec.js
GOROOT=$(go env GOROOT)
if [ -f "$GOROOT/misc/wasm/wasm_exec.js" ]; then
    cp "$GOROOT/misc/wasm/wasm_exec.js" openim-h5-demo/public/
    echo "✅ 已复制 wasm_exec.js"
else
    echo "⚠️  未找到 wasm_exec.js，跳过"
fi

echo "✅ 文件复制完成"

# 3. 显示下一步操作
echo ""
echo "[3/3] 构建完成！"
echo ""
echo "=========================================="
echo "下一步操作："
echo "=========================================="
echo ""
echo "1. 启动 H5 开发服务器："
echo "   cd openim-h5-demo"
echo "   npm run dev"
echo ""
echo "2. 在浏览器中打开应用（通常是 http://localhost:5173）"
echo ""
echo "3. 打开浏览器开发者工具（F12）"
echo ""
echo "4. 切换到 Console 标签"
echo ""
echo "5. 触发会导致错误的操作"
echo ""
echo "6. 查看详细的调试日志"
echo ""
echo "=========================================="
```

使用方法：

```bash
chmod +x build-and-copy.sh
./build-and-copy.sh
```

## 使用 go work 的情况

如果您使用 `go work`，确保 `openim-sdk-core` 在工作空间中：

```bash
# 查看当前工作空间
go work use

# 如果 openim-sdk-core 不在工作空间中，添加它
go work use ./openim-sdk-core
```

## 验证构建

### 检查 WASM 文件

```bash
# 检查文件是否存在
ls -lh openim-sdk-core/_output/bin/openIM.wasm

# 检查文件大小（应该在几百 KB 到几 MB 之间）
```

### 检查 H5 项目中的文件

```bash
# 检查文件是否已复制
ls -lh openim-h5-demo/public/openIM.wasm
ls -lh openim-h5-demo/public/wasm_exec.js
```

## 常见问题

### Q1: 构建失败，提示找不到 wasm_exec.js

**解决方案：**

```bash
# 检查 Go 安装
go version

# 查找 wasm_exec.js
find $(go env GOROOT) -name "wasm_exec.js"

# 如果找不到，可以从 Go 源码获取
# 或者在 H5 项目中已经包含了该文件
```

### Q2: 浏览器控制台看不到日志

**可能的原因：**

1. **WASM 文件没有更新** - 清除浏览器缓存
2. **日志级别设置不正确** - 检查 SDK 初始化配置
3. **控制台过滤** - 确保没有过滤掉 DEBUG 或 INFO 级别的日志

**解决方案：**

```javascript
// 在 H5 项目中，确保 SDK 初始化时设置了正确的日志级别
const sdk = new OpenIMSDK({
    logLevel: 'debug', // 或 'trace'
    // ... 其他配置
});
```

### Q3: 构建的 WASM 文件太大

**解决方案：**

```bash
# 使用更激进的优化
GOOS=js GOARCH=wasm go build -trimpath -ldflags "-s -w" -o _output/bin/openIM.wasm wasm/cmd/main.go

# 或者使用 wasm-opt（需要安装 Binaryen）
wasm-opt -O3 -o _output/bin/openIM.wasm _output/bin/openIM.wasm
```

### Q4: H5 项目无法加载 WASM 文件

**解决方案：**

1. 检查文件路径是否正确
2. 检查文件权限
3. 检查浏览器控制台的网络请求
4. 确保服务器正确配置了 MIME 类型（`application/wasm`）

## 监控后端服务日志

如果您想同时监控后端服务的日志（不是 WASM SDK），可以使用我们创建的工具：

```bash
cd openim-sdk-core/wasm

# 监控所有 OpenIM 服务的错误
./quick-monitor.sh -n openim monitor

# 分析最近的错误
./quick-monitor.sh -n openim analyze

# 查看特定服务的日志
kubectl logs -f openim-api-xxx -n openim
kubectl logs -f friend-rpc-server-xxx -n openim
```

## 日志分析

### 理解日志输出

1. **funcFieldsNum**: 函数期望的参数数量
2. **argumentsLen**: 实际传递的参数数量
3. **hasCallback**: 是否有回调函数
4. **argIndex**: 参数索引（从 0 开始）
5. **paramIndex**: 函数参数索引（考虑回调偏移）

### 错误分析

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

这表示：
- 函数期望 2 个参数（funcFieldsNum=2）
- 实际传递了 2 个参数（argumentsLen=2）
- 有回调函数（hasCallback=true）
- 尝试访问参数索引 2（paramIndex=2）
- 但函数只有 2 个参数（索引 0 和 1）

**问题原因：**
- 当 `hasCallback=true` 时，第一个参数是回调（索引 0）
- 实际的函数参数从索引 1 开始
- 如果传递了 2 个参数，加上回调，总共需要 3 个参数
- 但函数只定义了 2 个参数

## 下一步

1. **构建 WASM SDK** - 使用上面的脚本或手动构建
2. **复制到 H5 项目** - 确保文件已更新
3. **启动 H5 开发服务器** - 在本地测试
4. **触发错误** - 执行会导致错误的操作
5. **查看日志** - 在浏览器控制台中分析详细日志
6. **修复问题** - 根据日志信息修复代码
7. **验证修复** - 重新构建并测试

## 相关文档

- [`DEBUG_LOGGING_ADDED.md`](openim-sdk-core/wasm/DEBUG_LOGGING_ADDED.md) - 日志添加说明
- [`README.md`](openim-sdk-core/wasm/README.md) - 使用指南
- [`K8S_LOG_MONITORING.md`](openim-sdk-core/wasm/K8S_LOG_MONITORING.md) - Kubernetes 日志监控
