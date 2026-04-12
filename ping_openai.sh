#!/bin/bash

if [ $# -lt 3 ]; then
  echo "Usage: $0 <base_url> <api_key> <model>"
  echo "Example: $0 https://api.openai.com/v1 sk-xxx gpt-4o-mini"
  exit 1
fi

BASE_URL="$1"
API_KEY="$2"
MODEL="$3"

curl -s "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "'"${MODEL}"'",
    "messages": [
      {"role": "user", "content": "今天北京天气怎么样？"}
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "description": "获取指定城市的天气信息",
          "parameters": {
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
      }
    ]
  }' | jq
