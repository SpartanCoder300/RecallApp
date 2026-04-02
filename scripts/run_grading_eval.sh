#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASET_PATH="$ROOT_DIR/docs/ai-grading-eval-dataset.json"
PREDICTIONS_OUT="/tmp/ai-grading-live-predictions.json"
LIMIT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset)
      shift
      DATASET_PATH="$1"
      ;;
    --predictions-out)
      shift
      PREDICTIONS_OUT="$1"
      ;;
    --limit)
      shift
      LIMIT_ARGS=(--limit "$1")
      ;;
    --help|-h)
      cat <<'EOF'
Usage:
  scripts/run_grading_eval.sh [options]

Options:
  --dataset <path>          Defaults to docs/ai-grading-eval-dataset.json
  --predictions-out <path>  Defaults to /tmp/ai-grading-live-predictions.json
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

export CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache
export SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache

RUNNER_EXECUTABLE="/tmp/run_grading_eval_exec"

swiftc \
  "$ROOT_DIR/RecallApp/Models/Rating.swift" \
  "$ROOT_DIR/RecallApp/Services/AnswerGradingSupport.swift" \
  "$ROOT_DIR/scripts/run_grading_eval_main.swift" \
  -o "$RUNNER_EXECUTABLE"

"$RUNNER_EXECUTABLE" \
  --dataset "$DATASET_PATH" \
  --predictions-out "$PREDICTIONS_OUT" \
  "${LIMIT_ARGS[@]}"

swift \
  "$ROOT_DIR/scripts/evaluate_grading.swift" \
  --dataset "$DATASET_PATH" \
  --predictions "$PREDICTIONS_OUT"
