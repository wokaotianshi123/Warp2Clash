#!/bin/bash
file="clash_yaml.txt"
content_to_insert_home="proxies:"
content_to_insert_end="proxy-groups:
- name: 🇺🇸 美国线路.Warp+
  type: load-balance
  url: http://www.google.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:"

echo 1 | ./warp-yxip.sh
python3 WireguardConfig.py

# 检测文件是否存在
if [ -e "$file" ]; then
  line_count=$(wc -l < "$file")
  # 计算处理节点数量
  processing_node_count=$((line_count / 13))
  echo "Warp节点数量：$processing_node_count"
  sed -i "1i $content_to_insert_home" "$file"
  echo "$content_to_insert_end" >> "$file"
  
    # 使用for循环插入内容
  for ((i=1; i<=processing_node_count; i++)); do
    node_name="Warp$(printf "%02d" $i)"  # 格式化节点名
    echo "  - $node_name" >> "$file"     # 插入节点名到文件
  done
  
else
  echo "$file 不存在"
fi
