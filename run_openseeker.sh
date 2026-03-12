
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY

MODEL_PATH="path/to/OpenSeeker-v1-30B-SFT"
PORT=30018
GPU_IDS="0,1,2,3"
NUM_GPUS=4
DP_SIZE=1
HOST="0.0.0.0"
WORKERS=1
MAX_RUNNING_REQUESTS=2000
CONTEXT_LENGTH=256000
TRUST_REMOTE_CODE=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_sglang() {
    if ! command -v python -c "import sglang" &> /dev/null; then
        log_error "SGLang is not installed, please install SGLang first"
        echo "Install command: pip install sglang[all]"
        exit 1
    fi
    log_info "SGLang environment check passed"
}

check_model_path() {
    if [ ! -d "$MODEL_PATH" ] && [ ! -f "$MODEL_PATH" ]; then
        log_error "Model path does not exist: $MODEL_PATH"
        exit 1
    fi
    log_info "Model path check passed: $MODEL_PATH"
}

check_gpu() {
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi not found, please check NVIDIA driver"
        exit 1
    fi

    IFS=',' read -ra GPU_ARRAY <<< "$GPU_IDS"
    for gpu_id in "${GPU_ARRAY[@]}"; do
        if ! nvidia-smi -i "$gpu_id" &> /dev/null; then
            log_error "GPU $gpu_id does not exist or is not available"
            exit 1
        fi
    done
    log_info "GPU check passed, will use GPU: $GPU_IDS"
}

check_port() {
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
        log_error "Port $PORT is already in use"
        echo "Please change the port or stop the process using this port"
        exit 1
    fi
    log_info "Port $PORT is available"
}

start_server() {
    log_info "Starting SGLang server..."
    log_info "Configuration:"
    echo "  Model path: $MODEL_PATH"
    echo "  Port: $PORT"
    echo "  GPU: $GPU_IDS"
    echo "  Number of GPUs: $NUM_GPUS"
    echo "  Max concurrent requests: $MAX_RUNNING_REQUESTS"
    echo "  Context length: $CONTEXT_LENGTH"

    export CUDA_VISIBLE_DEVICES=$GPU_IDS

    CMD="python -m sglang.launch_server \
        --model-path $MODEL_PATH \
        --host $HOST \
        --port $PORT \
        --tp-size $NUM_GPUS \
        --dp $DP_SIZE\
        --max-running-requests $MAX_RUNNING_REQUESTS \
        --context-length $CONTEXT_LENGTH"

    if [ "$TRUST_REMOTE_CODE" = "true" ]; then
        CMD="$CMD --trust-remote-code"
    fi

    log_info "Executing command: $CMD"

    eval $CMD
}

cleanup() {
    log_warn "ending..."
    exit 0
}

trap cleanup SIGINT SIGTERM

main() {
    log_info "starting..."
    check_sglang
    check_model_path
    check_gpu
    check_port
    start_server
}
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi