#!/bin/bash

# WASM SDK 日志快速监控脚本
# 用于 Kubernetes 环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
NAMESPACE="${NAMESPACE:-default}"
POD_PATTERN="${POD_PATTERN:-openim}"
TIME_RANGE="${TIME_RANGE:-1h}"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
WASM SDK 日志快速监控脚本

用法: $0 [选项] [命令]

选项:
    -n, --namespace <namespace>    指定命名空间 (默认: $NAMESPACE)
    -p, --pod <pattern>           Pod 名称模式 (默认: $POD_PATTERN)
    -t, --time <range>            时间范围 (默认: $TIME_RANGE)
    -h, --help                    显示此帮助信息

命令:
    list                           列出所有相关 Pod
    monitor                        实时监控 index out of range 错误
    analyze                        分析最近的错误
    trace <operation-id>           追踪特定 operationID 的日志
    export                         导出日志到文件

示例:
    $0 list                                          # 列出所有 Pod
    $0 -n openim monitor                             # 监控 openim 命名空间
    $0 -n openim -p wasm analyze                     # 分析 wasm Pod 的错误
    $0 trace e8a1e76f-f364-4304-a07c-47fa8a506f41   # 追踪特定操作
    $0 export                                        # 导出日志

EOF
}

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群"
        exit 1
    fi

    print_success "kubectl 可用，已连接到集群"
}

# 列出所有相关 Pod
list_pods() {
    print_info "在命名空间 '$NAMESPACE' 中查找匹配 '$POD_PATTERN' 的 Pod..."
    echo ""

    PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

    if [ -z "$PODS" ]; then
        print_warning "未找到匹配的 Pod"
        print_info "尝试列出所有 Pod:"
        kubectl get pods -n $NAMESPACE
        exit 0
    fi

    print_success "找到以下 Pod:"
    echo ""
    kubectl get pods -n $NAMESPACE | grep $POD_PATTERN
    echo ""
    echo "Pod 列表:"
    echo "$PODS" | while read pod; do
        echo "  - $pod"
    done
}

# 实时监控错误
monitor_errors() {
    print_info "在命名空间 '$NAMESPACE' 中监控匹配 '$POD_PATTERN' 的 Pod..."
    print_info "查找 'index out of range' 错误..."
    print_info "按 Ctrl+C 停止监控"
    echo ""

    PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

    if [ -z "$PODS" ]; then
        print_error "未找到匹配的 Pod"
        exit 1
    fi

    # 使用 stern 如果可用，否则使用 kubectl
    if command -v stern &> /dev/null; then
        print_success "使用 stern 监控..."
        stern "$POD_PATTERN" -n $NAMESPACE | grep --line-buffered "index out of range"
    else
        print_warning "stern 未安装，使用 kubectl 监控..."
        print_info "建议安装 stern: brew install stern"
        echo ""

        # 监控所有 Pod
        for pod in $PODS; do
            print_info "监控 Pod: $pod"
            kubectl logs -f $pod -n $NAMESPACE 2>&1 | grep --line-buffered "index out of range" &
        done

        # 等待所有后台进程
        wait
    fi
}

# 分析最近的错误
analyze_errors() {
    print_info "在命名空间 '$NAMESPACE' 中分析匹配 '$POD_PATTERN' 的 Pod..."
    print_info "时间范围: 最近 $TIME_RANGE"
    echo ""

    PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

    if [ -z "$PODS" ]; then
        print_error "未找到匹配的 Pod"
        exit 1
    fi

    # 收集所有日志
    print_info "收集日志..."
    TEMP_LOGS="/tmp/wasm-logs-$(date +%Y%m%d-%H%M%S).txt"

    for pod in $PODS; do
        echo "=== Pod: $pod ===" >> $TEMP_LOGS
        kubectl logs --since=$TIME_RANGE $pod -n $NAMESPACE >> $TEMP_LOGS 2>&1
        echo "" >> $TEMP_LOGS
    done

    # 统计错误
    ERROR_COUNT=$(grep -c "index out of range" $TEMP_LOGS 2>/dev/null || true)
    if [ -z "$ERROR_COUNT" ] || [ "$ERROR_COUNT" -lt 0 ]; then
        ERROR_COUNT=0
    fi

    echo ""
    print_info "=== 错误分析结果 ==="
    echo ""
    echo "总错误数: $ERROR_COUNT"
    echo ""

    if [ "$ERROR_COUNT" -eq "0" ]; then
        print_success "未发现 'index out of range' 错误"
        rm -f $TEMP_LOGS
        exit 0
    fi

    # 提取所有 operationID
    print_info "发现错误的 OperationID:"
    echo ""
    grep "index out of range" $TEMP_LOGS | grep -oP 'operationID:\K[^,]+' | sort -u | while read opid; do
        echo "  - $opid"
    done
    echo ""

    # 显示每个错误的详细信息
    print_info "详细错误信息:"
    echo ""
    for opid in $(grep "index out of range" $TEMP_LOGS | grep -oP 'operationID:\K[^,]+' | sort -u); do
        echo "=== OperationID: $opid ==="
        grep "$opid" $TEMP_LOGS | grep -E "(asyncCallWithCallback|asyncCallWithOutCallback|SyncCall|index out of range)" | head -20
        echo ""
    done

    print_success "日志已保存到: $TEMP_LOGS"
    print_info "使用以下命令查看完整日志: cat $TEMP_LOGS"
}

# 追踪特定 operationID
trace_operation() {
    OPERATION_ID="$1"

    if [ -z "$OPERATION_ID" ]; then
        print_error "请提供 operationID"
        echo "用法: $0 trace <operation-id>"
        exit 1
    fi

    print_info "在命名空间 '$NAMESPACE' 中追踪 operationID: $OPERATION_ID"
    echo ""

    PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

    if [ -z "$PODS" ]; then
        print_error "未找到匹配的 Pod"
        exit 1
    fi

    # 在所有 Pod 中查找
    FOUND=false
    for pod in $PODS; do
        LOGS=$(kubectl logs $pod -n $NAMESPACE 2>/dev/null | grep "$OPERATION_ID" || true)
        if [ -n "$LOGS" ]; then
            print_success "在 Pod '$pod' 中找到日志:"
            echo ""
            echo "$LOGS"
            echo ""
            FOUND=true
        fi
    done

    if [ "$FOUND" = false ]; then
        print_warning "未找到 operationID '$OPERATION_ID' 的日志"
        print_info "尝试查看最近的日志:"
        for pod in $PODS; do
            print_info "Pod: $pod"
            kubectl logs --tail=50 $pod -n $NAMESPACE | grep -E "(asyncCallWithCallback|asyncCallWithOutCallback|SyncCall)" | tail -5
            echo ""
        done
    fi
}

# 导出日志
export_logs() {
    print_info "在命名空间 '$NAMESPACE' 中导出匹配 '$POD_PATTERN' 的 Pod 日志..."
    print_info "时间范围: 最近 $TIME_RANGE"
    echo ""

    PODS=$(kubectl get pods -n $NAMESPACE | grep $POD_PATTERN | awk '{print $1}')

    if [ -z "$PODS" ]; then
        print_error "未找到匹配的 Pod"
        exit 1
    fi

    EXPORT_DIR="/tmp/wasm-logs-export-$(date +%Y%m%d-%H%M%S)"
    mkdir -p $EXPORT_DIR

    print_info "导出目录: $EXPORT_DIR"
    echo ""

    for pod in $PODS; do
        print_info "导出 Pod: $pod"
        kubectl logs --since=$TIME_RANGE $pod -n $NAMESPACE > "$EXPORT_DIR/${pod}.log" 2>&1
        print_success "已导出: $EXPORT_DIR/${pod}.log"
    done

    # 创建汇总文件
    print_info "创建汇总文件..."
    cat "$EXPORT_DIR"/*.log > "$EXPORT_DIR/all-logs.log"

    # 创建错误汇总
    grep "index out of range" "$EXPORT_DIR/all-logs.log" > "$EXPORT_DIR/errors-only.log" 2>/dev/null || true

    echo ""
    print_success "日志导出完成!"
    echo ""
    echo "导出目录: $EXPORT_DIR"
    echo "文件列表:"
    ls -lh $EXPORT_DIR
    echo ""
    print_info "查看所有日志: cat $EXPORT_DIR/all-logs.log"
    print_info "查看错误日志: cat $EXPORT_DIR/errors-only.log"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -p|--pod)
                POD_PATTERN="$2"
                shift 2
                ;;
            -t|--time)
                TIME_RANGE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            list|monitor|analyze|trace|export)
                COMMAND="$1"
                shift
                break
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查 kubectl
    check_kubectl

    # 执行命令
    case ${COMMAND:-help} in
        list)
            list_pods
            ;;
        monitor)
            monitor_errors
            ;;
        analyze)
            analyze_errors
            ;;
        trace)
            trace_operation "$1"
            ;;
        export)
            export_logs
            ;;
        help)
            show_help
            ;;
        *)
            print_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
