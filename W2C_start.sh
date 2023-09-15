#!/bin/bash
export LANG=zh_CN.UTF-8
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"
###############################################################以下脚本内容，勿动#######################################################################

# 选择客户端 CPU 架构
archAffix(){
    case "$(uname -m)" in
        i386 | i686 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

update_gengxinzhi=0
apt_update() {
    if [ "$update_gengxinzhi" -eq 0 ]; then
        sudo apt update
        update_gengxinzhi=$((update_gengxinzhi + 1))
    fi
}

rmxx(){
if [ -e "$1" ]; then
  # 如果文件存在，删除它
  rm "$1"
  echo "$1 文件已清理。"
fi
}

apt_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 未安装，开始安装..."
        apt_update
        sudo apt install "$1" -y
        echo "$1 安装完成！"
    fi
}

apt_install wget

endpoint4(){
    n=0
    iplist=256
    while true; do
        temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 162.159.204.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
    done
    while true; do
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 162.159.204.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
            n=$(($n + 1))
        fi
    done

    # 将生成的 IP 段列表放到 ip.txt 里，待程序优选
    echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u > ip.txt

}

rmxx "ip.txt"

endpoint4

ulimit -n 102400

# 检查文件是否存在
if [ ! -e "warp" ]; then
  # 如果文件不存在，使用wget下载它
  wget "${proxygithub}https://raw.githubusercontent.com/cmliu/Warp2Clash/main/warp/warp-linux-$(archAffix)" -O "warp"
  echo "warp 文件已下载。"
fi

chmod +x warp && ./warp >/dev/null 2>&1

# 检查文件是否存在
if [ -e result.csv ]; then
  # 获取文件的行数
  line_count=$(wc -l < result.csv)

  if [ "$line_count" -gt 65 ]; then
    # 删除65行之后的内容
    sed -i '66,$d' result.csv
  fi
else
  echo "测速结果不存在。"
  exit 1
fi

python3 WireguardConfig.py

file="clash_yaml.txt"
content_to_insert_home="proxies:"
content_to_insert_end="proxy-groups:
  - name: 🇺🇸 美国线路.Warp+
    type: load-balance
    url: http://www.google.com/generate_204
    interval: 300
    strategy: round-robin
    proxies:"


# 检测文件是否存在
if [ -e "$file" ]; then
  line_count=$(wc -l < "$file")
  processing_node_count=$((line_count / 13))
  echo "Warp节点数量：$processing_node_count"
  sed -i "1i $content_to_insert_home" "$file"
  echo "$content_to_insert_end" >> "$file"

  for ((i=1; i<=processing_node_count; i++)); do
    node_name="Warp$(printf "%02d" $i)"
    echo "    - $node_name" >> "$file"
  done
  
else
  echo "$file 不存在"
fi

rmxx "ip.txt"
rmxx "result.csv"
