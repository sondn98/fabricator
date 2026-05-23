#!/bin/sh

until ollama ps >/dev/null 2>&1; do
  echo "Waiting for Ollama daemon to be ready..."
  sleep 5
done

for dir in /models/*; do
  # Skip if not a directory
  [ -d "$dir" ] || continue

  MODEL_NAME=$(basename "$dir")

  # Skip hidden directories
  case "$MODEL_NAME" in
    .* ) continue ;;
  esac

  # Skip if Modelfile does not exist
  [ -f "$dir/Modelfile" ] || continue

  # Create model only if it does not already exist
  if ! ollama list | awk 'NR>1 {print $1}' | grep -qx "$MODEL_NAME"; then
    echo "Creating model: $MODEL_NAME"
    ollama create "$MODEL_NAME" -f "$dir/Modelfile"
  else
    echo "Model already exists: $MODEL_NAME"
  fi
done