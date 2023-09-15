#!/bin/bash
export LANG=zh_CN.UTF-8
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"
WarpNumberNodes=64 #预计需要节点数量
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

WARP_key(){
# 检查文件是否存在
if [ ! -e "wgcf" ]; then
  # 如果文件不存在，使用wget下载它
  wget "${proxygithub}https://raw.githubusercontent.com/cmliu/Warp2Clash/main/warp/wgcf" -O "wgcf"
  echo "wgcf 文件已下载。"
fi

chmod +x wgcf
rm -f wgcf-account.toml wgcf-profile.conf
echo | ./wgcf register
chmod +x wgcf-account.toml
# clear

#带有warpkey参数，将赋值第1参数为warpkey
if [ -n "$1" ]; then 
    warpkey="$1"
else
	read -rp "输入WARP账户许可证密钥 (26个字符):" warpkey
	until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
		echo "WARP账户许可证密钥格式输入错误，请重新输入！"
		read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
	done
fi

	if [[ -n $warpkey ]]; then
	  sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml
	  devicename="Clash.WARP"
	  echo "注册WARP+账户中, 如下方显示:400 Bad Request, 则使用WARP免费版账户"
	  if [[ -n $devicename ]]; then
		wgcf update --name $(echo $devicename | sed s/[[:space:]]/_/g) > /etc/wireguard/info.log 2>&1
	  else
		wgcf update
	  fi
	else
	  echo "未输入WARP账户许可证密钥，将使用WARP免费账户"
	fi
./wgcf generate

#clear
echo "Wgcf的WireGuard配置文件已生成成功！"
echo "下面是配置文件内容："
cat wgcf-profile.conf
}

#带有public-key参数，将赋值第1参数为private-key，将赋值第2参数为public-key
if [ -n "$2" ]; then 
	private_key="$1"
	public_key="$2"
	
	if [ -n "$3" ]; then
		ipv6="$3"
 	else
  		ipv6="null"
	fi

else
	WARP_key
	
	# 指定配置文件的路径
	config_file="wgcf-profile.conf"
	if [ ! -e "$config_file" ]; then
	  echo "$config_file 文件不存在，脚本终止。"
	  exit 1
	fi
	# 提取PrivateKey的值
	private_key=$(grep -oP 'PrivateKey\s*=\s*\K[^ ]+' "$config_file")
	# 提取PublicKey的值
	public_key=$(grep -oP 'PublicKey\s*=\s*\K[^ ]+' "$config_file")
	# 使用grep和awk查找和提取IPv6地址行
	ipv6=$(grep -E 'Address\s*=.*:[0-9a-fA-F:/]+' "$config_file" | awk -F ' = ' '{print $2}' | sed 's/\/128$//')

fi

# 输出提取的值
#echo "PrivateKey: $private_key"
#echo "PublicKey: $public_key"
#echo "IPv6 Address: $ipv6"
	
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

	if [ "$line_count" -gt "$((WarpNumberNodes + 1))" ]; then
	  # 使用 sed 删除行
	  sed -i "$((WarpNumberNodes + 2)),\$d" result.csv
	fi
else
  echo "测速结果不存在。"
  exit 1
fi

# 检查文件是否存在
if [ ! -e "WireguardConfig.py" ]; then
  # 如果文件不存在，使用wget下载它
  wget "${proxygithub}https://raw.githubusercontent.com/cmliu/Warp2Clash/main/WireguardConfig.py" -O "WireguardConfig.py"
  echo "WireguardConfig.py 文件已下载。"
fi

if [ "$ipv6" = "null" ]; then
    python3 WireguardConfig.py "$private_key" "$public_key"
else
    python3 WireguardConfig.py "$private_key" "$public_key" "$ipv6"
fi

file="clash_yaml.txt"
content_to_insert_home="proxies:"
content_to_insert_end="proxy-groups:
  - name: ⚖️ 负载均衡.Warp+
    type: load-balance
    url: http://www.google.com/generate_204
    interval: 300
    strategy: round-robin
    proxies:"

# 检测文件是否存在
if [ -e "$file" ]; then
  line_count=$(wc -l < "$file")
  if [ "$ipv6" = "null" ]; then
    processing_node_count=$((line_count / 12))
  else
    processing_node_count=$((line_count / 13))
  fi
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
rmxx "wgcf-account.toml"
rmxx "wgcf-profile.conf"
