#!/bin/bash

if [ $# -lt 3 ]; then
  echo "Usage: $0 <base_url> <api_key> <model>"
  echo "Example: $0 https://api.anthropic.com sk-xxx claude-sonnet-4-20250514"
  exit 1
fi

BASE_URL="$1"
API_KEY="$2"
MODEL="$3"

curl -s "${BASE_URL}/v1/messages" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "'"${MODEL}"'",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "今天北京天气怎么样？"}
    ],
    "tools": [
      {
        "name": "get_weather",
        "description": "获取指定城市的天气信息",
        "input_schema": {
          "type": "object",
          "properties": {
            "city": {
              "type": "string",
              "description": "城市名称"
            }
          },
          "required": ["city"]
        }
      }
    ]
  }' | jq
