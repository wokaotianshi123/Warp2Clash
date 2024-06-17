#!/bin/bash
export LANG=zh_CN.UTF-8
proxygithub="https://gitjs.wokaotianshi123.cloudns.org/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"
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
  wget "${proxygithub}https://github.com/ViRb3/wgcf/releases/download/v2.2.19/wgcf_2.2.19_linux_$(archAffix)" -O "wgcf"
  echo "wgcf 文件已下载。"
fi

chmod +x wgcf
rm -f wgcf-account.toml wgcf-profile.conf
echo | ./wgcf register
chmod +x wgcf-account.toml
clear

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

clear
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

clear
# 输出提取的值
echo "PrivateKey: $private_key"
echo "PublicKey: $public_key"
echo "IPv6 Address: $ipv6"
	
endpoint6(){
    # 生成优选 WARP IPv6 Endpoint IP 段列表
    n=0
    iplist=100
    while true; do
        temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
        temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
        n=$(($n + 1))
        if [ $n -ge $iplist ]; then
            break
        fi
    done
    while true; do
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
        fi
        if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
            break
        else
            temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
        fi
    done

    # 将生成的 IP 段列表放到 ip.txt 里，待程序优选
    echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u > ip.txt

    # 启动优选程序
    endpointyx
}
rmxx "ip.txt"

endpoint6

ulimit -n 102400

# 检查文件是否存在
if [ ! -e "warp" ]; then
  # 如果文件不存在，使用wget下载它
  wget "${proxygithub}https://raw.githubusercontent.com/wokaotianshi123/Warp2Clash/main/warp/warp-linux-$(archAffix)" -O "warp"
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

# 检查文件是否存在，更新wireguard
if [  -e "WireguardConfig.py" ]; then
  rm "WireguardConfig.py"
  wget "${proxygithub}https://raw.githubusercontent.com/wokaotianshi123/Warp2Clash/main/WireguardConfig.py" -O "WireguardConfig.py"
  echo "wireguard设置文件已更新。"
else
  # 如果文件不存在，使用wget下载它
  wget "${proxygithub}https://raw.githubusercontent.com/wokaotianshi123/Warp2Clash/main/WireguardConfig.py" -O "WireguardConfig.py"
  echo "WireguardConfig.py 文件已下载。"
fi

if [ "$ipv6" = "null" ]; then
    python3 WireguardConfig.py "$private_key" "$public_key"
else
    python3 WireguardConfig.py "$private_key" "$public_key" "$ipv6"
fi

file="Warp2Clash.yaml"
content_to_insert_home="mixed-port: 7890
allow-lan: true
log-level: info
external-controller: 0.0.0.0:9090
dns:
  enabled: true
  listen: 0.0.0.0:1053
  ipv6: true
  default-nameserver:
    - 223.5.5.5
    - 114.114.114.114
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.lan'
    - '*.linksys.com'
    - '*.linksyssmartwifi.com'
    - swscan.apple.com
    - mesu.apple.com
    - '*.msftconnecttest.com'
    - '*.msftncsi.com'
    - time.*.com
    - time.*.gov
    - time.*.edu.cn
    - time.*.apple.com
    - time1.*.com
    - time2.*.com
    - time3.*.com
    - time4.*.com
    - time5.*.com
    - time6.*.com
    - time7.*.com
    - ntp.*.com
    - ntp.*.com
    - ntp1.*.com
    - ntp2.*.com
    - ntp3.*.com
    - ntp4.*.com
    - ntp5.*.com
    - ntp6.*.com
    - ntp7.*.com
    - '*.time.edu.cn'
    - '*.ntp.org.cn'
    - +.pool.ntp.org
    - time1.cloud.tencent.com
    - +.music.163.com
    - '*.126.net'
    - musicapi.taihe.com
    - music.taihe.com
    - songsearch.kugou.com
    - trackercdn.kugou.com
    - '*.kuwo.cn'
    - api-jooxtt.sanook.com
    - api.joox.com
    - joox.com
    - +.y.qq.com
    - +.music.tc.qq.com
    - aqqmusic.tc.qq.com
    - +.stream.qqmusic.qq.com
    - '*.xiami.com'
    - +.music.migu.cn
    - +.srv.nintendo.net
    - +.stun.playstation.net
    - xbox.*.microsoft.com
    - +.xboxlive.com
    - localhost.ptlogin2.qq.com
    - proxy.golang.org
    - stun.*.*
    - stun.*.*.*
    - '*.mcdn.bilivideo.cn'
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback-filter:
    geoip: false
    ipcidr:
      - 240.0.0.0/4
      - 0.0.0.0/32

proxies:"

content_to_insert_end="proxy-groups:
  - name: 🚀 节点选择
    type: select
    proxies:
      - ♻️ 自动选择
      - DIRECT
      - ⚖️ 负载均衡.Warp+
  - name: ♻️ 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    proxies:
      - ⚖️ 负载均衡.Warp+
  - name: 🌍 国外媒体
    type: select
    proxies:
      - 🚀 节点选择
      - ♻️ 自动选择
      - 🎯 全球直连
      - ⚖️ 负载均衡.Warp+
  - name: 📲 电报信息
    type: select
    proxies:
      - 🚀 节点选择
      - 🎯 全球直连
      - ⚖️ 负载均衡.Warp+
  - name: Ⓜ️ 微软服务
    type: select
    proxies:
      - 🎯 全球直连
      - 🚀 节点选择
      - ⚖️ 负载均衡.Warp+
  - name: 🍎 苹果服务
    type: select
    proxies:
      - 🚀 节点选择
      - 🎯 全球直连
      - ⚖️ 负载均衡.Warp+
  - name: 🎯 全球直连
    type: select
    proxies:
      - DIRECT
      - 🚀 节点选择
      - ♻️ 自动选择
  - name: 🛑 全球拦截
    type: select
    proxies:
      - REJECT
      - DIRECT
  - name: 🍃 应用净化
    type: select
    proxies:
      - REJECT
      - DIRECT
  - name: 🐟 漏网之鱼
    type: select
    proxies:
      - 🚀 节点选择
      - 🎯 全球直连
      - ♻️ 自动选择
      - ⚖️ 负载均衡.Warp+
  - name: ⚖️ 负载均衡.Warp+
    type: load-balance
    url: http://www.google.com/generate_204
    interval: 300
    strategy: round-robin
    proxies:"

rules="
rules:
# 本地/局域网地址
# 参考：https://en.wikipedia.org/wiki/Reserved_IP_addresses
# ACL4SSR标志 如没有，代表不是用ACL4SSR规则
# 本地/局域网地址
# Router managed 路由器管理域名
  - DOMAIN-SUFFIX,acl4.ssr,🎯 全球直连
  - DOMAIN-SUFFIX,ip6-localhost,🎯 全球直连
  - DOMAIN-SUFFIX,ip6-loopback,🎯 全球直连
  - DOMAIN-SUFFIX,lan,🎯 全球直连
  - DOMAIN-SUFFIX,local,🎯 全球直连
  - DOMAIN-SUFFIX,localhost,🎯 全球直连
  - IP-CIDR,10.0.0.0/8,🎯 全球直连,no-resolve
  - IP-CIDR,100.64.0.0/10,🎯 全球直连,no-resolve
  - IP-CIDR,127.0.0.0/8,🎯 全球直连,no-resolve
  - IP-CIDR,172.16.0.0/12,🎯 全球直连,no-resolve
  - IP-CIDR,192.168.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,198.18.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,224.0.0.0/4,🎯 全球直连,no-resolve
  - IP-CIDR6,::1/128,🎯 全球直连,no-resolve
  - IP-CIDR6,fc00::/7,🎯 全球直连,no-resolve
  - IP-CIDR6,fe80::/10,🎯 全球直连,no-resolve
  - IP-CIDR6,fd00::/8,🎯 全球直连,no-resolve
  - DOMAIN,instant.arubanetworks.com,🎯 全球直连
  - DOMAIN,setmeup.arubanetworks.com,🎯 全球直连
  - DOMAIN,router.asus.com,🎯 全球直连
  - DOMAIN-SUFFIX,hiwifi.com,🎯 全球直连
  - DOMAIN-SUFFIX,leike.cc,🎯 全球直连
  - DOMAIN-SUFFIX,miwifi.com,🎯 全球直连
  - DOMAIN-SUFFIX,my.router,🎯 全球直连
  - DOMAIN-SUFFIX,p.to,🎯 全球直连
  - DOMAIN-SUFFIX,peiluyou.com,🎯 全球直连
  - DOMAIN-SUFFIX,phicomm.me,🎯 全球直连
  - DOMAIN-SUFFIX,router.ctc,🎯 全球直连
  - DOMAIN-SUFFIX,routerlogin.com,🎯 全球直连
  - DOMAIN-SUFFIX,tendawifi.com,🎯 全球直连
  - DOMAIN-SUFFIX,zte.home,🎯 全球直连
  - DOMAIN-SUFFIX,tplogin.cn,🎯 全球直连
# 本碎片只包含常见广告关键字、广告联盟。无副作用，放心使用
# 广告关键词
# 广告联盟-国内****************
# 广告联盟-国外****************
# 垃圾站点****************
# 运营商广告****************
  - DOMAIN-KEYWORD,admarvel,🛑 全球拦截
  - DOMAIN-KEYWORD,admaster,🛑 全球拦截
  - DOMAIN-KEYWORD,adsage,🛑 全球拦截
  - DOMAIN-KEYWORD,adsensor,🛑 全球拦截
  - DOMAIN-KEYWORD,adservice,🛑 全球拦截
  - DOMAIN-KEYWORD,adsmogo,🛑 全球拦截
  - DOMAIN-KEYWORD,adsrvmedia,🛑 全球拦截
  - DOMAIN-KEYWORD,adsserving,🛑 全球拦截
  - DOMAIN-KEYWORD,adsystem,🛑 全球拦截
  - DOMAIN-KEYWORD,adwords,🛑 全球拦截
  - DOMAIN-KEYWORD,analysis,🛑 全球拦截
  - DOMAIN-KEYWORD,applovin,🛑 全球拦截
  - DOMAIN-KEYWORD,appsflyer,🛑 全球拦截
  - DOMAIN-KEYWORD,domob,🛑 全球拦截
  - DOMAIN-KEYWORD,duomeng,🛑 全球拦截
  - DOMAIN-KEYWORD,dwtrack,🛑 全球拦截
  - DOMAIN-KEYWORD,guanggao,🛑 全球拦截
  - DOMAIN-KEYWORD,omgmta,🛑 全球拦截
  - DOMAIN-KEYWORD,omniture,🛑 全球拦截
  - DOMAIN-KEYWORD,openx,🛑 全球拦截
  - DOMAIN-KEYWORD,partnerad,🛑 全球拦截
  - DOMAIN-KEYWORD,pingfore,🛑 全球拦截
  - DOMAIN-KEYWORD,socdm,🛑 全球拦截
  - DOMAIN-KEYWORD,supersonicads,🛑 全球拦截
  - DOMAIN-KEYWORD,usage,🛑 全球拦截
  - DOMAIN-KEYWORD,wlmonitor,🛑 全球拦截
  - DOMAIN-KEYWORD,zjtoolbar,🛑 全球拦截
  - DOMAIN-SUFFIX,09mk.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,100peng.com,🛑 全球拦截
  - DOMAIN-SUFFIX,114la.com,🛑 全球拦截
  - DOMAIN-SUFFIX,123juzi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,138lm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,17un.com,🛑 全球拦截
  - DOMAIN-SUFFIX,2cnt.net,🛑 全球拦截
  - DOMAIN-SUFFIX,3gmimo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,3xx.vip,🛑 全球拦截
  - DOMAIN-SUFFIX,51.la,🛑 全球拦截
  - DOMAIN-SUFFIX,51taifu.com,🛑 全球拦截
  - DOMAIN-SUFFIX,51yes.com,🛑 全球拦截
  - DOMAIN-SUFFIX,600ad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,6dad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,70e.com,🛑 全球拦截
  - DOMAIN-SUFFIX,86.cc,🛑 全球拦截
  - DOMAIN-SUFFIX,8le8le.com,🛑 全球拦截
  - DOMAIN-SUFFIX,8ox.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,95558000.com,🛑 全球拦截
  - DOMAIN-SUFFIX,99click.com,🛑 全球拦截
  - DOMAIN-SUFFIX,99youmeng.com,🛑 全球拦截
  - DOMAIN-SUFFIX,a3p4.net,🛑 全球拦截
  - DOMAIN-SUFFIX,acs86.com,🛑 全球拦截
  - DOMAIN-SUFFIX,acxiom-online.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-brix.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-delivery.net,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-locus.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-plus.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ad7.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adadapted.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adadvisor.net,🛑 全球拦截
  - DOMAIN-SUFFIX,adap.tv,🛑 全球拦截
  - DOMAIN-SUFFIX,adbana.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adchina.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adcome.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ader.mobi,🛑 全球拦截
  - DOMAIN-SUFFIX,adform.net,🛑 全球拦截
  - DOMAIN-SUFFIX,adfuture.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adhouyi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adinfuse.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adirects.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adjust.io,🛑 全球拦截
  - DOMAIN-SUFFIX,adkmob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adlive.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adlocus.com,🛑 全球拦截
  - DOMAIN-SUFFIX,admaji.com,🛑 全球拦截
  - DOMAIN-SUFFIX,admin6.com,🛑 全球拦截
  - DOMAIN-SUFFIX,admon.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adnyg.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adpolestar.net,🛑 全球拦截
  - DOMAIN-SUFFIX,adpro.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adpush.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adquan.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adreal.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ads8.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsame.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsmogo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsmogo.org,🛑 全球拦截
  - DOMAIN-SUFFIX,adsunflower.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsunion.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adtrk.me,🛑 全球拦截
  - DOMAIN-SUFFIX,adups.com,🛑 全球拦截
  - DOMAIN-SUFFIX,aduu.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,advertising.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adview.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,advmob.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,adwetec.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adwhirl.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adwo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adxmi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adyun.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adzerk.net,🛑 全球拦截
  - DOMAIN-SUFFIX,agrant.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,agrantsem.com,🛑 全球拦截
  - DOMAIN-SUFFIX,aihaoduo.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ajapk.com,🛑 全球拦截
  - DOMAIN-SUFFIX,allyes.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,allyes.com,🛑 全球拦截
  - DOMAIN-SUFFIX,amazon-adsystem.com,🛑 全球拦截
  - DOMAIN-SUFFIX,analysys.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,angsrvr.com,🛑 全球拦截
  - DOMAIN-SUFFIX,anquan.org,🛑 全球拦截
  - DOMAIN-SUFFIX,anysdk.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appadhoc.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appboy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appdriver.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,appjiagu.com,🛑 全球拦截
  - DOMAIN-SUFFIX,applifier.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appsflyer.com,🛑 全球拦截
  - DOMAIN-SUFFIX,atdmt.com,🛑 全球拦截
  - DOMAIN-SUFFIX,baifendian.com,🛑 全球拦截
  - DOMAIN-SUFFIX,banmamedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,baoyatu.cc,🛑 全球拦截
  - DOMAIN-SUFFIX,baycode.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,bayimob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,behe.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bfshan.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,biddingos.com,🛑 全球拦截
  - DOMAIN-SUFFIX,biddingx.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bjvvqu.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,bjxiaohua.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bloggerads.net,🛑 全球拦截
  - DOMAIN-SUFFIX,branch.io,🛑 全球拦截
  - DOMAIN-SUFFIX,bsdev.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,bshare.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,btyou.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bugtags.com,🛑 全球拦截
  - DOMAIN-SUFFIX,buysellads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,c0563.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cacafly.com,🛑 全球拦截
  - DOMAIN-SUFFIX,casee.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,cdnmaster.com,🛑 全球拦截
  - DOMAIN-SUFFIX,chance-ad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,chanet.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,chartbeat.com,🛑 全球拦截
  - DOMAIN-SUFFIX,chartboost.com,🛑 全球拦截
  - DOMAIN-SUFFIX,chengadx.com,🛑 全球拦截
  - DOMAIN-SUFFIX,chmae.com,🛑 全球拦截
  - DOMAIN-SUFFIX,clickadu.com,🛑 全球拦截
  - DOMAIN-SUFFIX,clicki.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,clicktracks.com,🛑 全球拦截
  - DOMAIN-SUFFIX,clickzs.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cloudmobi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,cmcore.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cnxad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cnzz.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cnzzlink.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cocounion.com,🛑 全球拦截
  - DOMAIN-SUFFIX,coocaatv.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cooguo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,coolguang.com,🛑 全球拦截
  - DOMAIN-SUFFIX,coremetrics.com,🛑 全球拦截
  - DOMAIN-SUFFIX,cpmchina.co,🛑 全球拦截
  - DOMAIN-SUFFIX,cpx24.com,🛑 全球拦截
  - DOMAIN-SUFFIX,crasheye.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,crosschannel.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ctrmi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,customer-security.online,🛑 全球拦截
  - DOMAIN-SUFFIX,daoyoudao.com,🛑 全球拦截
  - DOMAIN-SUFFIX,datouniao.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ddapp.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,dianjoy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,dianru.com,🛑 全球拦截
  - DOMAIN-SUFFIX,disqusads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,domob.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,domob.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,domob.org,🛑 全球拦截
  - DOMAIN-SUFFIX,dotmore.com.tw,🛑 全球拦截
  - DOMAIN-SUFFIX,doubleverify.com,🛑 全球拦截
  - DOMAIN-SUFFIX,doudouguo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,doumob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,duanat.com,🛑 全球拦截
  - DOMAIN-SUFFIX,duiba.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,duomeng.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,dxpmedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,edigitalsurvey.com,🛑 全球拦截
  - DOMAIN-SUFFIX,eduancm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,emarbox.com,🛑 全球拦截
  - DOMAIN-SUFFIX,exosrv.com,🛑 全球拦截
  - DOMAIN-SUFFIX,fancyapi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,feitian001.com,🛑 全球拦截
  - DOMAIN-SUFFIX,feixin2.com,🛑 全球拦截
  - DOMAIN-SUFFIX,flashtalking.com,🛑 全球拦截
  - DOMAIN-SUFFIX,fraudmetrix.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,g1.tagtic.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,gentags.net,🛑 全球拦截
  - DOMAIN-SUFFIX,gepush.com,🛑 全球拦截
  - DOMAIN-SUFFIX,getui.com,🛑 全球拦截
  - DOMAIN-SUFFIX,glispa.com,🛑 全球拦截
  - DOMAIN-SUFFIX,go-mpulse,🛑 全球拦截
  - DOMAIN-SUFFIX,go-mpulse.net,🛑 全球拦截
  - DOMAIN-SUFFIX,godloveme.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,gridsum.com,🛑 全球拦截
  - DOMAIN-SUFFIX,gridsumdissector.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,gridsumdissector.com,🛑 全球拦截
  - DOMAIN-SUFFIX,growingio.com,🛑 全球拦截
  - DOMAIN-SUFFIX,guohead.com,🛑 全球拦截
  - DOMAIN-SUFFIX,guomob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,haoghost.com,🛑 全球拦截
  - DOMAIN-SUFFIX,hivecn.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,hypers.com,🛑 全球拦截
  - DOMAIN-SUFFIX,icast.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,igexin.com,🛑 全球拦截
  - DOMAIN-SUFFIX,il8r.com,🛑 全球拦截
  - DOMAIN-SUFFIX,imageter.com,🛑 全球拦截
  - DOMAIN-SUFFIX,immob.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,inad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,inmobi.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,inmobi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,inmobicdn.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,inmobicdn.net,🛑 全球拦截
  - DOMAIN-SUFFIX,innity.com,🛑 全球拦截
  - DOMAIN-SUFFIX,instabug.com,🛑 全球拦截
  - DOMAIN-SUFFIX,intely.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,iperceptions.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ipinyou.com,🛑 全球拦截
  - DOMAIN-SUFFIX,irs01.com,🛑 全球拦截
  - DOMAIN-SUFFIX,irs01.net,🛑 全球拦截
  - DOMAIN-SUFFIX,irs09.com,🛑 全球拦截
  - DOMAIN-SUFFIX,istreamsche.com,🛑 全球拦截
  - DOMAIN-SUFFIX,jesgoo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,jiaeasy.net,🛑 全球拦截
  - DOMAIN-SUFFIX,jiguang.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,jimdo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,jisucn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,jmgehn.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,jpush.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,jusha.com,🛑 全球拦截
  - DOMAIN-SUFFIX,juzi.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,juzilm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,kejet.com,🛑 全球拦截
  - DOMAIN-SUFFIX,kejet.net,🛑 全球拦截
  - DOMAIN-SUFFIX,keydot.net,🛑 全球拦截
  - DOMAIN-SUFFIX,keyrun.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,kmd365.com,🛑 全球拦截
  - DOMAIN-SUFFIX,krux.net,🛑 全球拦截
  - DOMAIN-SUFFIX,lnk0.com,🛑 全球拦截
  - DOMAIN-SUFFIX,lnk8.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,localytics.com,🛑 全球拦截
  - DOMAIN-SUFFIX,lomark.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,lotuseed.com,🛑 全球拦截
  - DOMAIN-SUFFIX,lrswl.com,🛑 全球拦截
  - DOMAIN-SUFFIX,lufax.com,🛑 全球拦截
  - DOMAIN-SUFFIX,madhouse.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,madmini.com,🛑 全球拦截
  - DOMAIN-SUFFIX,madserving.com,🛑 全球拦截
  - DOMAIN-SUFFIX,magicwindow.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,mathtag.com,🛑 全球拦截
  - DOMAIN-SUFFIX,maysunmedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mbai.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,mediaplex.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mediav.com,🛑 全球拦截
  - DOMAIN-SUFFIX,megajoy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mgogo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,miaozhen.com,🛑 全球拦截
  - DOMAIN-SUFFIX,microad-cn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,miidi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,mijifen.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mixpanel.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mjmobi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mng-ads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,moad.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,moatads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobaders.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobclix.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobgi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobisage.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,mobvista.com,🛑 全球拦截
  - DOMAIN-SUFFIX,moogos.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mopub.com,🛑 全球拦截
  - DOMAIN-SUFFIX,moquanad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mpush.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,mxpnl.com,🛑 全球拦截
  - DOMAIN-SUFFIX,myhug.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,mzy2014.com,🛑 全球拦截
  - DOMAIN-SUFFIX,networkbench.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ninebox.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ntalker.com,🛑 全球拦截
  - DOMAIN-SUFFIX,nylalobghyhirgh.com,🛑 全球拦截
  - DOMAIN-SUFFIX,o2omobi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,oadz.com,🛑 全球拦截
  - DOMAIN-SUFFIX,oneapm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,onetad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,optaim.com,🛑 全球拦截
  - DOMAIN-SUFFIX,optimix.asia,🛑 全球拦截
  - DOMAIN-SUFFIX,optimix.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,optimizelyapis.com,🛑 全球拦截
  - DOMAIN-SUFFIX,overture.com,🛑 全球拦截
  - DOMAIN-SUFFIX,p0y.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,pagechoice.net,🛑 全球拦截
  - DOMAIN-SUFFIX,pingdom.net,🛑 全球拦截
  - DOMAIN-SUFFIX,plugrush.com,🛑 全球拦截
  - DOMAIN-SUFFIX,popin.cc,🛑 全球拦截
  - DOMAIN-SUFFIX,pro.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,publicidad.net,🛑 全球拦截
  - DOMAIN-SUFFIX,publicidad.tv,🛑 全球拦截
  - DOMAIN-SUFFIX,pubmatic.com,🛑 全球拦截
  - DOMAIN-SUFFIX,pubnub.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qcl777.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qiyou.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qtmojo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,quantcount.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qucaigg.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qumi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,qxxys.com,🛑 全球拦截
  - DOMAIN-SUFFIX,reachmax.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,responsys.net,🛑 全球拦截
  - DOMAIN-SUFFIX,revsci.net,🛑 全球拦截
  - DOMAIN-SUFFIX,rlcdn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,rtbasia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sanya1.com,🛑 全球拦截
  - DOMAIN-SUFFIX,scupio.com,🛑 全球拦截
  - DOMAIN-SUFFIX,serving-sys.com,🛑 全球拦截
  - DOMAIN-SUFFIX,shuiguo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,shuzilm.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,similarweb.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sitemeter.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sitescout.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sitetag.us,🛑 全球拦截
  - DOMAIN-SUFFIX,smartmad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,social-touch.com,🛑 全球拦截
  - DOMAIN-SUFFIX,somecoding.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sponsorpay.com,🛑 全球拦截
  - DOMAIN-SUFFIX,stargame.com,🛑 全球拦截
  - DOMAIN-SUFFIX,stg8.com,🛑 全球拦截
  - DOMAIN-SUFFIX,switchadhub.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sycbbs.com,🛑 全球拦截
  - DOMAIN-SUFFIX,synacast.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sysdig.com,🛑 全球拦截
  - DOMAIN-SUFFIX,talkingdata.com,🛑 全球拦截
  - DOMAIN-SUFFIX,talkingdata.net,🛑 全球拦截
  - DOMAIN-SUFFIX,tansuotv.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tanv.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tanx.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tapjoy.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,th7.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,thoughtleadr.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tianmidian.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tiqcdn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,touclick.com,🛑 全球拦截
  - DOMAIN-SUFFIX,trafficjam.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,trafficmp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tuia.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ueadlian.com,🛑 全球拦截
  - DOMAIN-SUFFIX,uerzyr.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,ugdtimg.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ugvip.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ujian.cc,🛑 全球拦截
  - DOMAIN-SUFFIX,ukeiae.com,🛑 全球拦截
  - DOMAIN-SUFFIX,umeng.co,🛑 全球拦截
  - DOMAIN-SUFFIX,umeng.com,🛑 全球拦截
  - DOMAIN-SUFFIX,umtrack.com,🛑 全球拦截
  - DOMAIN-SUFFIX,unimhk.com,🛑 全球拦截
  - DOMAIN-SUFFIX,union-wifi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,union001.com,🛑 全球拦截
  - DOMAIN-SUFFIX,unionsy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,unlitui.com,🛑 全球拦截
  - DOMAIN-SUFFIX,uri6.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ushaqi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,usingde.com,🛑 全球拦截
  - DOMAIN-SUFFIX,uuzu.com,🛑 全球拦截
  - DOMAIN-SUFFIX,uyunad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,vamaker.com,🛑 全球拦截
  - DOMAIN-SUFFIX,vlion.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,voiceads.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,voiceads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,vpon.com,🛑 全球拦截
  - DOMAIN-SUFFIX,vungle.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,vungle.com,🛑 全球拦截
  - DOMAIN-SUFFIX,waps.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,wapx.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,webterren.com,🛑 全球拦截
  - DOMAIN-SUFFIX,whpxy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,winads.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,winasdaq.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wiyun.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wooboo.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,wqmobile.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wrating.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wumii.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,xcy8.com,🛑 全球拦截
  - DOMAIN-SUFFIX,xdrig.com,🛑 全球拦截
  - DOMAIN-SUFFIX,xiaozhen.com,🛑 全球拦截
  - DOMAIN-SUFFIX,xibao100.com,🛑 全球拦截
  - DOMAIN-SUFFIX,xtgreat.com,🛑 全球拦截
  - DOMAIN-SUFFIX,xy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yandui.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yigao.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yijifen.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yinooo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yiqifa.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yiwk.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ylunion.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ymapp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ymcdn.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,yongyuelm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yooli.com,🛑 全球拦截
  - DOMAIN-SUFFIX,youmi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,youxiaoad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yoyi.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,yoyi.tv,🛑 全球拦截
  - DOMAIN-SUFFIX,yrxmr.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ysjwj.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yunjiasu.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yunpifu.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,zampdsp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zamplus.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zcdsp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zhidian3g.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,zhiziyun.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zhjfad.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zqzxz.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zzsx8.com,🛑 全球拦截
  - DOMAIN-SUFFIX,acuityplatform.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-stir.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad-survey.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ad4game.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adcloud.jp,🛑 全球拦截
  - DOMAIN-SUFFIX,adcolony.com,🛑 全球拦截
  - DOMAIN-SUFFIX,addthis.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adfurikun.jp,🛑 全球拦截
  - DOMAIN-SUFFIX,adhigh.net,🛑 全球拦截
  - DOMAIN-SUFFIX,adhood.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adinall.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adition.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adk2x.com,🛑 全球拦截
  - DOMAIN-SUFFIX,admarket.mobi,🛑 全球拦截
  - DOMAIN-SUFFIX,admarvel.com,🛑 全球拦截
  - DOMAIN-SUFFIX,admedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adnxs.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adotmob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adperium.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adriver.ru,🛑 全球拦截
  - DOMAIN-SUFFIX,adroll.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsco.re,🛑 全球拦截
  - DOMAIN-SUFFIX,adservice.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adsrvr.org,🛑 全球拦截
  - DOMAIN-SUFFIX,adsymptotic.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adtaily.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adtech.de,🛑 全球拦截
  - DOMAIN-SUFFIX,adtechjp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,adtechus.com,🛑 全球拦截
  - DOMAIN-SUFFIX,airpush.com,🛑 全球拦截
  - DOMAIN-SUFFIX,am15.net,🛑 全球拦截
  - DOMAIN-SUFFIX,amobee.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appier.net,🛑 全球拦截
  - DOMAIN-SUFFIX,applift.com,🛑 全球拦截
  - DOMAIN-SUFFIX,apsalar.com,🛑 全球拦截
  - DOMAIN-SUFFIX,atas.io,🛑 全球拦截
  - DOMAIN-SUFFIX,awempire.com,🛑 全球拦截
  - DOMAIN-SUFFIX,axonix.com,🛑 全球拦截
  - DOMAIN-SUFFIX,beintoo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bepolite.eu,🛑 全球拦截
  - DOMAIN-SUFFIX,bidtheatre.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bidvertiser.com,🛑 全球拦截
  - DOMAIN-SUFFIX,blismedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,brucelead.com,🛑 全球拦截
  - DOMAIN-SUFFIX,bttrack.com,🛑 全球拦截
  - DOMAIN-SUFFIX,casalemedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,celtra.com,🛑 全球拦截
  - DOMAIN-SUFFIX,channeladvisor.com,🛑 全球拦截
  - DOMAIN-SUFFIX,connexity.net,🛑 全球拦截
  - DOMAIN-SUFFIX,criteo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,criteo.net,🛑 全球拦截
  - DOMAIN-SUFFIX,csbew.com,🛑 全球拦截
  - DOMAIN-SUFFIX,directrev.com,🛑 全球拦截
  - DOMAIN-SUFFIX,dumedia.ru,🛑 全球拦截
  - DOMAIN-SUFFIX,effectivemeasure.com,🛑 全球拦截
  - DOMAIN-SUFFIX,effectivemeasure.net,🛑 全球拦截
  - DOMAIN-SUFFIX,eqads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,everesttech.net,🛑 全球拦截
  - DOMAIN-SUFFIX,exoclick.com,🛑 全球拦截
  - DOMAIN-SUFFIX,extend.tv,🛑 全球拦截
  - DOMAIN-SUFFIX,eyereturn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,fastapi.net,🛑 全球拦截
  - DOMAIN-SUFFIX,fastclick.com,🛑 全球拦截
  - DOMAIN-SUFFIX,fastclick.net,🛑 全球拦截
  - DOMAIN-SUFFIX,flurry.com,🛑 全球拦截
  - DOMAIN-SUFFIX,gosquared.com,🛑 全球拦截
  - DOMAIN-SUFFIX,gtags.net,🛑 全球拦截
  - DOMAIN-SUFFIX,heyzap.com,🛑 全球拦截
  - DOMAIN-SUFFIX,histats.com,🛑 全球拦截
  - DOMAIN-SUFFIX,hitslink.com,🛑 全球拦截
  - DOMAIN-SUFFIX,hot-mob.com,🛑 全球拦截
  - DOMAIN-SUFFIX,hyperpromote.com,🛑 全球拦截
  - DOMAIN-SUFFIX,i-mobile.co.jp,🛑 全球拦截
  - DOMAIN-SUFFIX,imrworldwide.com,🛑 全球拦截
  - DOMAIN-SUFFIX,inmobi.com,🛑 全球拦截
  - DOMAIN-SUFFIX,inner-active.mobi,🛑 全球拦截
  - DOMAIN-SUFFIX,intentiq.com,🛑 全球拦截
  - DOMAIN-SUFFIX,inter1ads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ipredictive.com,🛑 全球拦截
  - DOMAIN-SUFFIX,ironsrc.com,🛑 全球拦截
  - DOMAIN-SUFFIX,iskyworker.com,🛑 全球拦截
  - DOMAIN-SUFFIX,jizzads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,juicyads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,kochava.com,🛑 全球拦截
  - DOMAIN-SUFFIX,leadbolt.com,🛑 全球拦截
  - DOMAIN-SUFFIX,leadbolt.net,🛑 全球拦截
  - DOMAIN-SUFFIX,leadboltads.net,🛑 全球拦截
  - DOMAIN-SUFFIX,leadboltapps.net,🛑 全球拦截
  - DOMAIN-SUFFIX,leadboltmobile.net,🛑 全球拦截
  - DOMAIN-SUFFIX,lenzmx.com,🛑 全球拦截
  - DOMAIN-SUFFIX,liveadvert.com,🛑 全球拦截
  - DOMAIN-SUFFIX,marketgid.com,🛑 全球拦截
  - DOMAIN-SUFFIX,marketo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mdotm.com,🛑 全球拦截
  - DOMAIN-SUFFIX,medialytics.com,🛑 全球拦截
  - DOMAIN-SUFFIX,medialytics.io,🛑 全球拦截
  - DOMAIN-SUFFIX,meetrics.com,🛑 全球拦截
  - DOMAIN-SUFFIX,meetrics.net,🛑 全球拦截
  - DOMAIN-SUFFIX,mgid.com,🛑 全球拦截
  - DOMAIN-SUFFIX,millennialmedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobadme.jp,🛑 全球拦截
  - DOMAIN-SUFFIX,mobfox.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobileadtrading.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mobilityware.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mojiva.com,🛑 全球拦截
  - DOMAIN-SUFFIX,mookie1.com,🛑 全球拦截
  - DOMAIN-SUFFIX,msads.net,🛑 全球拦截
  - DOMAIN-SUFFIX,mydas.mobi,🛑 全球拦截
  - DOMAIN-SUFFIX,nend.net,🛑 全球拦截
  - DOMAIN-SUFFIX,netshelter.net,🛑 全球拦截
  - DOMAIN-SUFFIX,nexage.com,🛑 全球拦截
  - DOMAIN-SUFFIX,owneriq.net,🛑 全球拦截
  - DOMAIN-SUFFIX,pixels.asia,🛑 全球拦截
  - DOMAIN-SUFFIX,plista.com,🛑 全球拦截
  - DOMAIN-SUFFIX,popads.net,🛑 全球拦截
  - DOMAIN-SUFFIX,powerlinks.com,🛑 全球拦截
  - DOMAIN-SUFFIX,propellerads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,quantserve.com,🛑 全球拦截
  - DOMAIN-SUFFIX,rayjump.com,🛑 全球拦截
  - DOMAIN-SUFFIX,revdepo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,rubiconproject.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sape.ru,🛑 全球拦截
  - DOMAIN-SUFFIX,scorecardresearch.com,🛑 全球拦截
  - DOMAIN-SUFFIX,segment.com,🛑 全球拦截
  - DOMAIN-SUFFIX,serving-sys.com,🛑 全球拦截
  - DOMAIN-SUFFIX,sharethis.com,🛑 全球拦截
  - DOMAIN-SUFFIX,smaato.com,🛑 全球拦截
  - DOMAIN-SUFFIX,smaato.net,🛑 全球拦截
  - DOMAIN-SUFFIX,smartadserver.com,🛑 全球拦截
  - DOMAIN-SUFFIX,smartnews-ads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,startapp.com,🛑 全球拦截
  - DOMAIN-SUFFIX,startappexchange.com,🛑 全球拦截
  - DOMAIN-SUFFIX,statcounter.com,🛑 全球拦截
  - DOMAIN-SUFFIX,steelhousemedia.com,🛑 全球拦截
  - DOMAIN-SUFFIX,stickyadstv.com,🛑 全球拦截
  - DOMAIN-SUFFIX,supersonic.com,🛑 全球拦截
  - DOMAIN-SUFFIX,taboola.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tapjoy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,tapjoyads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,trafficjunky.com,🛑 全球拦截
  - DOMAIN-SUFFIX,trafficjunky.net,🛑 全球拦截
  - DOMAIN-SUFFIX,tribalfusion.com,🛑 全球拦截
  - DOMAIN-SUFFIX,turn.com,🛑 全球拦截
  - DOMAIN-SUFFIX,uberads.com,🛑 全球拦截
  - DOMAIN-SUFFIX,vidoomy.com,🛑 全球拦截
  - DOMAIN-SUFFIX,viglink.com,🛑 全球拦截
  - DOMAIN-SUFFIX,voicefive.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wedolook.com,🛑 全球拦截
  - DOMAIN-SUFFIX,yadro.ru,🛑 全球拦截
  - DOMAIN-SUFFIX,yengo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zedo.com,🛑 全球拦截
  - DOMAIN-SUFFIX,zemanta.com,🛑 全球拦截
  - DOMAIN-SUFFIX,11h5.com,🛑 全球拦截
  - DOMAIN-SUFFIX,1kxun.mobi,🛑 全球拦截
  - DOMAIN-SUFFIX,26zsd.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,519397.com,🛑 全球拦截
  - DOMAIN-SUFFIX,626uc.com,🛑 全球拦截
  - DOMAIN-SUFFIX,915.com,🛑 全球拦截
  - DOMAIN-SUFFIX,appget.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,appuu.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,coinhive.com,🛑 全球拦截
  - DOMAIN-SUFFIX,huodonghezi.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,vcbn65.xyz,🛑 全球拦截
  - DOMAIN-SUFFIX,wanfeng1.com,🛑 全球拦截
  - DOMAIN-SUFFIX,wep016.top,🛑 全球拦截
  - DOMAIN-SUFFIX,win-stock.com.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,zantainet.com,🛑 全球拦截
  - DOMAIN-SUFFIX,dh54wf.xyz,🛑 全球拦截
  - DOMAIN-SUFFIX,g2q3e.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,114so.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,go.10086.cn,🛑 全球拦截
  - DOMAIN-SUFFIX,hivedata.cc,🛑 全球拦截
  - DOMAIN-SUFFIX,navi.gd.chinamobile.com,🛑 全球拦截
# 包含常用应用的各种去广告规则。
# 可能有轻微副作用，可放心使用。（如果网站功能和广告冲突，会删掉去广告规则）
# 163
# 17173
# 178
# 2345
# 360
# 58
# Alibaba
# Adobe
# Apple
# AutoHome
# Baidu
# Book-app 起点 掌阅 书旗 宜搜
# ByteDance 头条抖音
# Dangdang
# Duomi
# Facebook
# Fang
# Google
# JD
# Kugou
# Kuwo
# Meizu flyme 魅族
# Meitu
# Miui 小米
# Moji
# Qingting.fm
# QQ
# RenRen
# Sina
# Sougou
# Teleplus
# Twitter
# UC ali
# Weifeng
# WPS Office
# Wi-Fi key
# Ximalaya 喜马拉雅
# Xunlei 迅雷app&看看
# Yahoo
# Zhihu
# Ads in Video apps 下面都是 ********************
# 6间房
# Baofeng 暴风影音
# Douyu
# Fenghuang 凤凰TV
# Funshion 风行
# iqiyi PPS 爱奇艺
# Ku6 酷6
# LeTV 乐视
# MGTV 芒果TV
# Sohu 搜狐
# PPTV、PPLive
# QQ Live
# Youku & Tudou
# Youtube
# Others ads in Video apps
# Ads in Video apps end 上面都是 ********************
# 常用网站广告
  - DOMAIN-SUFFIX,a.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,adgeo.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.126.net,🍃 应用净化
  - DOMAIN-SUFFIX,bobo.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,c.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,clkservice.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,conv.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,dsp-impr2.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,dsp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,fa.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,g.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,g1.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,gb.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,gorgon.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,haitaoad.nosdn.127.net,🍃 应用净化
  - DOMAIN-SUFFIX,iadmatvideo.nosdn.127.net,🍃 应用净化
  - DOMAIN-SUFFIX,img1.126.net,🍃 应用净化
  - DOMAIN-SUFFIX,img2.126.net,🍃 应用净化
  - DOMAIN-SUFFIX,ir.mail.126.com,🍃 应用净化
  - DOMAIN-SUFFIX,ir.mail.yeah.net,🍃 应用净化
  - DOMAIN-SUFFIX,mimg.126.net,🍃 应用净化
  - DOMAIN-SUFFIX,nc004x.corp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,nc045x.corp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,nex.corp.163.com,🍃 应用净化
  - DOMAIN-SUFFIX,oimagea2.ydstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,pagechoice.net,🍃 应用净化
  - DOMAIN-SUFFIX,prom.gome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,qchannel0d.cn,🍃 应用净化
  - DOMAIN-SUFFIX,qt002x.corp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,rlogs.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,static.flv.uuzuonline.com,🍃 应用净化
  - DOMAIN-SUFFIX,tb060x.corp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,tb104x.corp.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,union.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,wanproxy.127.net,🍃 应用净化
  - DOMAIN-SUFFIX,ydpushserver.youdao.com,🍃 应用净化
  - DOMAIN-SUFFIX,cvda.17173.com,🍃 应用净化
  - DOMAIN-SUFFIX,imgapp.yeyou.com,🍃 应用净化
  - DOMAIN-SUFFIX,log1.17173.com,🍃 应用净化
  - DOMAIN-SUFFIX,s.17173cdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,ue.yeyoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,vda.17173.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.wanmei.com,🍃 应用净化
  - DOMAIN-SUFFIX,gg.stargame.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,download.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,houtai.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,jifen.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,jifendownload.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,minipage.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wan.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,zhushou.2345.cn,🍃 应用净化
  - DOMAIN-SUFFIX,3600.com,🍃 应用净化
  - DOMAIN-SUFFIX,gamebox.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,jiagu.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,kuaikan.netmon.360safe.com,🍃 应用净化
  - DOMAIN-SUFFIX,leak.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,lianmeng.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pub.se.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,s.so.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,shouji.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,soft.data.weather.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,stat.360safe.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.m.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,update.360safe.com,🍃 应用净化
  - DOMAIN-SUFFIX,wan.360.cn,🍃 应用净化
  - DOMAIN-SUFFIX,58.xgo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,brandshow.58.com,🍃 应用净化
  - DOMAIN-SUFFIX,imp.xgo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,jing.58.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.xgo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,track.58.com,🍃 应用净化
  - DOMAIN-SUFFIX,tracklog.58.com,🍃 应用净化
  - DOMAIN-SUFFIX,acjs.aliyun.com,🍃 应用净化
  - DOMAIN-SUFFIX,adash-c.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,adash-c.ut.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,adashx4yt.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,adashxgc.ut.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,afp.alicdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,ai.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,alipaylog.com,🍃 应用净化
  - DOMAIN-SUFFIX,atanx.alicdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,atanx2.alicdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,fav.simba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,g.click.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,g.tbcdn.cn,🍃 应用净化
  - DOMAIN-SUFFIX,gma.alicdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,gtmsdd.alicdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,hydra.alibaba.com,🍃 应用净化
  - DOMAIN-SUFFIX,m.simba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,pindao.huoban.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,re.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,redirect.simba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,rj.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,sdkinit.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,show.re.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,simaba.m.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,simaba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,srd.simba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,strip.taobaocdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,tns.simba.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,tyh.taobao.com,🍃 应用净化
  - DOMAIN-SUFFIX,userimg.qunar.com,🍃 应用净化
  - DOMAIN-SUFFIX,yiliao.hupan.com,🍃 应用净化
  - DOMAIN-SUFFIX,3dns-2.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,3dns-3.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,activate-sea.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,activate-sjc0.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,activate.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,adobe-dns-2.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,adobe-dns-3.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,adobe-dns.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,ereg.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,geo2.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,hl2rcv.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,hlrcv.stage.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,lm.licenses.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,lmlicenses.wip4.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,na1r.services.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,na2m-pr.licenses.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,practivate.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,wip3.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,wwis-dubc1-vip60.adobe.com,🍃 应用净化
  - DOMAIN-SUFFIX,adserver.unityads.unity3d.com,🍃 应用净化
  - DOMAIN-SUFFIX,33.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adproxy.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,al.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,alert.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,applogapi.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,c.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cmx.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dspmnt.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pcd.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,push.app.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pvx.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,rd.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,rdx.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,stats.autohome.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,a.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,a.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.duapps.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.player.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,adm.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,adscdn.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adscdn.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,adx.xiaodutv.com,🍃 应用净化
  - DOMAIN-SUFFIX,ae.bdstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,afd.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,afd.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,als.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,als.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,anquan.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,anquan.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,antivirus.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,api.mobula.sdk.duapps.com,🍃 应用净化
  - DOMAIN-SUFFIX,appc.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,appc.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,as.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,as.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,baichuan.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,baidu9635.com,🍃 应用净化
  - DOMAIN-SUFFIX,baidustatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,baidutv.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,baikebcs.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,banlv.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,bar.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,bdplus.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,btlaunch.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,c.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,c.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cb.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cb.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cbjs.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cbjs.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cbjslog.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cbjslog.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cjhq.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cjhq.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cleaner.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.bes.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.hm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.qianqian.com,🍃 应用净化
  - DOMAIN-SUFFIX,cm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpro.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cpro.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpro.baidustatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpro.tieba.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpro.zhidao.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpro2.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cpro2.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpu-admin.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,crs.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,crs.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,datax.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl-vip.bav.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl-vip.pcfaster.baidu.co.th,🍃 应用净化
  - DOMAIN-SUFFIX,dl.client.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl.ops.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl1sw.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl2.bav.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dlsw.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dlsw.br.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,download.bav.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,download.sd.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,drmcmm.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,drmcmm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dup.baidustatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,dxp.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dzl.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,e.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,e.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,eclick.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,eclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ecma.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,ecmb.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,ecmc.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,eiv.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,eiv.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,em.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ers.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,f10.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,fc-.cdn.bcebos.com,🍃 应用净化
  - DOMAIN-SUFFIX,fc-feed.cdn.bcebos.com,🍃 应用净化
  - DOMAIN-SUFFIX,fclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,fexclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,g.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,gimg.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,guanjia.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,hc.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,hc.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,hm.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,hm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,hmma.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,hmma.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,hpd.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,hpd.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,idm-su.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,iebar.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ikcode.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,imageplus.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,imageplus.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,img.taotaosou.cn,🍃 应用净化
  - DOMAIN-SUFFIX,img01.taotaosou.cn,🍃 应用净化
  - DOMAIN-SUFFIX,itsdata.map.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,j.br.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,kstj.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.music.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.nuomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,m1.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ma.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ma.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,mg09.zhaopin.com,🍃 应用净化
  - DOMAIN-SUFFIX,mipcache.bdstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobads-logs.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mobads-logs.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobads.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mobads.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,mpro.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,mtj.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mtj.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,neirong.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,nsclick.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,nsclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,nsclickvideo.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,openrcv.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pc.videoclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pos.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pups.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pups.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pups.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.music.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.zhanzhang.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,qchannel0d.cn,🍃 应用净化
  - DOMAIN-SUFFIX,qianclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,release.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,res.limei.com,🍃 应用净化
  - DOMAIN-SUFFIX,res.mi.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,rigel.baidustatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,river.zhidao.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,rj.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,rj.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,rp.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,rp.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,rplog.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,s.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,sclick.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,sestat.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,shadu.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,share.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,sobar.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,sobartop.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,spcode.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,spcode.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.v.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,su.bdimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,su.bdstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,tk.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,tk.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tkweb.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tob-cms.bj.bcebos.com,🍃 应用净化
  - DOMAIN-SUFFIX,toolbar.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tracker.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tuijian.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tuisong.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,tuisong.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ubmcmm.baidustatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,ucstat.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ucstat.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ulic.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ulog.imap.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,union.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,union.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,unionimage.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,utility.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,utility.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,utk.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,utk.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,videopush.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,videopush.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,vv84.bj.bcebos.com,🍃 应用净化
  - DOMAIN-SUFFIX,w.gdown.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,w.x.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,wangmeng.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wangmeng.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,weishi.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,wenku-cms.bj.bcebos.com,🍃 应用净化
  - DOMAIN-SUFFIX,wisepush.video.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,wm.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wm.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,znsv.baidu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,znsv.baidu.com,🍃 应用净化
  - DOMAIN-SUFFIX,zz.bdstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,zzy1.quyaoya.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.zhangyue.com,🍃 应用净化
  - DOMAIN-SUFFIX,adm.ps.easou.com,🍃 应用净化
  - DOMAIN-SUFFIX,aishowbger.com,🍃 应用净化
  - DOMAIN-SUFFIX,api.itaoxiaoshuo.com,🍃 应用净化
  - DOMAIN-SUFFIX,assets.ps.easou.com,🍃 应用净化
  - DOMAIN-SUFFIX,bbcoe.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cj.qidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,dkeyn.com,🍃 应用净化
  - DOMAIN-SUFFIX,drdwy.com,🍃 应用净化
  - DOMAIN-SUFFIX,e.aa985.cn,🍃 应用净化
  - DOMAIN-SUFFIX,e.v02u9.cn,🍃 应用净化
  - DOMAIN-SUFFIX,e701.net,🍃 应用净化
  - DOMAIN-SUFFIX,ehxyz.com,🍃 应用净化
  - DOMAIN-SUFFIX,ethod.gzgmjcx.com,🍃 应用净化
  - DOMAIN-SUFFIX,focuscat.com,🍃 应用净化
  - DOMAIN-SUFFIX,game.qidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,hdswgc.com,🍃 应用净化
  - DOMAIN-SUFFIX,jyd.fjzdmy.com,🍃 应用净化
  - DOMAIN-SUFFIX,m.ourlj.com,🍃 应用净化
  - DOMAIN-SUFFIX,m.txtxr.com,🍃 应用净化
  - DOMAIN-SUFFIX,m.vsxet.com,🍃 应用净化
  - DOMAIN-SUFFIX,miam4.cn,🍃 应用净化
  - DOMAIN-SUFFIX,o.if.qidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.vq6nsu.cn,🍃 应用净化
  - DOMAIN-SUFFIX,picture.duokan.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.zhangyue.com,🍃 应用净化
  - DOMAIN-SUFFIX,pyerc.com,🍃 应用净化
  - DOMAIN-SUFFIX,s1.cmfu.com,🍃 应用净化
  - DOMAIN-SUFFIX,sc.shayugg.com,🍃 应用净化
  - DOMAIN-SUFFIX,sdk.cferw.com,🍃 应用净化
  - DOMAIN-SUFFIX,sezvc.com,🍃 应用净化
  - DOMAIN-SUFFIX,sys.zhangyue.com,🍃 应用净化
  - DOMAIN-SUFFIX,tjlog.ps.easou.com,🍃 应用净化
  - DOMAIN-SUFFIX,tongji.qidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,ut2.shuqistat.com,🍃 应用净化
  - DOMAIN-SUFFIX,xgcsr.com,🍃 应用净化
  - DOMAIN-SUFFIX,xjq.jxmqkj.com,🍃 应用净化
  - DOMAIN-SUFFIX,xpe.cxaerp.com,🍃 应用净化
  - DOMAIN-SUFFIX,xtzxmy.com,🍃 应用净化
  - DOMAIN-SUFFIX,xyrkl.com,🍃 应用净化
  - DOMAIN-SUFFIX,zhuanfakong.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,dsp.toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,ic.snssdk.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.snssdk.com,🍃 应用净化
  - DOMAIN-SUFFIX,nativeapp.toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,pangolin-sdk-toutiao-b.com,🍃 应用净化
  - DOMAIN-SUFFIX,pangolin-sdk-toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,pangolin.snssdk.com,🍃 应用净化
  - DOMAIN-SUFFIX,partner.toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,pglstatp-toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,sm.toutiao.com,🍃 应用净化
  - DOMAIN-SUFFIX,a.dangdang.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.dangdang.com,🍃 应用净化
  - DOMAIN-SUFFIX,schprompt.dangdang.com,🍃 应用净化
  - DOMAIN-SUFFIX,t.dangdang.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.duomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,boxshows.com,🍃 应用净化
  - DOMAIN-SUFFIX,staticxx.facebook.com,🍃 应用净化
  - DOMAIN-SUFFIX,click1n.soufun.com,🍃 应用净化
  - DOMAIN-SUFFIX,clickm.fang.com,🍃 应用净化
  - DOMAIN-SUFFIX,clickn.fang.com,🍃 应用净化
  - DOMAIN-SUFFIX,countpvn.light.fang.com,🍃 应用净化
  - DOMAIN-SUFFIX,countubn.light.soufun.com,🍃 应用净化
  - DOMAIN-SUFFIX,mshow.fang.com,🍃 应用净化
  - DOMAIN-SUFFIX,tongji.home.soufun.com,🍃 应用净化
  - DOMAIN-SUFFIX,admob.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.gmodules.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,adservice.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,afd.l.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,badad.googleplex.com,🍃 应用净化
  - DOMAIN-SUFFIX,csi.gstatic.com,🍃 应用净化
  - DOMAIN-SUFFIX,doubleclick.com,🍃 应用净化
  - DOMAIN-SUFFIX,doubleclick.net,🍃 应用净化
  - DOMAIN-SUFFIX,google-analytics.com,🍃 应用净化
  - DOMAIN-SUFFIX,googleadservices.com,🍃 应用净化
  - DOMAIN-SUFFIX,googleadsserving.cn,🍃 应用净化
  - DOMAIN-SUFFIX,googlecommerce.com,🍃 应用净化
  - DOMAIN-SUFFIX,googlesyndication.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobileads.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,pagead-tpc.l.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,pagead.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,pagead.l.google.com,🍃 应用净化
  - DOMAIN-SUFFIX,service.urchin.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.union.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,c-nfa.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,cps.360buy.com,🍃 应用净化
  - DOMAIN-SUFFIX,img-x.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,jrclick.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,jzt.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,policy.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.m.jd.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.service.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,adsfile.bssdlbig.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,d.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,downmobile.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,gad.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,game.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,gamebox.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,gcapi.sy.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,gg.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,install.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,install2.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,kgmobilestat.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,kuaikaiapp.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.stat.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.web.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,minidcsc.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,mo.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobilelog.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,msg.mobile.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,mvads.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.mobile.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,rtmonitor.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,sdn.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,tj.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,update.mobile.kugou.com,🍃 应用净化
  - DOMAIN-SUFFIX,apk.shouji.koowo.com,🍃 应用净化
  - DOMAIN-SUFFIX,deliver.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,g.koowo.com,🍃 应用净化
  - DOMAIN-SUFFIX,g.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,kwmsg.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,log.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mobilead.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,msclick2.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,msphoneclick.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,updatepage.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wa.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,webstat.kuwo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,aider-res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,api-flow.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,api-game.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,api-push.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,aries.mzres.com,🍃 应用净化
  - DOMAIN-SUFFIX,bro.flyme.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cal.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ebook.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ebook.res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,game-res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,game.res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,infocenter.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,openapi-news.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,reader.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,reader.res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,t-e.flyme.cn,🍃 应用净化
  - DOMAIN-SUFFIX,t-flow.flyme.cn,🍃 应用净化
  - DOMAIN-SUFFIX,tongji-res1.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tongji.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,umid.orion.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,upush.res.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,uxip.meizu.com,🍃 应用净化
  - DOMAIN-SUFFIX,a.koudai.com,🍃 应用净化
  - DOMAIN-SUFFIX,adui.tg.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,corp.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,dc.meitustat.com,🍃 应用净化
  - DOMAIN-SUFFIX,gg.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,mdc.meitustat.com,🍃 应用净化
  - DOMAIN-SUFFIX,meitubeauty.meitudata.com,🍃 应用净化
  - DOMAIN-SUFFIX,message.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,rabbit.meitustat.com,🍃 应用净化
  - DOMAIN-SUFFIX,rabbit.tg.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,tuiguang.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,xiuxiu.android.dl.meitu.com,🍃 应用净化
  - DOMAIN-SUFFIX,xiuxiu.mobile.meitudata.com,🍃 应用净化
  - DOMAIN-SUFFIX,a.market.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad1.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,adv.sec.intl.miui.com,🍃 应用净化
  - DOMAIN-SUFFIX,adv.sec.miui.com,🍃 应用净化
  - DOMAIN-SUFFIX,bss.pandora.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,d.g.mi.com,🍃 应用净化
  - DOMAIN-SUFFIX,data.mistat.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,de.pandora.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,dvb.pandora.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,jellyfish.pandora.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,migc.g.mi.com,🍃 应用净化
  - DOMAIN-SUFFIX,migcreport.g.mi.com,🍃 应用净化
  - DOMAIN-SUFFIX,notice.game.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,ppurifier.game.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,r.browser.miui.com,🍃 应用净化
  - DOMAIN-SUFFIX,security.browser.miui.com,🍃 应用净化
  - DOMAIN-SUFFIX,shenghuo.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.pandora.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,union.mi.com,🍃 应用净化
  - DOMAIN-SUFFIX,wtradv.market.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,xmpush.xiaomi.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.api.moji.com,🍃 应用净化
  - DOMAIN-SUFFIX,app.moji001.com,🍃 应用净化
  - DOMAIN-SUFFIX,cdn.moji002.com,🍃 应用净化
  - DOMAIN-SUFFIX,cdn2.moji002.com,🍃 应用净化
  - DOMAIN-SUFFIX,fds.api.moji.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.moji.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.moji.com,🍃 应用净化
  - DOMAIN-SUFFIX,ugc.moji001.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.qingting.fm,🍃 应用净化
  - DOMAIN-SUFFIX,admgr.qingting.fm,🍃 应用净化
  - DOMAIN-SUFFIX,dload.qd.qingting.fm,🍃 应用净化
  - DOMAIN-SUFFIX,logger.qingting.fm,🍃 应用净化
  - DOMAIN-SUFFIX,s.qd.qingting.fm,🍃 应用净化
  - DOMAIN-SUFFIX,s.qd.qingtingfm.com,🍃 应用净化
  - DOMAIN-KEYWORD,omgmtaw,🍃 应用净化
  - DOMAIN,adsmind.apdcdn.tc.qq.com,🍃 应用净化
  - DOMAIN,adsmind.gdtimg.com,🍃 应用净化
  - DOMAIN,adsmind.tc.qq.com,🍃 应用净化
  - DOMAIN,pgdt.gtimg.cn,🍃 应用净化
  - DOMAIN,pgdt.gtimg.com,🍃 应用净化
  - DOMAIN,pgdt.ugdtimg.com,🍃 应用净化
  - DOMAIN,splashqqlive.gtimg.com,🍃 应用净化
  - DOMAIN,wa.gtimg.com,🍃 应用净化
  - DOMAIN,wxsnsdy.wxs.qq.com,🍃 应用净化
  - DOMAIN,wxsnsdythumb.wxs.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,act.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.qun.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,adsfile.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,bugly.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,buluo.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,e.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,gdt.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,monitor.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,pingma.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,pingtcss.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,report.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,tajs.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,tcss.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,uu.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,ebp.renren.com,🍃 应用净化
  - DOMAIN-SUFFIX,jebe.renren.com,🍃 应用净化
  - DOMAIN-SUFFIX,jebe.xnimg.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adbox.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,add.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adimg.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adm.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,alitui.weibo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,biz.weibo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,cre.dp.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dcads.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dd.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dmp.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,game.weibo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,gw5.push.mcp.weibo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,leju.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,log.mix.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mobileads.dx.cn,🍃 应用净化
  - DOMAIN-SUFFIX,newspush.sinajs.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pay.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,sax.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,sax.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,saxd.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,sdkapp.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,sdkapp.uve.weibo.com,🍃 应用净化
  - DOMAIN-SUFFIX,sdkclick.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,slog.sina.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,trends.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,tui.weibo.com,🍃 应用净化
  - DOMAIN-SUFFIX,u1.img.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wax.weibo.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wbapp.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wbapp.uve.weibo.com,🍃 应用净化
  - DOMAIN-SUFFIX,wbclick.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,wbpctips.mobile.sina.cn,🍃 应用净化
  - DOMAIN-SUFFIX,zymo.mps.weibo.com,🍃 应用净化
  - DOMAIN-SUFFIX,123.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,123.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,adsence.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,amfi.gou.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,brand.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,cpc.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,epro.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,fair.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,files2.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,galaxy.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,golden1.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,goto.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,inte.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,iwan.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,lu.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,lu.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,pb.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,pd.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,theta.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,wan.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,wangmeng.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,applovin.com,🍃 应用净化
  - DOMAIN-SUFFIX,guangzhuiyuan.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads-twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,scribe.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,syndication-o.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,syndication.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,tellapart.com,🍃 应用净化
  - DOMAIN-SUFFIX,urls.api.twitter.com,🍃 应用净化
  - DOMAIN-SUFFIX,adslot.uc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,api.mp.uc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,applog.uc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,client.video.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,cms.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,dispatcher.upmc.uc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,huichuan.sm.cn,🍃 应用净化
  - DOMAIN-SUFFIX,log.cs.pp.cn,🍃 应用净化
  - DOMAIN-SUFFIX,m.uczzd.cn,🍃 应用净化
  - DOMAIN-SUFFIX,patriot.cs.pp.cn,🍃 应用净化
  - DOMAIN-SUFFIX,puds.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,server.m.pp.cn,🍃 应用净化
  - DOMAIN-SUFFIX,track.uc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,u.uc123.com,🍃 应用净化
  - DOMAIN-SUFFIX,u.ucfly.com,🍃 应用净化
  - DOMAIN-SUFFIX,uc.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,ucsec.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,ucsec1.ucweb.com,🍃 应用净化
  - DOMAIN-SUFFIX,aoodoo.feng.com,🍃 应用净化
  - DOMAIN-SUFFIX,fengbuy.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.feng.com,🍃 应用净化
  - DOMAIN-SUFFIX,we.tm,🍃 应用净化
  - DOMAIN-SUFFIX,yes1.feng.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.docer.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,adm.zookingsoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,bannera.kingsoft-office-service.com,🍃 应用净化
  - DOMAIN-SUFFIX,bole.shangshufang.ksosoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,counter.kingsoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,docerad.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,gou.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,hoplink.ksosoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,ic.ksosoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,img.gou.wpscdn.cn,🍃 应用净化
  - DOMAIN-SUFFIX,info.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ios-informationplatform.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,minfo.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,mo.res.wpscdn.cn,🍃 应用净化
  - DOMAIN-SUFFIX,news.docer.com,🍃 应用净化
  - DOMAIN-SUFFIX,notify.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pc.uf.ksosoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,pcfg.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pixiu.shangshufang.ksosoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,rating6.kingsoft-office-service.com,🍃 应用净化
  - DOMAIN-SUFFIX,up.wps.kingsoft.com,🍃 应用净化
  - DOMAIN-SUFFIX,wpsweb-dc.wps.cn,🍃 应用净化
  - DOMAIN-SUFFIX,c.51y5.net,🍃 应用净化
  - DOMAIN-SUFFIX,cdsget.51y5.net,🍃 应用净化
  - DOMAIN-SUFFIX,news-imgpb.51y5.net,🍃 应用净化
  - DOMAIN-SUFFIX,wifiapidd.51y5.net,🍃 应用净化
  - DOMAIN-SUFFIX,wkanc.51y5.net,🍃 应用净化
  - DOMAIN-SUFFIX,adse.ximalaya.com,🍃 应用净化
  - DOMAIN-SUFFIX,linkeye.ximalaya.com,🍃 应用净化
  - DOMAIN-SUFFIX,location.ximalaya.com,🍃 应用净化
  - DOMAIN-SUFFIX,xdcs-collector.ximalaya.com,🍃 应用净化
  - DOMAIN-SUFFIX,biz5.kankan.com,🍃 应用净化
  - DOMAIN-SUFFIX,float.kankan.com,🍃 应用净化
  - DOMAIN-SUFFIX,hub5btmain.sandai.net,🍃 应用净化
  - DOMAIN-SUFFIX,hub5emu.sandai.net,🍃 应用净化
  - DOMAIN-SUFFIX,logic.cpm.cm.kankan.com,🍃 应用净化
  - DOMAIN-SUFFIX,upgrade.xl9.xunlei.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.wretch.cc,🍃 应用净化
  - DOMAIN-SUFFIX,ads.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,adserver.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,adss.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.query.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,ane.yahoo.co.jp,🍃 应用净化
  - DOMAIN-SUFFIX,ard.yahoo.co.jp,🍃 应用净化
  - DOMAIN-SUFFIX,beap-bc.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,clicks.beap.bc.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,comet.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,doubleplay-conf-yql.media.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,flurry.com,🍃 应用净化
  - DOMAIN-SUFFIX,gemini.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,geo.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,js-apac-ss.ysm.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,locdrop.query.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,onepush.query.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,p3p.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,partnerads.ysm.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,ws.progrss.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,yads.yahoo.co.jp,🍃 应用净化
  - DOMAIN-SUFFIX,ybp.yahoo.com,🍃 应用净化
  - DOMAIN-SUFFIX,zhihu-web-analytics.zhihu.com,🍃 应用净化
  - DOMAIN-SUFFIX,shrek.6.cn,🍃 应用净化
  - DOMAIN-SUFFIX,simba.6.cn,🍃 应用净化
  - DOMAIN-SUFFIX,union.6.cn,🍃 应用净化
  - DOMAIN-SUFFIX,logger.baofeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,xs.houyi.baofeng.net,🍃 应用净化
  - DOMAIN-SUFFIX,dotcounter.douyutv.com,🍃 应用净化
  - DOMAIN-SUFFIX,api.newad.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,exp.3g.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,game.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,iis3g.deliver.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,mfp.deliver.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,stadig.ifeng.com,🍃 应用净化
  - DOMAIN-SUFFIX,adm.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,jobsfe.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,po.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,pub.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.funshion.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.m.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,afp.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,c.uaa.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,cloudpush.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,cm.passport.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,cupid.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,emoticon.sns.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,gamecenter.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,ifacelog.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,mbdlog.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,meta.video.qiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,msg.71.am,🍃 应用净化
  - DOMAIN-SUFFIX,msg1.video.qiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,msg2.video.qiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,paopao.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,paopaod.qiyipic.com,🍃 应用净化
  - DOMAIN-SUFFIX,policy.video.iqiyi.com,🍃 应用净化
  - DOMAIN-SUFFIX,yuedu.iqiyi.com,🍃 应用净化
  - IP-CIDR,101.227.200.0/24,🍃 应用净化,no-resolve
  - IP-CIDR,101.227.200.11/32,🍃 应用净化,no-resolve
  - IP-CIDR,101.227.200.28/32,🍃 应用净化,no-resolve
  - IP-CIDR,101.227.97.240/32,🍃 应用净化,no-resolve
  - IP-CIDR,124.192.153.42/32,🍃 应用净化,no-resolve
  - DOMAIN-SUFFIX,gug.ku6cdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,pq.stat.ku6.com,🍃 应用净化
  - DOMAIN-SUFFIX,st.vq.ku6.cn,🍃 应用净化
  - DOMAIN-SUFFIX,static.ku6.com,🍃 应用净化
  - DOMAIN-SUFFIX,1.letvlive.com,🍃 应用净化
  - DOMAIN-SUFFIX,2.letvlive.com,🍃 应用净化
  - DOMAIN-SUFFIX,ark.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,dc.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,fz.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,g3.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,game.letvstore.com,🍃 应用净化
  - DOMAIN-SUFFIX,i0.letvimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,i3.letvimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,minisite.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,n.mark.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,pro.hoye.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,pro.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,static.app.m.letv.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,da.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,da.mgtv.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.v2.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,p2.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,res.hunantv.com,🍃 应用净化
  - DOMAIN-SUFFIX,888.tv.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,adnet.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,aty.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,aty.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,bd.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,click2.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,ctr.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,epro.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,epro.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,go.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,golden1.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,golden1.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,hui.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,inte.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,inte.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,inte.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,lm.tv.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,lu.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,pb.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.tv.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,theta.sogoucdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,um.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,uranus.sogou.com,🍃 应用净化
  - DOMAIN-SUFFIX,uranus.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,wan.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,wl.hd.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,yule.sohu.com,🍃 应用净化
  - DOMAIN-SUFFIX,afp.pplive.com,🍃 应用净化
  - DOMAIN-SUFFIX,app.aplus.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,as.aplus.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,asimgs.pplive.cn,🍃 应用净化
  - DOMAIN-SUFFIX,de.as.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,jp.as.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,pp2.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.pptv.com,🍃 应用净化
  - DOMAIN-SUFFIX,btrace.video.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,c.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,dp3.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,livep.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,lives.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,livew.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,mcgi.v.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,mdevstat.qqlive.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,omgmta1.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,rcgi.video.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,t.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,u.l.qq.com,🍃 应用净化
  - DOMAIN-SUFFIX,a-dxk.play.api.3g.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,actives.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.api.3g.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.api.3g.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.api.mobile.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.mobile.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,adcontrol.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,adplay.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,b.smartvideo.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,c.yes.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,dev-push.m.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,dl.g.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,dmapp.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,e.stat.ykimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,gamex.mobile.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,goods.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,hudong.pl.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,hz.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,iwstat.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,iyes.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,l.ykimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,l.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,lstat.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,lvip.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobilemsg.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,msg.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,myes.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,nstat.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,p-log.ykimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.l.ykimg.com,🍃 应用净化
  - DOMAIN-SUFFIX,p.l.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,passport-log.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.m.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,r.l.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,s.p.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,sdk.m.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,stats.tudou.com,🍃 应用净化
  - DOMAIN-SUFFIX,store.tv.api.3g.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,store.xl.api.3g.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,tdrec.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,test.ott.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,v.l.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,val.api.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,wan.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ykatr.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ykrec.youku.com,🍃 应用净化
  - DOMAIN-SUFFIX,ykrectab.youku.com,🍃 应用净化
  - IP-CIDR,117.177.248.17/32,🍃 应用净化,no-resolve
  - IP-CIDR,117.177.248.41/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.176.139/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.176.176/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.180/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.182/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.184/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.43/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.47/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.177.80/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.182.101/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.182.102/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.182.11/32,🍃 应用净化,no-resolve
  - IP-CIDR,223.87.182.52/32,🍃 应用净化,no-resolve
  - DOMAIN-SUFFIX,azabu-u.ac.jp,🍃 应用净化
  - DOMAIN-SUFFIX,couchcoaster.jp,🍃 应用净化
  - DOMAIN-SUFFIX,delivery.dmkt-sp.jp,🍃 应用净化
  - DOMAIN-SUFFIX,ehg-youtube.hitbox.com,🍃 应用净化
  - DOMAIN-SUFFIX,nichibenren.or.jp,🍃 应用净化
  - DOMAIN-SUFFIX,nicorette.co.kr,🍃 应用净化
  - DOMAIN-SUFFIX,ssl-youtube.2cnt.net,🍃 应用净化
  - DOMAIN-SUFFIX,youtube.112.2o7.net,🍃 应用净化
  - DOMAIN-SUFFIX,youtube.2cnt.net,🍃 应用净化
  - DOMAIN-SUFFIX,acsystem.wasu.tv,🍃 应用净化
  - DOMAIN-SUFFIX,ads.cdn.tvb.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.wasu.tv,🍃 应用净化
  - DOMAIN-SUFFIX,afp.wasu.tv,🍃 应用净化
  - DOMAIN-SUFFIX,c.algovid.com,🍃 应用净化
  - DOMAIN-SUFFIX,gg.jtertp.com,🍃 应用净化
  - DOMAIN-SUFFIX,gridsum-vd.cntv.cn,🍃 应用净化
  - DOMAIN-SUFFIX,kwflvcdn.000dn.com,🍃 应用净化
  - DOMAIN-SUFFIX,logstat.t.sfht.com,🍃 应用净化
  - DOMAIN-SUFFIX,match.rtbidder.net,🍃 应用净化
  - DOMAIN-SUFFIX,n-st.vip.com,🍃 应用净化
  - DOMAIN-SUFFIX,pop.uusee.com,🍃 应用净化
  - DOMAIN-SUFFIX,static.duoshuo.com,🍃 应用净化
  - DOMAIN-SUFFIX,t.cr-nielsen.com,🍃 应用净化
  - DOMAIN-SUFFIX,terren.cntv.cn,🍃 应用净化
  - DOMAIN-SUFFIX,1.win7china.com,🍃 应用净化
  - DOMAIN-SUFFIX,168.it168.com,🍃 应用净化
  - DOMAIN-SUFFIX,2.win7china.com,🍃 应用净化
  - DOMAIN-SUFFIX,801.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,801.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,803.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,803.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,806.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,806.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,808.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,808.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,92x.tumblr.com,🍃 应用净化
  - DOMAIN-SUFFIX,a1.itc.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad-channel.wikawika.xyz,🍃 应用净化
  - DOMAIN-SUFFIX,ad-display.wikawika.xyz,🍃 应用净化
  - DOMAIN-SUFFIX,ad.12306.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.3.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.95306.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.caiyunapp.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.cctv.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.cmvideo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.csdn.net,🍃 应用净化
  - DOMAIN-SUFFIX,ad.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.house365.com,🍃 应用净化
  - DOMAIN-SUFFIX,ad.thepaper.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ad.unimhk.com,🍃 应用净化
  - DOMAIN-SUFFIX,adadmin.house365.com,🍃 应用净化
  - DOMAIN-SUFFIX,adhome.1fangchan.com,🍃 应用净化
  - DOMAIN-SUFFIX,adm.10jqka.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ads.csdn.net,🍃 应用净化
  - DOMAIN-SUFFIX,ads.feedly.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.genieessp.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.house365.com,🍃 应用净化
  - DOMAIN-SUFFIX,ads.linkedin.com,🍃 应用净化
  - DOMAIN-SUFFIX,adshownew.it168.com,🍃 应用净化
  - DOMAIN-SUFFIX,adv.ccb.com,🍃 应用净化
  - DOMAIN-SUFFIX,advert.api.thejoyrun.com,🍃 应用净化
  - DOMAIN-SUFFIX,analytics.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,api-deal.kechenggezi.com,🍃 应用净化
  - DOMAIN-SUFFIX,api-z.weidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,app-monitor.ele.me,🍃 应用净化
  - DOMAIN-SUFFIX,bat.bing.com,🍃 应用净化
  - DOMAIN-SUFFIX,bd1.52che.com,🍃 应用净化
  - DOMAIN-SUFFIX,bd2.52che.com,🍃 应用净化
  - DOMAIN-SUFFIX,bdj.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,bdj.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,beacon.tingyun.com,🍃 应用净化
  - DOMAIN-SUFFIX,cdn.jiuzhilan.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.cheshi-img.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.cheshi.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,click.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,click.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,client-api.ele.me,🍃 应用净化
  - DOMAIN-SUFFIX,collector.githubapp.com,🍃 应用净化
  - DOMAIN-SUFFIX,counter.csdn.net,🍃 应用净化
  - DOMAIN-SUFFIX,d0.xcar.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,de.soquair.com,🍃 应用净化
  - DOMAIN-SUFFIX,dol.tianya.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dol.tianyaui.cn,🍃 应用净化
  - DOMAIN-SUFFIX,dw.xcar.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,e.nexac.com,🍃 应用净化
  - DOMAIN-SUFFIX,eq.10jqka.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,exp.17wo.cn,🍃 应用净化
  - DOMAIN-SUFFIX,game.51yund.com,🍃 应用净化
  - DOMAIN-SUFFIX,ganjituiguang.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,grand.ele.me,🍃 应用净化
  - DOMAIN-SUFFIX,hosting.miarroba.info,🍃 应用净化
  - DOMAIN-SUFFIX,iadsdk.apple.com,🍃 应用净化
  - DOMAIN-SUFFIX,image.gentags.com,🍃 应用净化
  - DOMAIN-SUFFIX,its-dori.tumblr.com,🍃 应用净化
  - DOMAIN-SUFFIX,log.outbrain.com,🍃 应用净化
  - DOMAIN-SUFFIX,m.12306media.com,🍃 应用净化
  - DOMAIN-SUFFIX,media.cheshi-img.com,🍃 应用净化
  - DOMAIN-SUFFIX,media.cheshi.com,🍃 应用净化
  - DOMAIN-SUFFIX,mobile-pubt.ele.me,🍃 应用净化
  - DOMAIN-SUFFIX,mobileads.msn.com,🍃 应用净化
  - DOMAIN-SUFFIX,n.cosbot.cn,🍃 应用净化
  - DOMAIN-SUFFIX,newton-api.ele.me,🍃 应用净化
  - DOMAIN-SUFFIX,ozone.10jqka.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,pdl.gionee.com,🍃 应用净化
  - DOMAIN-SUFFIX,pica-juicy.picacomic.com,🍃 应用净化
  - DOMAIN-SUFFIX,pixel.wp.com,🍃 应用净化
  - DOMAIN-SUFFIX,pub.mop.com,🍃 应用净化
  - DOMAIN-SUFFIX,push.wandoujia.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.cheshi-img.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.cheshi.com,🍃 应用净化
  - DOMAIN-SUFFIX,pv.xcar.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,qdp.qidian.com,🍃 应用净化
  - DOMAIN-SUFFIX,res.gwifi.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,ssp.kssws.ks-cdn.com,🍃 应用净化
  - DOMAIN-SUFFIX,sta.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,stat.10jqka.com.cn,🍃 应用净化
  - DOMAIN-SUFFIX,stat.it168.com,🍃 应用净化
  - DOMAIN-SUFFIX,stats.chinaz.com,🍃 应用净化
  - DOMAIN-SUFFIX,stats.developingperspective.com,🍃 应用净化
  - DOMAIN-SUFFIX,track.hujiang.com,🍃 应用净化
  - DOMAIN-SUFFIX,tracker.yhd.com,🍃 应用净化
  - DOMAIN-SUFFIX,tralog.ganji.com,🍃 应用净化
  - DOMAIN-SUFFIX,up.qingdaonews.com,🍃 应用净化
  - DOMAIN-SUFFIX,vaserviece.10jqka.com.cn,🍃 应用净化
# Google China
#DOMAIN-SUFFIX,translate.googleapis.com
  - DOMAIN-SUFFIX,265.com,🎯 全球直连
  - DOMAIN-SUFFIX,2mdn.net,🎯 全球直连
  - DOMAIN-SUFFIX,alt1-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt2-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt3-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt4-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt5-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt6-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt7-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,alt8-mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,app-measurement.com,🎯 全球直连
  - DOMAIN-SUFFIX,c.android.clients.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,cache.pack.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,clickserve.dartsearch.net,🎯 全球直连
  - DOMAIN-SUFFIX,clientservices.googleapis.com,🎯 全球直连
  - DOMAIN-SUFFIX,crl.pki.goog,🎯 全球直连
  - DOMAIN-SUFFIX,dl.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,dl.l.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,fonts.googleapis.com,🎯 全球直连
  - DOMAIN-SUFFIX,fonts.gstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,googletagmanager.com,🎯 全球直连
  - DOMAIN-SUFFIX,googletagservices.com,🎯 全球直连
  - DOMAIN-SUFFIX,gtm.oasisfeng.com,🎯 全球直连
  - DOMAIN-SUFFIX,imasdk.googleapis.com,🎯 全球直连
  - DOMAIN-SUFFIX,mtalk.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,ocsp.pki.goog,🎯 全球直连
  - DOMAIN-SUFFIX,recaptcha.net,🎯 全球直连
  - DOMAIN-SUFFIX,safebrowsing-cache.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,safebrowsing.googleapis.com,🎯 全球直连
  - DOMAIN-SUFFIX,settings.crashlytics.com,🎯 全球直连
  - DOMAIN-SUFFIX,ssl-google-analytics.l.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,toolbarqueries.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,tools.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,tools.l.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,update.googleapis.com,🎯 全球直连
  - DOMAIN-SUFFIX,www-googletagmanager.l.google.com,🎯 全球直连
  - DOMAIN-SUFFIX,www.gstatic.com,🎯 全球直连
# 内容：SteamCN
# 数量：15条
  - DOMAIN,csgo.wmsj.cn,🎯 全球直连
  - DOMAIN,dl.steam.clngaa.com,🎯 全球直连
  - DOMAIN,dl.steam.ksyna.com,🎯 全球直连
  - DOMAIN,dota2.wmsj.cn,🎯 全球直连
  - DOMAIN,st.dl.bscstorage.net,🎯 全球直连
  - DOMAIN,st.dl.eccdnx.com,🎯 全球直连
  - DOMAIN,st.dl.pinyuncloud.com,🎯 全球直连
  - DOMAIN,steampipe.steamcontent.tnkjmec.com,🎯 全球直连
  - DOMAIN,steampowered.com.8686c.com,🎯 全球直连
  - DOMAIN,steamstatic.com.8686c.com,🎯 全球直连
  - DOMAIN,wmsjsteam.com,🎯 全球直连
  - DOMAIN-SUFFIX,cm.steampowered.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamchina.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamcontent.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamusercontent.com,🎯 全球直连
# Microsoft Services
# optimized from https://gist.github.com/TTTPOB/ce93fb3b04ba2f21880b09427442d831
# source: https://docs.microsoft.com/en-us/office365/enterprise/urls-and-ip-address-ranges
  - DOMAIN-KEYWORD,1drv,Ⓜ️ 微软服务
  - DOMAIN-KEYWORD,microsoft,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,aadrm.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,acompli.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,acompli.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,aka.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,akadns.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,aspnetcdn.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,assets-yammer.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,azure.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,azure.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,azureedge.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,azurerms.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,bing.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,cloudapp.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,cloudappsecurity.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,edgesuite.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,gfx.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,hotmail.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,live.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,live.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,lync.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msappproxy.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msauth.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msauthimages.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msecnd.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msedge.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msft.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msftauth.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msftauthimages.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msftidentity.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msidentity.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msn.cn,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msn.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msocdn.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,msocsp.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,mstea.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,o365weve.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,oaspapps.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,office.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,office.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,office365.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,officeppe.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,omniroot.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,onedrive.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,onenote.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,onenote.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,onestore.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,outlook.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,outlookmobile.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,phonefactor.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,public-trust.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sfbassets.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sfx.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sharepoint.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sharepointonline.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,skype.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,skypeassets.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,skypeforbusiness.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,staffhub.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,svc.ms,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sway-cdn.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sway-extensions.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,sway.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,trafficmanager.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,uservoice.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,virtualearth.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,visualstudio.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windows-ppe.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windows.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windows.net,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windowsazure.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windowsupdate.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,wunderlist.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,yammer.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,yammerusercontent.com,Ⓜ️ 微软服务
# Apple
# 一般国内Apple肯定正常,不需要开代理
  - DOMAIN,apple.comscoreresearch.com,🍎 苹果服务
  - DOMAIN-SUFFIX,aaplimg.com,🍎 苹果服务
  - DOMAIN-SUFFIX,akadns.net,🍎 苹果服务
  - DOMAIN-SUFFIX,apple-cloudkit.com,🍎 苹果服务
  - DOMAIN-SUFFIX,apple-mapkit.com,🍎 苹果服务
  - DOMAIN-SUFFIX,apple.co,🍎 苹果服务
  - DOMAIN-SUFFIX,apple.com,🍎 苹果服务
  - DOMAIN-SUFFIX,apple.com.cn,🍎 苹果服务
  - DOMAIN-SUFFIX,apple.news,🍎 苹果服务
  - DOMAIN-SUFFIX,appstore.com,🍎 苹果服务
  - DOMAIN-SUFFIX,cdn-apple.com,🍎 苹果服务
  - DOMAIN-SUFFIX,crashlytics.com,🍎 苹果服务
  - DOMAIN-SUFFIX,icloud-content.com,🍎 苹果服务
  - DOMAIN-SUFFIX,icloud.com,🍎 苹果服务
  - DOMAIN-SUFFIX,icloud.com.cn,🍎 苹果服务
  - DOMAIN-SUFFIX,itunes.com,🍎 苹果服务
  - DOMAIN-SUFFIX,me.com,🍎 苹果服务
  - DOMAIN-SUFFIX,mzstatic.com,🍎 苹果服务
  - IP-CIDR,17.0.0.0/8,🍎 苹果服务,no-resolve
  - IP-CIDR,63.92.224.0/19,🍎 苹果服务,no-resolve
  - IP-CIDR,65.199.22.0/23,🍎 苹果服务,no-resolve
  - IP-CIDR,139.178.128.0/18,🍎 苹果服务,no-resolve
  - IP-CIDR,144.178.0.0/19,🍎 苹果服务,no-resolve
  - IP-CIDR,144.178.36.0/22,🍎 苹果服务,no-resolve
  - IP-CIDR,144.178.48.0/20,🍎 苹果服务,no-resolve
  - IP-CIDR,192.35.50.0/24,🍎 苹果服务,no-resolve
  - IP-CIDR,198.183.17.0/24,🍎 苹果服务,no-resolve
  - IP-CIDR,205.180.175.0/24,🍎 苹果服务,no-resolve
# 内容：国外媒体列表
# 更新：2023-01-15 22:06:33
# 数量：330条
# ABC
# AbemaTV
# All4
# Amazon
# AppleNews
# AppleTV
# BBCiPlayer
# Bahamut
# DAZN
# Deezer
# DiscoveryPlus
# DisneyPlus
# EncoreTVB
# FoxNow
# HBO
# HBO_GO_HKG
# HWTV
# Hulu
# HuluJapan
# ITV
# JOOX
# Japonx
# KKBOX
# KKTV
# LiTV
# LineTV
# My5
# MyTVSuper
# Netflix
# Niconico
# PBS
# Pandora
# Pornhub
# Qobuz
# SoundCloud
# Spotify
# TIDAL
# TaiWanGood 台湾好
# TikTok
# Twitch
# ViuTV
# YouTube
# YouTubeMusic
  - DOMAIN-SUFFIX,edgedatg.com,🌍 国外媒体
  - DOMAIN-SUFFIX,go.com,🌍 国外媒体
#   - USER-AGENT,AbemaTV*,🌍 国外媒体
  - DOMAIN-KEYWORD,abematv.akamaized.net,🌍 国外媒体
  - DOMAIN,api-abematv.bucketeer.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,abema-tv.com,🌍 国外媒体
  - DOMAIN-SUFFIX,abema.io,🌍 国外媒体
  - DOMAIN-SUFFIX,abema.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,ameba.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,hayabusa.io,🌍 国外媒体
  - DOMAIN-SUFFIX,hayabusa.media,🌍 国外媒体
#   - USER-AGENT,All4*,🌍 国外媒体
  - DOMAIN-SUFFIX,c4assets.com,🌍 国外媒体
  - DOMAIN-SUFFIX,channel4.com,🌍 国外媒体
  - DOMAIN-KEYWORD,avoddashs,🌍 国外媒体
  - DOMAIN,atv-ps.amazon.com,🌍 国外媒体
  - DOMAIN,avodmp4s3ww-a.akamaihd.net,🌍 国外媒体
  - DOMAIN,d1v5ir2lpwr8os.cloudfront.net,🌍 国外媒体
  - DOMAIN,d1xfray82862hr.cloudfront.net,🌍 国外媒体
  - DOMAIN,d22qjgkvxw22r6.cloudfront.net,🌍 国外媒体
  - DOMAIN,d25xi40x97liuc.cloudfront.net,🌍 国外媒体
  - DOMAIN,d27xxe7juh1us6.cloudfront.net,🌍 国外媒体
  - DOMAIN,d3196yreox78o9.cloudfront.net,🌍 国外媒体
  - DOMAIN,dmqdd6hw24ucf.cloudfront.net,🌍 国外媒体
  - DOMAIN,ktpx.amazon.com,🌍 国外媒体
  - DOMAIN-SUFFIX,aboutamazon.com,🌍 国外媒体
  - DOMAIN-SUFFIX,aiv-cdn.net,🌍 国外媒体
  - DOMAIN-SUFFIX,aiv-delivery.net,🌍 国外媒体
  - DOMAIN-SUFFIX,amazon.jobs,🌍 国外媒体
  - DOMAIN-SUFFIX,amazonuniversity.jobs,🌍 国外媒体
  - DOMAIN-SUFFIX,amazonvideo.com,🌍 国外媒体
  - DOMAIN-SUFFIX,media-amazon.com,🌍 国外媒体
  - DOMAIN-SUFFIX,pv-cdn.net,🌍 国外媒体
#   - URL-REGEX,^https?:\/\/www\.amazon\.com\/(Amazon-Video|gp\/video)\/,🌍 国外媒体
#   - USER-AGENT,AppleNews*,🌍 国外媒体
#   - USER-AGENT,com.apple.news*,🌍 国外媒体
  - DOMAIN,gspe1-ssl.ls.apple.com,🌍 国外媒体
  - DOMAIN,np-edge.itunes.apple.com,🌍 国外媒体
  - DOMAIN,play-edge.itunes.apple.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tv.apple.com,🌍 国外媒体
#   - USER-AGENT,BBCiPlayer*,🌍 国外媒体
  - DOMAIN-KEYWORD,bbcfmt,🌍 国外媒体
  - DOMAIN-KEYWORD,uk-live,🌍 国外媒体
  - DOMAIN,aod-dash-uk-live.akamaized.net,🌍 国外媒体
  - DOMAIN,aod-hls-uk-live.akamaized.net,🌍 国外媒体
  - DOMAIN,vod-dash-uk-live.akamaized.net,🌍 国外媒体
  - DOMAIN,vod-thumb-uk-live.akamaized.net,🌍 国外媒体
  - DOMAIN-SUFFIX,bbc.co,🌍 国外媒体
  - DOMAIN-SUFFIX,bbc.co.uk,🌍 国外媒体
  - DOMAIN-SUFFIX,bbc.com,🌍 国外媒体
  - DOMAIN-SUFFIX,bbc.net.uk,🌍 国外媒体
  - DOMAIN-SUFFIX,bbcfmt.hs.llnwd.net,🌍 国外媒体
  - DOMAIN-SUFFIX,bbci.co,🌍 国外媒体
  - DOMAIN-SUFFIX,bbci.co.uk,🌍 国外媒体
  - DOMAIN-SUFFIX,bidi.net.uk,🌍 国外媒体
#   - USER-AGENT,Anime*,🌍 国外媒体
  - DOMAIN,bahamut.akamaized.net,🌍 国外媒体
  - DOMAIN,gamer-cds.cdn.hinet.net,🌍 国外媒体
  - DOMAIN,gamer2-cds.cdn.hinet.net,🌍 国外媒体
  - DOMAIN-SUFFIX,bahamut.com.tw,🌍 国外媒体
  - DOMAIN-SUFFIX,gamer.com.tw,🌍 国外媒体
#   - USER-AGENT,DAZN*,🌍 国外媒体
  - DOMAIN-KEYWORD,voddazn,🌍 国外媒体
  - DOMAIN,d151l6v8er5bdm.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,d151l6v8er5bdm.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,d1sgwhnao7452x.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,dazn-api.com,🌍 国外媒体
  - DOMAIN-SUFFIX,dazn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,dazndn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,dcblivedazn.akamaized.net,🌍 国外媒体
  - DOMAIN-SUFFIX,indazn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,indaznlab.com,🌍 国外媒体
  - DOMAIN-SUFFIX,sentry.io,🌍 国外媒体
#   - USER-AGENT,Deezer*,🌍 国外媒体
  - DOMAIN-SUFFIX,deezer.com,🌍 国外媒体
  - DOMAIN-SUFFIX,dzcdn.net,🌍 国外媒体
  - DOMAIN-SUFFIX,disco-api.com,🌍 国外媒体
  - DOMAIN-SUFFIX,discovery.com,🌍 国外媒体
  - DOMAIN-SUFFIX,uplynk.com,🌍 国外媒体
#   - USER-AGENT,Disney*,🌍 国外媒体
#   - USER-AGENT,Disney+*,🌍 国外媒体
  - DOMAIN,cdn.registerdisney.go.com,🌍 国外媒体
  - DOMAIN-SUFFIX,adobedtm.com,🌍 国外媒体
  - DOMAIN-SUFFIX,bam.nr-data.net,🌍 国外媒体
  - DOMAIN-SUFFIX,bamgrid.com,🌍 国外媒体
  - DOMAIN-SUFFIX,braze.com,🌍 国外媒体
  - DOMAIN-SUFFIX,cdn.optimizely.com,🌍 国外媒体
  - DOMAIN-SUFFIX,cdn.registerdisney.go.com,🌍 国外媒体
  - DOMAIN-SUFFIX,cws.conviva.com,🌍 国外媒体
  - DOMAIN-SUFFIX,d9.flashtalking.com,🌍 国外媒体
  - DOMAIN-SUFFIX,disney-plus.net,🌍 国外媒体
  - DOMAIN-SUFFIX,disney-portal.my.onetrust.com,🌍 国外媒体
  - DOMAIN-SUFFIX,disney.demdex.net,🌍 国外媒体
  - DOMAIN-SUFFIX,disney.my.sentry.io,🌍 国外媒体
  - DOMAIN-SUFFIX,disneyplus.bn5x.net,🌍 国外媒体
  - DOMAIN-SUFFIX,disneyplus.com,🌍 国外媒体
  - DOMAIN-SUFFIX,disneyplus.com.ssl.sc.omtrdc.net,🌍 国外媒体
  - DOMAIN-SUFFIX,disneystreaming.com,🌍 国外媒体
  - DOMAIN-SUFFIX,dssott.com,🌍 国外媒体
  - DOMAIN-SUFFIX,execute-api.us-east-1.amazonaws.com,🌍 国外媒体
  - DOMAIN-SUFFIX,js-agent.newrelic.com,🌍 国外媒体
#   - USER-AGENT,encoreTVB*,🌍 国外媒体
  - DOMAIN,bcbolt446c5271-a.akamaihd.net,🌍 国外媒体
  - DOMAIN,content.jwplatform.com,🌍 国外媒体
  - DOMAIN,edge.api.brightcove.com,🌍 国外媒体
  - DOMAIN,videos-f.jwpsrv.com,🌍 国外媒体
  - DOMAIN-SUFFIX,encoretvb.com,🌍 国外媒体
#   - USER-AGENT,FOX%20NOW*,🌍 国外媒体
  - DOMAIN-SUFFIX,fox.com,🌍 国外媒体
  - DOMAIN-SUFFIX,foxdcg.com,🌍 国外媒体
  - DOMAIN-SUFFIX,uplynk.com,🌍 国外媒体
#   - USER-AGENT,HBO%20NOW*,🌍 国外媒体
#   - USER-AGENT,HBOMAX*,🌍 国外媒体
  - DOMAIN-SUFFIX,hbo.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbogo.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbomax.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbomaxcdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbonow.com,🌍 国外媒体
#   - USER-AGENT,HBO%20GO%20PROD*,🌍 国外媒体
  - DOMAIN-KEYWORD,.hbogoasia.,🌍 国外媒体
  - DOMAIN-KEYWORD,hbogoasia,🌍 国外媒体
  - DOMAIN,44wilhpljf.execute-api.ap-southeast-1.amazonaws.com,🌍 国外媒体
  - DOMAIN,bcbolthboa-a.akamaihd.net,🌍 国外媒体
  - DOMAIN,cf-images.ap-southeast-1.prod.boltdns.net,🌍 国外媒体
  - DOMAIN,dai3fd1oh325y.cloudfront.net,🌍 国外媒体
  - DOMAIN,hboasia1-i.akamaihd.net,🌍 国外媒体
  - DOMAIN,hboasia2-i.akamaihd.net,🌍 国外媒体
  - DOMAIN,hboasia3-i.akamaihd.net,🌍 国外媒体
  - DOMAIN,hboasia4-i.akamaihd.net,🌍 国外媒体
  - DOMAIN,hboasia5-i.akamaihd.net,🌍 国外媒体
  - DOMAIN,hboasialive.akamaized.net,🌍 国外媒体
  - DOMAIN,hbogoprod-vod.akamaized.net,🌍 国外媒体
  - DOMAIN,hbolb.onwardsmg.com,🌍 国外媒体
  - DOMAIN,hbounify-prod.evergent.com,🌍 国外媒体
  - DOMAIN,players.brightcove.net,🌍 国外媒体
  - DOMAIN,s3-ap-southeast-1.amazonaws.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hboasia.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbogoasia.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hbogoasia.hk,🌍 国外媒体
#   - USER-AGENT,HWTVMobile*,🌍 国外媒体
  - DOMAIN-SUFFIX,5itv.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,ocnttv.com,🌍 国外媒体
  - DOMAIN-SUFFIX,cws-hulu.conviva.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hulu.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hulu.hb.omtrdc.net,🌍 国外媒体
  - DOMAIN-SUFFIX,hulu.sc.omtrdc.net,🌍 国外媒体
  - DOMAIN-SUFFIX,huluad.com,🌍 国外媒体
  - DOMAIN-SUFFIX,huluim.com,🌍 国外媒体
  - DOMAIN-SUFFIX,hulustream.com,🌍 国外媒体
  - DOMAIN-SUFFIX,happyon.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,hjholdings.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,hulu.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,prod.hjholdings.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,streaks.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,yb.uncn.jp,🌍 国外媒体
#   - USER-AGENT,ITV_Player*,🌍 国外媒体
  - DOMAIN,itvpnpmobile-a.akamaihd.net,🌍 国外媒体
  - DOMAIN-SUFFIX,itv.com,🌍 国外媒体
  - DOMAIN-SUFFIX,itvstatic.com,🌍 国外媒体
#   - USER-AGENT,JOOX*,🌍 国外媒体
#   - USER-AGENT,WeMusic*,🌍 国外媒体
  - DOMAIN-KEYWORD,jooxweb-api,🌍 国外媒体
  - DOMAIN-SUFFIX,joox.com,🌍 国外媒体
  - DOMAIN-KEYWORD,japonx,🌍 国外媒体
  - DOMAIN-KEYWORD,japronx,🌍 国外媒体
  - DOMAIN-SUFFIX,japonx.com,🌍 国外媒体
  - DOMAIN-SUFFIX,japonx.net,🌍 国外媒体
  - DOMAIN-SUFFIX,japonx.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,japonx.vip,🌍 国外媒体
  - DOMAIN-SUFFIX,japronx.com,🌍 国外媒体
  - DOMAIN-SUFFIX,japronx.net,🌍 国外媒体
  - DOMAIN-SUFFIX,japronx.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,japronx.vip,🌍 国外媒体
  - DOMAIN-SUFFIX,kfs.io,🌍 国外媒体
  - DOMAIN-SUFFIX,kkbox.com,🌍 国外媒体
  - DOMAIN-SUFFIX,kkbox.com.tw,🌍 国外媒体
#   - USER-AGENT,KKTV*,🌍 国外媒体
#   - USER-AGENT,com.kktv.ios.kktv*,🌍 国外媒体
  - DOMAIN,kktv-theater.kk.stream,🌍 国外媒体
  - DOMAIN,theater-kktv.cdn.hinet.net,🌍 国外媒体
  - DOMAIN-SUFFIX,kktv.com.tw,🌍 国外媒体
  - DOMAIN-SUFFIX,kktv.me,🌍 国外媒体
  - DOMAIN,litvfreemobile-hichannel.cdn.hinet.net,🌍 国外媒体
  - DOMAIN-SUFFIX,litv.tv,🌍 国外媒体
#   - USER-AGENT,LINE%20TV*,🌍 国外媒体
#   - USER-AGENT,LINE*,🌍 国外媒体
  - DOMAIN,d3c7rimkq79yfu.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,d3c7rimkq79yfu.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,linetv.tw,🌍 国外媒体
  - DOMAIN-SUFFIX,profile.line-scdn.net,🌍 国外媒体
#   - USER-AGENT,My5*,🌍 国外媒体
  - DOMAIN,d349g9zuie06uo.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,channel5.com,🌍 国外媒体
  - DOMAIN-SUFFIX,my5.tv,🌍 国外媒体
#   - USER-AGENT,mytv*,🌍 国外媒体
  - DOMAIN-KEYWORD,nowtv100,🌍 国外媒体
  - DOMAIN-KEYWORD,rthklive,🌍 国外媒体
  - DOMAIN,mytvsuperlimited.hb.omtrdc.net,🌍 国外媒体
  - DOMAIN,mytvsuperlimited.sc.omtrdc.net,🌍 国外媒体
  - DOMAIN-SUFFIX,mytvsuper.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tvb.com,🌍 国外媒体
#   - USER-AGENT,Argo*,🌍 国外媒体
  - DOMAIN-KEYWORD,apiproxy-device-prod-nlb-,🌍 国外媒体
  - DOMAIN-KEYWORD,dualstack.apiproxy-,🌍 国外媒体
  - DOMAIN-KEYWORD,netflixdnstest,🌍 国外媒体
  - DOMAIN,netflix.com.edgesuite.net,🌍 国外媒体
  - DOMAIN-SUFFIX,fast.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflix.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflix.net,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest0.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest1.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest2.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest3.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest4.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest5.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest6.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest7.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest8.com,🌍 国外媒体
  - DOMAIN-SUFFIX,netflixdnstest9.com,🌍 国外媒体
  - DOMAIN-SUFFIX,nflxext.com,🌍 国外媒体
  - DOMAIN-SUFFIX,nflximg.com,🌍 国外媒体
  - DOMAIN-SUFFIX,nflximg.net,🌍 国外媒体
  - DOMAIN-SUFFIX,nflxso.net,🌍 国外媒体
  - DOMAIN-SUFFIX,nflxvideo.net,🌍 国外媒体
  - IP-CIDR,8.41.4.0/24,🌍 国外媒体,no-resolve
  - IP-CIDR,23.246.0.0/18,🌍 国外媒体,no-resolve
  - IP-CIDR,37.77.184.0/21,🌍 国外媒体,no-resolve
  - IP-CIDR,38.72.126.0/24,🌍 国外媒体,no-resolve
  - IP-CIDR,45.57.0.0/17,🌍 国外媒体,no-resolve
  - IP-CIDR,64.120.128.0/17,🌍 国外媒体,no-resolve
  - IP-CIDR,66.197.128.0/17,🌍 国外媒体,no-resolve
  - IP-CIDR,69.53.224.0/19,🌍 国外媒体,no-resolve
  - IP-CIDR,103.87.204.0/22,🌍 国外媒体,no-resolve
  - IP-CIDR,108.175.32.0/20,🌍 国外媒体,no-resolve
  - IP-CIDR,185.2.220.0/22,🌍 国外媒体,no-resolve
  - IP-CIDR,185.9.188.0/22,🌍 国外媒体,no-resolve
  - IP-CIDR,192.173.64.0/18,🌍 国外媒体,no-resolve
  - IP-CIDR,198.38.96.0/19,🌍 国外媒体,no-resolve
  - IP-CIDR,198.45.48.0/20,🌍 国外媒体,no-resolve
  - IP-CIDR,207.45.72.0/22,🌍 国外媒体,no-resolve
  - IP-CIDR,208.75.76.0/22,🌍 国外媒体,no-resolve
#   - USER-AGENT,Niconico*,🌍 国外媒体
  - DOMAIN-SUFFIX,dmc.nico,🌍 国外媒体
  - DOMAIN-SUFFIX,nicovideo.jp,🌍 国外媒体
  - DOMAIN-SUFFIX,nimg.jp,🌍 国外媒体
#   - USER-AGENT,PBS*,🌍 国外媒体
  - DOMAIN-SUFFIX,pbs.org,🌍 国外媒体
#   - USER-AGENT,Pandora*,🌍 国外媒体
  - DOMAIN-SUFFIX,pandora.com,🌍 国外媒体
  - DOMAIN-SUFFIX,phncdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,phprcdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,pornhub.com,🌍 国外媒体
  - DOMAIN-SUFFIX,pornhubpremium.com,🌍 国外媒体
  - DOMAIN-SUFFIX,qobuz.com,🌍 国外媒体
#   - USER-AGENT,SoundCloud*,🌍 国外媒体
  - DOMAIN-SUFFIX,p-cdn.us,🌍 国外媒体
  - DOMAIN-SUFFIX,sndcdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,soundcloud.com,🌍 国外媒体
#   - USER-AGENT,Spotify*,🌍 国外媒体
  - DOMAIN-KEYWORD,-spotify-com,🌍 国外媒体
  - DOMAIN-KEYWORD,spotify.com,🌍 国外媒体
  - DOMAIN-SUFFIX,pscdn.co,🌍 国外媒体
  - DOMAIN-SUFFIX,scdn.co,🌍 国外媒体
  - DOMAIN-SUFFIX,spoti.fi,🌍 国外媒体
  - DOMAIN-SUFFIX,spotify.com,🌍 国外媒体
  - DOMAIN-SUFFIX,spotifycdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,spotifycdn.net,🌍 国外媒体
#   - USER-AGENT,TIDAL*,🌍 国外媒体
  - DOMAIN-SUFFIX,tidal-cms.s3.amazonaws.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tidal.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tidalhifi.com,🌍 国外媒体
#   - USER-AGENT,TaiwanGood*,🌍 国外媒体
  - DOMAIN,hamifans.emome.net,🌍 国外媒体
  - DOMAIN-SUFFIX,skyking.com.tw,🌍 国外媒体
#   - USER-AGENT,TikTok*,🌍 国外媒体
  - DOMAIN-KEYWORD,tiktokcdn-,🌍 国外媒体
  - DOMAIN-SUFFIX,byteoversea.com,🌍 国外媒体
  - DOMAIN-SUFFIX,ibytedtos.com,🌍 国外媒体
  - DOMAIN-SUFFIX,ipstatp.com,🌍 国外媒体
  - DOMAIN-SUFFIX,muscdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,musical.ly,🌍 国外媒体
  - DOMAIN-SUFFIX,tik-tokapi.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tiktok.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tiktokcdn.com,🌍 国外媒体
  - DOMAIN-SUFFIX,tiktokv.com,🌍 国外媒体
  - DOMAIN-KEYWORD,ttvnw,🌍 国外媒体
  - DOMAIN-SUFFIX,ext-twitch.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,jtvnw.net,🌍 国外媒体
  - DOMAIN-SUFFIX,ttvnw.net,🌍 国外媒体
  - DOMAIN-SUFFIX,twitch-ext.rootonline.de,🌍 国外媒体
  - DOMAIN-SUFFIX,twitch.tv,🌍 国外媒体
  - DOMAIN-SUFFIX,twitchcdn.net,🌍 国外媒体
#   - USER-AGENT,Viu*,🌍 国外媒体
  - PROCESS-NAME,com.viu.pad,🌍 国外媒体
  - PROCESS-NAME,com.viu.phone,🌍 国外媒体
  - PROCESS-NAME,com.vuclip.viu,🌍 国外媒体
  - DOMAIN,api.viu.now.com,🌍 国外媒体
  - DOMAIN,d1k2us671qcoau.cloudfront.net,🌍 国外媒体
  - DOMAIN,d2anahhhmp1ffz.cloudfront.net,🌍 国外媒体
  - DOMAIN,dfp6rglgjqszk.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,cognito-identity.us-east-1.amazonaws.com,🌍 国外媒体
  - DOMAIN-SUFFIX,d1k2us671qcoau.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,d2anahhhmp1ffz.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,dfp6rglgjqszk.cloudfront.net,🌍 国外媒体
  - DOMAIN-SUFFIX,mobileanalytics.us-east-1.amazonaws.com,🌍 国外媒体
  - DOMAIN-SUFFIX,viu.com,🌍 国外媒体
  - DOMAIN-SUFFIX,viu.now.com,🌍 国外媒体
  - DOMAIN-SUFFIX,viu.tv,🌍 国外媒体
#   - USER-AGENT,*youtube*,🌍 国外媒体
#   - USER-AGENT,YouTube*,🌍 国外媒体
#   - USER-AGENT,com.google.ios.youtube*,🌍 国外媒体
  - DOMAIN-KEYWORD,youtube,🌍 国外媒体
  - DOMAIN,youtubei.googleapis.com,🌍 国外媒体
  - DOMAIN,yt3.ggpht.com,🌍 国外媒体
  - DOMAIN-SUFFIX,googlevideo.com,🌍 国外媒体
  - DOMAIN-SUFFIX,gvt2.com,🌍 国外媒体
  - DOMAIN-SUFFIX,withyoutube.com,🌍 国外媒体
  - DOMAIN-SUFFIX,youtu.be,🌍 国外媒体
  - DOMAIN-SUFFIX,youtube-nocookie.com,🌍 国外媒体
  - DOMAIN-SUFFIX,youtube.com,🌍 国外媒体
  - DOMAIN-SUFFIX,youtubeeducation.com,🌍 国外媒体
  - DOMAIN-SUFFIX,youtubegaming.com,🌍 国外媒体
  - DOMAIN-SUFFIX,youtubekids.com,🌍 国外媒体
  - DOMAIN-SUFFIX,yt.be,🌍 国外媒体
  - DOMAIN-SUFFIX,ytimg.com,🌍 国外媒体
#   - USER-AGENT,*YouTubeMusic*,🌍 国外媒体
#   - USER-AGENT,*com.google.ios.youtubemusic*,🌍 国外媒体
#   - USER-AGENT,YouTubeMusic*,🌍 国外媒体
#   - USER-AGENT,com.google.ios.youtubemusic*,🌍 国外媒体
  - DOMAIN,music.youtube.com,🌍 国外媒体
# Telegram
#PROCESS-NAME,Telegram.exe
#PROCESS-NAME,org.telegram.messenger
  - DOMAIN-SUFFIX,t.me,📲 电报信息
  - DOMAIN-SUFFIX,tdesktop.com,📲 电报信息
  - DOMAIN-SUFFIX,telegra.ph,📲 电报信息
  - DOMAIN-SUFFIX,telegram.me,📲 电报信息
  - DOMAIN-SUFFIX,telegram.org,📲 电报信息
  - DOMAIN-SUFFIX,telesco.pe,📲 电报信息
  - IP-CIDR,91.108.0.0/16,📲 电报信息,no-resolve
  - IP-CIDR,109.239.140.0/24,📲 电报信息,no-resolve
  - IP-CIDR,149.154.160.0/20,📲 电报信息,no-resolve
  - IP-CIDR6,2001:67c:4e8::/48,📲 电报信息,no-resolve
  - IP-CIDR6,2001:b28:f23d::/48,📲 电报信息,no-resolve
  - IP-CIDR6,2001:b28:f23f::/48,📲 电报信息,no-resolve
# 长风网站，自动注入
  - DOMAIN-SUFFIX,v2rayse.com,🚀 节点选择
  - DOMAIN-SUFFIX,cff.pw,🚀 节点选择
  - DOMAIN-SUFFIX,vpnse.org,🚀 节点选择
  - DOMAIN-SUFFIX,cfmem.com,🚀 节点选择
# 代理列表
# MyList && Other
# 国外域名
# 国外域名关键字
# Top Blocked Sites
# Amazon
# BBC
# Developer 开发者常用国外网站、镜像和论坛
# Discord
# Facebook
# Github
# Google
# GoogleCNProxyIP 谷歌中国服务 services.googleapis.cn
# Instagram
# Kakao Talk
# Line
# OneDrive
#DOMAIN-SUFFIX,aria.microsoft.com
# Porn
# Pixiv
# Spark
# Steam
# TapTap
# Twitch
# Twitter
# Telegram
# TeraBox
# Whatsapp
# Wikipedia 维基相关域名
#飞流直播
#华文电视
# VikACG
  - DOMAIN-SUFFIX,1password.com,🚀 节点选择
  - DOMAIN-SUFFIX,adguard.org,🚀 节点选择
  - DOMAIN-SUFFIX,bit.no.com,🚀 节点选择
  - DOMAIN-SUFFIX,btlibrary.me,🚀 节点选择
  - DOMAIN-SUFFIX,chat.openai.com,🚀 节点选择
  - DOMAIN-SUFFIX,cloudcone.com,🚀 节点选择
  - DOMAIN-SUFFIX,dubox.com,🚀 节点选择
  - DOMAIN-SUFFIX,gameloft.com,🚀 节点选择
  - DOMAIN-SUFFIX,garena.com,🚀 节点选择
  - DOMAIN-SUFFIX,hoyolab.com,🚀 节点选择
  - DOMAIN-SUFFIX,inoreader.com,🚀 节点选择
  - DOMAIN-SUFFIX,ip138.com,🚀 节点选择
  - DOMAIN-SUFFIX,linkedin.com,🚀 节点选择
  - DOMAIN-SUFFIX,myteamspeak.com,🚀 节点选择
  - DOMAIN-SUFFIX,notion.so,🚀 节点选择
  - DOMAIN-SUFFIX,openai.com,🚀 节点选择
  - DOMAIN-SUFFIX,ping.pe,🚀 节点选择
  - DOMAIN-SUFFIX,reddit.com,🚀 节点选择
  - DOMAIN-SUFFIX,teddysun.com,🚀 节点选择
  - DOMAIN-SUFFIX,tumbex.com,🚀 节点选择
  - DOMAIN-SUFFIX,twdvd.com,🚀 节点选择
  - DOMAIN-SUFFIX,unsplash.com,🚀 节点选择
  - DOMAIN-SUFFIX,eu,🚀 节点选择
  - DOMAIN-SUFFIX,hk,🚀 节点选择
  - DOMAIN-SUFFIX,jp,🚀 节点选择
  - DOMAIN-SUFFIX,kr,🚀 节点选择
  - DOMAIN-SUFFIX,sg,🚀 节点选择
  - DOMAIN-SUFFIX,tw,🚀 节点选择
  - DOMAIN-SUFFIX,uk,🚀 节点选择
  - DOMAIN-SUFFIX,us,🚀 节点选择
  - DOMAIN-KEYWORD,1e100,🚀 节点选择
  - DOMAIN-KEYWORD,abema,🚀 节点选择
  - DOMAIN-KEYWORD,appledaily,🚀 节点选择
  - DOMAIN-KEYWORD,avtb,🚀 节点选择
  - DOMAIN-KEYWORD,beetalk,🚀 节点选择
  - DOMAIN-KEYWORD,blogspot,🚀 节点选择
  - DOMAIN-KEYWORD,dropbox,🚀 节点选择
  - DOMAIN-KEYWORD,facebook,🚀 节点选择
  - DOMAIN-KEYWORD,fbcdn,🚀 节点选择
  - DOMAIN-KEYWORD,github,🚀 节点选择
  - DOMAIN-KEYWORD,gmail,🚀 节点选择
  - DOMAIN-KEYWORD,google,🚀 节点选择
  - DOMAIN-KEYWORD,instagram,🚀 节点选择
  - DOMAIN-KEYWORD,porn,🚀 节点选择
  - DOMAIN-KEYWORD,sci-hub,🚀 节点选择
  - DOMAIN-KEYWORD,spotify,🚀 节点选择
  - DOMAIN-KEYWORD,telegram,🚀 节点选择
  - DOMAIN-KEYWORD,twitter,🚀 节点选择
  - DOMAIN-KEYWORD,whatsapp,🚀 节点选择
  - DOMAIN-KEYWORD,youtube,🚀 节点选择
  - DOMAIN-SUFFIX,4sqi.net,🚀 节点选择
  - DOMAIN-SUFFIX,a248.e.akamai.net,🚀 节点选择
  - DOMAIN-SUFFIX,adobedtm.com,🚀 节点选择
  - DOMAIN-SUFFIX,ampproject.org,🚀 节点选择
  - DOMAIN-SUFFIX,android.com,🚀 节点选择
  - DOMAIN-SUFFIX,aolcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,apkmirror.com,🚀 节点选择
  - DOMAIN-SUFFIX,apkpure.com,🚀 节点选择
  - DOMAIN-SUFFIX,app-measurement.com,🚀 节点选择
  - DOMAIN-SUFFIX,appspot.com,🚀 节点选择
  - DOMAIN-SUFFIX,archive.org,🚀 节点选择
  - DOMAIN-SUFFIX,armorgames.com,🚀 节点选择
  - DOMAIN-SUFFIX,aspnetcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,awsstatic.com,🚀 节点选择
  - DOMAIN-SUFFIX,azureedge.net,🚀 节点选择
  - DOMAIN-SUFFIX,azurewebsites.net,🚀 节点选择
  - DOMAIN-SUFFIX,bandwagonhost.com,🚀 节点选择
  - DOMAIN-SUFFIX,bing.com,🚀 节点选择
  - DOMAIN-SUFFIX,bkrtx.com,🚀 节点选择
  - DOMAIN-SUFFIX,blogcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,blogger.com,🚀 节点选择
  - DOMAIN-SUFFIX,blogsmithmedia.com,🚀 节点选择
  - DOMAIN-SUFFIX,blogspot.com,🚀 节点选择
  - DOMAIN-SUFFIX,blogspot.hk,🚀 节点选择
  - DOMAIN-SUFFIX,blogspot.jp,🚀 节点选择
  - DOMAIN-SUFFIX,bloomberg.cn,🚀 节点选择
  - DOMAIN-SUFFIX,bloomberg.com,🚀 节点选择
  - DOMAIN-SUFFIX,box.com,🚀 节点选择
  - DOMAIN-SUFFIX,cachefly.net,🚀 节点选择
  - DOMAIN-SUFFIX,cdnst.net,🚀 节点选择
  - DOMAIN-SUFFIX,cloudfront.net,🚀 节点选择
  - DOMAIN-SUFFIX,comodoca.com,🚀 节点选择
  - DOMAIN-SUFFIX,daum.net,🚀 节点选择
  - DOMAIN-SUFFIX,deskconnect.com,🚀 节点选择
  - DOMAIN-SUFFIX,disqus.com,🚀 节点选择
  - DOMAIN-SUFFIX,disquscdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,dropbox.com,🚀 节点选择
  - DOMAIN-SUFFIX,dropboxapi.com,🚀 节点选择
  - DOMAIN-SUFFIX,dropboxstatic.com,🚀 节点选择
  - DOMAIN-SUFFIX,dropboxusercontent.com,🚀 节点选择
  - DOMAIN-SUFFIX,duckduckgo.com,🚀 节点选择
  - DOMAIN-SUFFIX,edgecastcdn.net,🚀 节点选择
  - DOMAIN-SUFFIX,edgekey.net,🚀 节点选择
  - DOMAIN-SUFFIX,edgesuite.net,🚀 节点选择
  - DOMAIN-SUFFIX,eurekavpt.com,🚀 节点选择
  - DOMAIN-SUFFIX,fastmail.com,🚀 节点选择
  - DOMAIN-SUFFIX,firebaseio.com,🚀 节点选择
  - DOMAIN-SUFFIX,flickr.com,🚀 节点选择
  - DOMAIN-SUFFIX,flipboard.com,🚀 节点选择
  - DOMAIN-SUFFIX,gfx.ms,🚀 节点选择
  - DOMAIN-SUFFIX,gongm.in,🚀 节点选择
  - DOMAIN-SUFFIX,hulu.com,🚀 节点选择
  - DOMAIN-SUFFIX,id.heroku.com,🚀 节点选择
  - DOMAIN-SUFFIX,io.io,🚀 节点选择
  - DOMAIN-SUFFIX,issuu.com,🚀 节点选择
  - DOMAIN-SUFFIX,ixquick.com,🚀 节点选择
  - DOMAIN-SUFFIX,jtvnw.net,🚀 节点选择
  - DOMAIN-SUFFIX,kat.cr,🚀 节点选择
  - DOMAIN-SUFFIX,kik.com,🚀 节点选择
  - DOMAIN-SUFFIX,kobo.com,🚀 节点选择
  - DOMAIN-SUFFIX,kobobooks.com,🚀 节点选择
  - DOMAIN-SUFFIX,licdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,live.net,🚀 节点选择
  - DOMAIN-SUFFIX,livefilestore.com,🚀 节点选择
  - DOMAIN-SUFFIX,llnwd.net,🚀 节点选择
  - DOMAIN-SUFFIX,macrumors.com,🚀 节点选择
  - DOMAIN-SUFFIX,medium.com,🚀 节点选择
  - DOMAIN-SUFFIX,mega.nz,🚀 节点选择
  - DOMAIN-SUFFIX,megaupload.com,🚀 节点选择
  - DOMAIN-SUFFIX,messenger.com,🚀 节点选择
  - DOMAIN-SUFFIX,netdna-cdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,nintendo.net,🚀 节点选择
  - DOMAIN-SUFFIX,nsstatic.net,🚀 节点选择
  - DOMAIN-SUFFIX,nytstyle.com,🚀 节点选择
  - DOMAIN-SUFFIX,overcast.fm,🚀 节点选择
  - DOMAIN-SUFFIX,openvpn.net,🚀 节点选择
  - DOMAIN-SUFFIX,periscope.tv,🚀 节点选择
  - DOMAIN-SUFFIX,pinimg.com,🚀 节点选择
  - DOMAIN-SUFFIX,pinterest.com,🚀 节点选择
  - DOMAIN-SUFFIX,potato.im,🚀 节点选择
  - DOMAIN-SUFFIX,prfct.co,🚀 节点选择
  - DOMAIN-SUFFIX,pscp.tv,🚀 节点选择
  - DOMAIN-SUFFIX,quora.com,🚀 节点选择
  - DOMAIN-SUFFIX,resilio.com,🚀 节点选择
  - DOMAIN-SUFFIX,sfx.ms,🚀 节点选择
  - DOMAIN-SUFFIX,shadowsocks.org,🚀 节点选择
  - DOMAIN-SUFFIX,slack-edge.com,🚀 节点选择
  - DOMAIN-SUFFIX,smartdnsproxy.com,🚀 节点选择
  - DOMAIN-SUFFIX,sndcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,soundcloud.com,🚀 节点选择
  - DOMAIN-SUFFIX,startpage.com,🚀 节点选择
  - DOMAIN-SUFFIX,staticflickr.com,🚀 节点选择
  - DOMAIN-SUFFIX,symauth.com,🚀 节点选择
  - DOMAIN-SUFFIX,symcb.com,🚀 节点选择
  - DOMAIN-SUFFIX,symcd.com,🚀 节点选择
  - DOMAIN-SUFFIX,textnow.com,🚀 节点选择
  - DOMAIN-SUFFIX,textnow.me,🚀 节点选择
  - DOMAIN-SUFFIX,thefacebook.com,🚀 节点选择
  - DOMAIN-SUFFIX,thepiratebay.org,🚀 节点选择
  - DOMAIN-SUFFIX,torproject.org,🚀 节点选择
  - DOMAIN-SUFFIX,trustasiassl.com,🚀 节点选择
  - DOMAIN-SUFFIX,tumblr.co,🚀 节点选择
  - DOMAIN-SUFFIX,tumblr.com,🚀 节点选择
  - DOMAIN-SUFFIX,tvb.com,🚀 节点选择
  - DOMAIN-SUFFIX,txmblr.com,🚀 节点选择
  - DOMAIN-SUFFIX,v2ex.com,🚀 节点选择
  - DOMAIN-SUFFIX,vimeo.com,🚀 节点选择
  - DOMAIN-SUFFIX,vine.co,🚀 节点选择
  - DOMAIN-SUFFIX,vox-cdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,amazon.co.jp,🚀 节点选择
  - DOMAIN-SUFFIX,amazon.com,🚀 节点选择
  - DOMAIN-SUFFIX,amazonaws.com,🚀 节点选择
  - IP-CIDR,13.32.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,13.35.0.0/17,🚀 节点选择,no-resolve
  - IP-CIDR,18.184.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,18.194.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,18.208.0.0/13,🚀 节点选择,no-resolve
  - IP-CIDR,18.232.0.0/14,🚀 节点选择,no-resolve
  - IP-CIDR,52.58.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,52.74.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,52.77.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,52.84.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,52.200.0.0/13,🚀 节点选择,no-resolve
  - IP-CIDR,54.93.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,54.156.0.0/14,🚀 节点选择,no-resolve
  - IP-CIDR,54.226.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,54.230.156.0/22,🚀 节点选择,no-resolve
  - DOMAIN-KEYWORD,uk-live,🚀 节点选择
  - DOMAIN-SUFFIX,bbc.co,🚀 节点选择
  - DOMAIN-SUFFIX,bbc.com,🚀 节点选择
  - DOMAIN-SUFFIX,apache.org,🚀 节点选择
  - DOMAIN-SUFFIX,docker.com,🚀 节点选择
  - DOMAIN-SUFFIX,elastic.co,🚀 节点选择
  - DOMAIN-SUFFIX,elastic.com,🚀 节点选择
  - DOMAIN-SUFFIX,gcr.io,🚀 节点选择
  - DOMAIN-SUFFIX,gitlab.com,🚀 节点选择
  - DOMAIN-SUFFIX,gitlab.io,🚀 节点选择
  - DOMAIN-SUFFIX,jitpack.io,🚀 节点选择
  - DOMAIN-SUFFIX,maven.org,🚀 节点选择
  - DOMAIN-SUFFIX,medium.com,🚀 节点选择
  - DOMAIN-SUFFIX,mvnrepository.com,🚀 节点选择
  - DOMAIN-SUFFIX,quay.io,🚀 节点选择
  - DOMAIN-SUFFIX,reddit.com,🚀 节点选择
  - DOMAIN-SUFFIX,redhat.com,🚀 节点选择
  - DOMAIN-SUFFIX,sonatype.org,🚀 节点选择
  - DOMAIN-SUFFIX,sourcegraph.com,🚀 节点选择
  - DOMAIN-SUFFIX,spring.io,🚀 节点选择
  - DOMAIN-SUFFIX,spring.net,🚀 节点选择
  - DOMAIN-SUFFIX,stackoverflow.com,🚀 节点选择
  - DOMAIN-SUFFIX,discord.co,🚀 节点选择
  - DOMAIN-SUFFIX,discord.com,🚀 节点选择
  - DOMAIN-SUFFIX,discord.gg,🚀 节点选择
  - DOMAIN-SUFFIX,discord.media,🚀 节点选择
  - DOMAIN-SUFFIX,discordapp.com,🚀 节点选择
  - DOMAIN-SUFFIX,discordapp.net,🚀 节点选择
  - DOMAIN-SUFFIX,facebook.com,🚀 节点选择
  - DOMAIN-SUFFIX,fb.com,🚀 节点选择
  - DOMAIN-SUFFIX,fb.me,🚀 节点选择
  - DOMAIN-SUFFIX,fbcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,fbcdn.net,🚀 节点选择
  - IP-CIDR,31.13.24.0/21,🚀 节点选择,no-resolve
  - IP-CIDR,31.13.64.0/18,🚀 节点选择,no-resolve
  - IP-CIDR,45.64.40.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,66.220.144.0/20,🚀 节点选择,no-resolve
  - IP-CIDR,69.63.176.0/20,🚀 节点选择,no-resolve
  - IP-CIDR,69.171.224.0/19,🚀 节点选择,no-resolve
  - IP-CIDR,74.119.76.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,103.4.96.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,129.134.0.0/17,🚀 节点选择,no-resolve
  - IP-CIDR,157.240.0.0/17,🚀 节点选择,no-resolve
  - IP-CIDR,173.252.64.0/18,🚀 节点选择,no-resolve
  - IP-CIDR,179.60.192.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,185.60.216.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,204.15.20.0/22,🚀 节点选择,no-resolve
  - DOMAIN-SUFFIX,github.com,🚀 节点选择
  - DOMAIN-SUFFIX,github.io,🚀 节点选择
  - DOMAIN-SUFFIX,githubapp.com,🚀 节点选择
  - DOMAIN-SUFFIX,githubassets.com,🚀 节点选择
  - DOMAIN-SUFFIX,githubusercontent.com,🚀 节点选择
  - DOMAIN-SUFFIX,1e100.net,🚀 节点选择
  - DOMAIN-SUFFIX,2mdn.net,🚀 节点选择
  - DOMAIN-SUFFIX,app-measurement.net,🚀 节点选择
  - DOMAIN-SUFFIX,g.co,🚀 节点选择
  - DOMAIN-SUFFIX,ggpht.com,🚀 节点选择
  - DOMAIN-SUFFIX,goo.gl,🚀 节点选择
  - DOMAIN-SUFFIX,googleapis.cn,🚀 节点选择
  - DOMAIN-SUFFIX,googleapis.com,🚀 节点选择
  - DOMAIN-SUFFIX,gstatic.cn,🚀 节点选择
  - DOMAIN-SUFFIX,gstatic.com,🚀 节点选择
  - DOMAIN-SUFFIX,gvt0.com,🚀 节点选择
  - DOMAIN-SUFFIX,gvt1.com,🚀 节点选择
  - DOMAIN-SUFFIX,gvt2.com,🚀 节点选择
  - DOMAIN-SUFFIX,gvt3.com,🚀 节点选择
  - DOMAIN-SUFFIX,xn--ngstr-lra8j.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtu.be,🚀 节点选择
  - DOMAIN-SUFFIX,youtube-nocookie.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,yt.be,🚀 节点选择
  - DOMAIN-SUFFIX,ytimg.com,🚀 节点选择
  - IP-CIDR,74.125.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,173.194.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,120.232.181.162/32,🚀 节点选择,no-resolve
  - IP-CIDR,120.241.147.226/32,🚀 节点选择,no-resolve
  - IP-CIDR,120.253.253.226/32,🚀 节点选择,no-resolve
  - IP-CIDR,120.253.255.162/32,🚀 节点选择,no-resolve
  - IP-CIDR,120.253.255.34/32,🚀 节点选择,no-resolve
  - IP-CIDR,120.253.255.98/32,🚀 节点选择,no-resolve
  - IP-CIDR,180.163.150.162/32,🚀 节点选择,no-resolve
  - IP-CIDR,180.163.150.34/32,🚀 节点选择,no-resolve
  - IP-CIDR,180.163.151.162/32,🚀 节点选择,no-resolve
  - IP-CIDR,180.163.151.34/32,🚀 节点选择,no-resolve
  - IP-CIDR,203.208.39.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,203.208.40.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,203.208.41.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,203.208.43.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,203.208.50.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,220.181.174.162/32,🚀 节点选择,no-resolve
  - IP-CIDR,220.181.174.226/32,🚀 节点选择,no-resolve
  - IP-CIDR,220.181.174.34/32,🚀 节点选择,no-resolve
  - DOMAIN-SUFFIX,cdninstagram.com,🚀 节点选择
  - DOMAIN-SUFFIX,instagram.com,🚀 节点选择
  - DOMAIN-SUFFIX,instagr.am,🚀 节点选择
  - DOMAIN-SUFFIX,kakao.com,🚀 节点选择
  - DOMAIN-SUFFIX,kakao.co.kr,🚀 节点选择
  - DOMAIN-SUFFIX,kakaocdn.net,🚀 节点选择
  - IP-CIDR,1.201.0.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,27.0.236.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,103.27.148.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,103.246.56.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,110.76.140.0/22,🚀 节点选择,no-resolve
  - IP-CIDR,113.61.104.0/22,🚀 节点选择,no-resolve
  - DOMAIN-SUFFIX,lin.ee,🚀 节点选择
  - DOMAIN-SUFFIX,line-apps.com,🚀 节点选择
  - DOMAIN-SUFFIX,line-cdn.net,🚀 节点选择
  - DOMAIN-SUFFIX,line-scdn.net,🚀 节点选择
  - DOMAIN-SUFFIX,line.me,🚀 节点选择
  - DOMAIN-SUFFIX,line.naver.jp,🚀 节点选择
  - DOMAIN-SUFFIX,nhncorp.jp,🚀 节点选择
  - IP-CIDR,103.2.28.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,103.2.30.0/23,🚀 节点选择,no-resolve
  - IP-CIDR,119.235.224.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,119.235.232.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,119.235.235.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,119.235.236.0/23,🚀 节点选择,no-resolve
  - IP-CIDR,147.92.128.0/17,🚀 节点选择,no-resolve
  - IP-CIDR,203.104.128.0/19,🚀 节点选择,no-resolve
  - DOMAIN-KEYWORD,1drv,🚀 节点选择
  - DOMAIN-KEYWORD,onedrive,🚀 节点选择
  - DOMAIN-KEYWORD,skydrive,🚀 节点选择
  - DOMAIN-SUFFIX,livefilestore.com,🚀 节点选择
  - DOMAIN-SUFFIX,oneclient.sfx.ms,🚀 节点选择
  - DOMAIN-SUFFIX,onedrive.com,🚀 节点选择
  - DOMAIN-SUFFIX,onedrive.live.com,🚀 节点选择
  - DOMAIN-SUFFIX,photos.live.com,🚀 节点选择
  - DOMAIN-SUFFIX,skydrive.wns.windows.com,🚀 节点选择
  - DOMAIN-SUFFIX,spoprod-a.akamaihd.net,🚀 节点选择
  - DOMAIN-SUFFIX,storage.live.com,🚀 节点选择
  - DOMAIN-SUFFIX,storage.msn.com,🚀 节点选择
  - DOMAIN-KEYWORD,porn,🚀 节点选择
  - DOMAIN-SUFFIX,8teenxxx.com,🚀 节点选择
  - DOMAIN-SUFFIX,ahcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,bcvcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,bongacams.com,🚀 节点选择
  - DOMAIN-SUFFIX,chaturbate.com,🚀 节点选择
  - DOMAIN-SUFFIX,dditscdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,livejasmin.com,🚀 节点选择
  - DOMAIN-SUFFIX,phncdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,phprcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,pornhub.com,🚀 节点选择
  - DOMAIN-SUFFIX,pornhubpremium.com,🚀 节点选择
  - DOMAIN-SUFFIX,rdtcdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,redtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,sb-cd.com,🚀 节点选择
  - DOMAIN-SUFFIX,spankbang.com,🚀 节点选择
  - DOMAIN-SUFFIX,t66y.com,🚀 节点选择
  - DOMAIN-SUFFIX,xhamster.com,🚀 节点选择
  - DOMAIN-SUFFIX,xnxx-cdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,xnxx.com,🚀 节点选择
  - DOMAIN-SUFFIX,xvideos-cdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,xvideos.com,🚀 节点选择
  - DOMAIN-SUFFIX,ypncdn.com,🚀 节点选择
  - DOMAIN-SUFFIX,pixiv.net,🚀 节点选择
  - DOMAIN-SUFFIX,pximg.net,🚀 节点选择
  - DOMAIN-SUFFIX,amplitude.com,🚀 节点选择
  - DOMAIN-SUFFIX,firebaseio.com,🚀 节点选择
  - DOMAIN-SUFFIX,hockeyapp.net,🚀 节点选择
  - DOMAIN-SUFFIX,readdle.com,🚀 节点选择
  - DOMAIN-SUFFIX,smartmailcloud.com,🚀 节点选择
  - DOMAIN-SUFFIX,fanatical.com,🚀 节点选择
  - DOMAIN-SUFFIX,humblebundle.com,🚀 节点选择
  - DOMAIN-SUFFIX,underlords.com,🚀 节点选择
  - DOMAIN-SUFFIX,valvesoftware.com,🚀 节点选择
  - DOMAIN-SUFFIX,playartifact.com,🚀 节点选择
  - DOMAIN-SUFFIX,steam-chat.com,🚀 节点选择
  - DOMAIN-SUFFIX,steamcommunity.com,🚀 节点选择
  - DOMAIN-SUFFIX,steamgames.com,🚀 节点选择
  - DOMAIN-SUFFIX,steampowered.com,🚀 节点选择
  - DOMAIN-SUFFIX,steamserver.net,🚀 节点选择
  - DOMAIN-SUFFIX,steamstatic.com,🚀 节点选择
  - DOMAIN-SUFFIX,steamstat.us,🚀 节点选择
  - DOMAIN,steambroadcast.akamaized.net,🚀 节点选择
  - DOMAIN,steamcdn-a.akamaihd.net,🚀 节点选择
  - DOMAIN,steamcommunity-a.akamaihd.net,🚀 节点选择
  - DOMAIN,steamstore-a.akamaihd.net,🚀 节点选择
  - DOMAIN,steamusercontent-a.akamaihd.net,🚀 节点选择
  - DOMAIN,steamuserimages-a.akamaihd.net,🚀 节点选择
  - DOMAIN,steampipe.akamaized.net,🚀 节点选择
  - DOMAIN-SUFFIX,tap.io,🚀 节点选择
  - DOMAIN-SUFFIX,taptap.tw,🚀 节点选择
  - DOMAIN-SUFFIX,twitch.tv,🚀 节点选择
  - DOMAIN-SUFFIX,ttvnw.net,🚀 节点选择
  - DOMAIN-SUFFIX,jtvnw.net,🚀 节点选择
  - DOMAIN-KEYWORD,ttvnw,🚀 节点选择
  - DOMAIN-SUFFIX,t.co,🚀 节点选择
  - DOMAIN-SUFFIX,twimg.co,🚀 节点选择
  - DOMAIN-SUFFIX,twimg.com,🚀 节点选择
  - DOMAIN-SUFFIX,twimg.org,🚀 节点选择
  - DOMAIN-SUFFIX,t.me,🚀 节点选择
  - DOMAIN-SUFFIX,tdesktop.com,🚀 节点选择
  - DOMAIN-SUFFIX,telegra.ph,🚀 节点选择
  - DOMAIN-SUFFIX,telegram.me,🚀 节点选择
  - DOMAIN-SUFFIX,telegram.org,🚀 节点选择
  - DOMAIN-SUFFIX,telesco.pe,🚀 节点选择
  - IP-CIDR,91.108.0.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,109.239.140.0/24,🚀 节点选择,no-resolve
  - IP-CIDR,149.154.160.0/20,🚀 节点选择,no-resolve
  - IP-CIDR6,2001:67c:4e8::/48,🚀 节点选择,no-resolve
  - IP-CIDR6,2001:b28:f23d::/48,🚀 节点选择,no-resolve
  - IP-CIDR6,2001:b28:f23f::/48,🚀 节点选择,no-resolve
  - DOMAIN-SUFFIX,terabox.com,🚀 节点选择
  - DOMAIN-SUFFIX,teraboxcdn.com,🚀 节点选择
  - IP-CIDR,18.194.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,34.224.0.0/12,🚀 节点选择,no-resolve
  - IP-CIDR,54.242.0.0/15,🚀 节点选择,no-resolve
  - IP-CIDR,50.22.198.204/30,🚀 节点选择,no-resolve
  - IP-CIDR,208.43.122.128/27,🚀 节点选择,no-resolve
  - IP-CIDR,108.168.174.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,173.192.231.32/27,🚀 节点选择,no-resolve
  - IP-CIDR,158.85.5.192/27,🚀 节点选择,no-resolve
  - IP-CIDR,174.37.243.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,158.85.46.128/27,🚀 节点选择,no-resolve
  - IP-CIDR,173.192.222.160/27,🚀 节点选择,no-resolve
  - IP-CIDR,184.173.128.0/17,🚀 节点选择,no-resolve
  - IP-CIDR,158.85.224.160/27,🚀 节点选择,no-resolve
  - IP-CIDR,75.126.150.0/16,🚀 节点选择,no-resolve
  - IP-CIDR,69.171.235.0/16,🚀 节点选择,no-resolve
  - DOMAIN-SUFFIX,mediawiki.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikibooks.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikidata.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikileaks.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikimedia.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikinews.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikipedia.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikiquote.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikisource.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikiversity.org,🚀 节点选择
  - DOMAIN-SUFFIX,wikivoyage.org,🚀 节点选择
  - DOMAIN-SUFFIX,wiktionary.org,🚀 节点选择
  - DOMAIN-SUFFIX,neulion.com,🚀 节点选择
  - DOMAIN-SUFFIX,icntv.xyz,🚀 节点选择
  - DOMAIN-SUFFIX,flzbcdn.xyz,🚀 节点选择
  - DOMAIN-SUFFIX,ocnttv.com,🚀 节点选择
  - DOMAIN-SUFFIX,vikacg.com,🚀 节点选择
  - DOMAIN-SUFFIX,picjs.xyz,🚀 节点选择
# 直连列表
# MyList
# CN域名直连(中国|公司|网络)
# 中国国内常见域名关键词直连
# 360
# 4399
# 58
# Alibaba
# Baidu
# Bilibili
# Blizzard
# ByteDance
# CCTV
# ChinaNet
# DiDi
# Douyu 斗鱼
# Epic
# HuaWei
# Iflytek 科大讯飞
# Iqiyi
# JD
# Kingsoft
# Kuaishou 快手
# Meitu
# LeTV 乐视
# MGTV 芒果TV
# MI
# NetEase
# PPTV、PPLive
# PDD 拼多多
# Sina
# Sohu Sogo
# Sony
# SteamCN
# Tencent
# Vip 唯品会
# Ximalaya 喜马拉雅
# Xunlei 迅雷
# YYeTs 人人影视
# Private Tracker
# TeamViewer
# Public Direct CDN 公共直连
#DOMAIN-SUFFIX,ajax.aspnetcdn.com
#DOMAIN-SUFFIX,ajax.cloudflare.com
#DOMAIN-SUFFIX,cdnjs.cloudflare.com
#DOMAIN-SUFFIX,code.jquery.com
# AccelerateDirectSites
  - DOMAIN-SUFFIX,13th.tech,🎯 全球直连
  - DOMAIN-SUFFIX,423down.com,🎯 全球直连
  - DOMAIN-SUFFIX,bokecc.com,🎯 全球直连
  - DOMAIN-SUFFIX,chaipip.com,🎯 全球直连
  - DOMAIN-SUFFIX,chinaplay.store,🎯 全球直连
  - DOMAIN-SUFFIX,hrtsea.com,🎯 全球直连
  - DOMAIN-SUFFIX,kaikeba.com,🎯 全球直连
  - DOMAIN-SUFFIX,laomo.me,🎯 全球直连
  - DOMAIN-SUFFIX,mpyit.com,🎯 全球直连
  - DOMAIN-SUFFIX,msftconnecttest.com,🎯 全球直连
  - DOMAIN-SUFFIX,msftncsi.com,🎯 全球直连
  - DOMAIN-SUFFIX,qupu123.com,🎯 全球直连
  - DOMAIN-SUFFIX,pdfwifi.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhenguanyu.biz,🎯 全球直连
  - DOMAIN-SUFFIX,zhenguanyu.com,🎯 全球直连
  - DOMAIN-SUFFIX,cn,🎯 全球直连
  - DOMAIN-SUFFIX,xn--fiqs8s,🎯 全球直连
  - DOMAIN-SUFFIX,xn--55qx5d,🎯 全球直连
  - DOMAIN-SUFFIX,xn--io0a7i,🎯 全球直连
  - DOMAIN-KEYWORD,-cn,🎯 全球直连
  - DOMAIN-KEYWORD,360buy,🎯 全球直连
  - DOMAIN-KEYWORD,alicdn,🎯 全球直连
  - DOMAIN-KEYWORD,alimama,🎯 全球直连
  - DOMAIN-KEYWORD,alipay,🎯 全球直连
  - DOMAIN-KEYWORD,appzapp,🎯 全球直连
  - DOMAIN-KEYWORD,baidupcs,🎯 全球直连
  - DOMAIN-KEYWORD,bilibili,🎯 全球直连
  - DOMAIN-KEYWORD,ccgslb,🎯 全球直连
  - DOMAIN-KEYWORD,chinacache,🎯 全球直连
  - DOMAIN-KEYWORD,duobao,🎯 全球直连
  - DOMAIN-KEYWORD,jdpay,🎯 全球直连
  - DOMAIN-KEYWORD,moke,🎯 全球直连
  - DOMAIN-KEYWORD,qhimg,🎯 全球直连
  - DOMAIN-KEYWORD,vpimg,🎯 全球直连
  - DOMAIN-KEYWORD,xiami,🎯 全球直连
  - DOMAIN-KEYWORD,xiaomi,🎯 全球直连
  - DOMAIN-SUFFIX,360.com,🎯 全球直连
  - DOMAIN-SUFFIX,360kuai.com,🎯 全球直连
  - DOMAIN-SUFFIX,360safe.com,🎯 全球直连
  - DOMAIN-SUFFIX,dhrest.com,🎯 全球直连
  - DOMAIN-SUFFIX,qhres.com,🎯 全球直连
  - DOMAIN-SUFFIX,qhstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,qhupdate.com,🎯 全球直连
  - DOMAIN-SUFFIX,so.com,🎯 全球直连
  - DOMAIN-SUFFIX,4399.com,🎯 全球直连
  - DOMAIN-SUFFIX,4399pk.com,🎯 全球直连
  - DOMAIN-SUFFIX,5054399.com,🎯 全球直连
  - DOMAIN-SUFFIX,img4399.com,🎯 全球直连
  - DOMAIN-SUFFIX,58.com,🎯 全球直连
  - DOMAIN-SUFFIX,1688.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliapp.org,🎯 全球直连
  - DOMAIN-SUFFIX,alibaba.com,🎯 全球直连
  - DOMAIN-SUFFIX,alibabacloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,alibabausercontent.com,🎯 全球直连
  - DOMAIN-SUFFIX,alicdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,alicloudccp.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliexpress.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,alikunlun.com,🎯 全球直连
  - DOMAIN-SUFFIX,alipay.com,🎯 全球直连
  - DOMAIN-SUFFIX,alipayobjects.com,🎯 全球直连
  - DOMAIN-SUFFIX,alisoft.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliyuncdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliyuncs.com,🎯 全球直连
  - DOMAIN-SUFFIX,aliyundrive.com,🎯 全球直连
  - DOMAIN-SUFFIX,amap.com,🎯 全球直连
  - DOMAIN-SUFFIX,autonavi.com,🎯 全球直连
  - DOMAIN-SUFFIX,dingtalk.com,🎯 全球直连
  - DOMAIN-SUFFIX,ele.me,🎯 全球直连
  - DOMAIN-SUFFIX,hichina.com,🎯 全球直连
  - DOMAIN-SUFFIX,mmstat.com,🎯 全球直连
  - DOMAIN-SUFFIX,mxhichina.com,🎯 全球直连
  - DOMAIN-SUFFIX,soku.com,🎯 全球直连
  - DOMAIN-SUFFIX,taobao.com,🎯 全球直连
  - DOMAIN-SUFFIX,taobaocdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,tbcache.com,🎯 全球直连
  - DOMAIN-SUFFIX,tbcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,tmall.com,🎯 全球直连
  - DOMAIN-SUFFIX,tmall.hk,🎯 全球直连
  - DOMAIN-SUFFIX,ucweb.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiami.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiami.net,🎯 全球直连
  - DOMAIN-SUFFIX,ykimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,youku.com,🎯 全球直连
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,baidubcr.com,🎯 全球直连
  - DOMAIN-SUFFIX,baidupcs.com,🎯 全球直连
  - DOMAIN-SUFFIX,baidustatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,bcebos.com,🎯 全球直连
  - DOMAIN-SUFFIX,bdimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,bdstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,bdurl.net,🎯 全球直连
  - DOMAIN-SUFFIX,hao123.com,🎯 全球直连
  - DOMAIN-SUFFIX,hao123img.com,🎯 全球直连
  - DOMAIN-SUFFIX,jomodns.com,🎯 全球直连
  - DOMAIN-SUFFIX,yunjiasu-cdn.net,🎯 全球直连
  - DOMAIN-SUFFIX,acg.tv,🎯 全球直连
  - DOMAIN-SUFFIX,acgvideo.com,🎯 全球直连
  - DOMAIN-SUFFIX,b23.tv,🎯 全球直连
  - DOMAIN-SUFFIX,bigfun.cn,🎯 全球直连
  - DOMAIN-SUFFIX,bigfunapp.cn,🎯 全球直连
  - DOMAIN-SUFFIX,biliapi.com,🎯 全球直连
  - DOMAIN-SUFFIX,biliapi.net,🎯 全球直连
  - DOMAIN-SUFFIX,bilibili.com,🎯 全球直连
  - DOMAIN-SUFFIX,biligame.com,🎯 全球直连
  - DOMAIN-SUFFIX,biligame.net,🎯 全球直连
  - DOMAIN-SUFFIX,bilivideo.com,🎯 全球直连
  - DOMAIN-SUFFIX,bilivideo.cn,🎯 全球直连
  - DOMAIN-SUFFIX,hdslb.com,🎯 全球直连
  - DOMAIN-SUFFIX,im9.com,🎯 全球直连
  - DOMAIN-SUFFIX,smtcdns.net,🎯 全球直连
  - DOMAIN-SUFFIX,battle.net,🎯 全球直连
  - DOMAIN-SUFFIX,battlenet.com,🎯 全球直连
  - DOMAIN-SUFFIX,blizzard.com,🎯 全球直连
  - DOMAIN-SUFFIX,amemv.com,🎯 全球直连
  - DOMAIN-SUFFIX,bdxiguaimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,bdxiguastatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,byted-static.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytedance.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytedance.net,🎯 全球直连
  - DOMAIN-SUFFIX,bytedns.net,🎯 全球直连
  - DOMAIN-SUFFIX,bytednsdoc.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytegoofy.com,🎯 全球直连
  - DOMAIN-SUFFIX,byteimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytescm.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytetos.com,🎯 全球直连
  - DOMAIN-SUFFIX,bytexservice.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyin.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyinpic.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyinstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyinvod.com,🎯 全球直连
  - DOMAIN-SUFFIX,feelgood.cn,🎯 全球直连
  - DOMAIN-SUFFIX,feiliao.com,🎯 全球直连
  - DOMAIN-SUFFIX,gifshow.com,🎯 全球直连
  - DOMAIN-SUFFIX,huoshan.com,🎯 全球直连
  - DOMAIN-SUFFIX,huoshanzhibo.com,🎯 全球直连
  - DOMAIN-SUFFIX,ibytedapm.com,🎯 全球直连
  - DOMAIN-SUFFIX,iesdouyin.com,🎯 全球直连
  - DOMAIN-SUFFIX,ixigua.com,🎯 全球直连
  - DOMAIN-SUFFIX,kspkg.com,🎯 全球直连
  - DOMAIN-SUFFIX,pstatp.com,🎯 全球直连
  - DOMAIN-SUFFIX,snssdk.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiao.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiao13.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaoapi.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaocdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaocdn.net,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaocloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaohao.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaohao.net,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaoimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,toutiaopage.com,🎯 全球直连
  - DOMAIN-SUFFIX,wukong.com,🎯 全球直连
  - DOMAIN-SUFFIX,zijieapi.com,🎯 全球直连
  - DOMAIN-SUFFIX,zijieimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,zjbyte.com,🎯 全球直连
  - DOMAIN-SUFFIX,zjcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,cctv.com,🎯 全球直连
  - DOMAIN-SUFFIX,cctvpic.com,🎯 全球直连
  - DOMAIN-SUFFIX,livechina.com,🎯 全球直连
  - DOMAIN-SUFFIX,21cn.com,🎯 全球直连
  - DOMAIN-SUFFIX,didialift.com,🎯 全球直连
  - DOMAIN-SUFFIX,didiglobal.com,🎯 全球直连
  - DOMAIN-SUFFIX,udache.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyu.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyu.tv,🎯 全球直连
  - DOMAIN-SUFFIX,douyuscdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,douyutv.com,🎯 全球直连
  - DOMAIN-SUFFIX,epicgames.com,🎯 全球直连
  - DOMAIN-SUFFIX,epicgames.dev,🎯 全球直连
  - DOMAIN-SUFFIX,helpshift.com,🎯 全球直连
  - DOMAIN-SUFFIX,paragon.com,🎯 全球直连
  - DOMAIN-SUFFIX,unrealengine.com,🎯 全球直连
  - DOMAIN-SUFFIX,dbankcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,hc-cdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,hicloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,huawei.com,🎯 全球直连
  - DOMAIN-SUFFIX,huaweicloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,huaweishop.net,🎯 全球直连
  - DOMAIN-SUFFIX,hwccpc.com,🎯 全球直连
  - DOMAIN-SUFFIX,vmall.com,🎯 全球直连
  - DOMAIN-SUFFIX,vmallres.com,🎯 全球直连
  - DOMAIN-SUFFIX,iflyink.com,🎯 全球直连
  - DOMAIN-SUFFIX,iflyrec.com,🎯 全球直连
  - DOMAIN-SUFFIX,iflytek.com,🎯 全球直连
  - DOMAIN-SUFFIX,71.am,🎯 全球直连
  - DOMAIN-SUFFIX,71edge.com,🎯 全球直连
  - DOMAIN-SUFFIX,iqiyi.com,🎯 全球直连
  - DOMAIN-SUFFIX,iqiyipic.com,🎯 全球直连
  - DOMAIN-SUFFIX,ppsimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,qiyi.com,🎯 全球直连
  - DOMAIN-SUFFIX,qiyipic.com,🎯 全球直连
  - DOMAIN-SUFFIX,qy.net,🎯 全球直连
  - DOMAIN-SUFFIX,360buy.com,🎯 全球直连
  - DOMAIN-SUFFIX,360buyimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,jcloudcs.com,🎯 全球直连
  - DOMAIN-SUFFIX,jd.com,🎯 全球直连
  - DOMAIN-SUFFIX,jd.hk,🎯 全球直连
  - DOMAIN-SUFFIX,jdcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,jdpay.com,🎯 全球直连
  - DOMAIN-SUFFIX,paipai.com,🎯 全球直连
  - DOMAIN-SUFFIX,iciba.com,🎯 全球直连
  - DOMAIN-SUFFIX,ksosoft.com,🎯 全球直连
  - DOMAIN-SUFFIX,ksyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,kuaishou.com,🎯 全球直连
  - DOMAIN-SUFFIX,yximgs.com,🎯 全球直连
  - DOMAIN-SUFFIX,meitu.com,🎯 全球直连
  - DOMAIN-SUFFIX,meitudata.com,🎯 全球直连
  - DOMAIN-SUFFIX,meitustat.com,🎯 全球直连
  - DOMAIN-SUFFIX,meipai.com,🎯 全球直连
  - DOMAIN-SUFFIX,le.com,🎯 全球直连
  - DOMAIN-SUFFIX,lecloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,letv.com,🎯 全球直连
  - DOMAIN-SUFFIX,letvcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,letvimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,letvlive.com,🎯 全球直连
  - DOMAIN-SUFFIX,letvstore.com,🎯 全球直连
  - DOMAIN-SUFFIX,hitv.com,🎯 全球直连
  - DOMAIN-SUFFIX,hunantv.com,🎯 全球直连
  - DOMAIN-SUFFIX,mgtv.com,🎯 全球直连
  - DOMAIN-SUFFIX,duokan.com,🎯 全球直连
  - DOMAIN-SUFFIX,mi-img.com,🎯 全球直连
  - DOMAIN-SUFFIX,mi.com,🎯 全球直连
  - DOMAIN-SUFFIX,miui.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiaomi.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiaomi.net,🎯 全球直连
  - DOMAIN-SUFFIX,xiaomicp.com,🎯 全球直连
  - DOMAIN-SUFFIX,126.com,🎯 全球直连
  - DOMAIN-SUFFIX,126.net,🎯 全球直连
  - DOMAIN-SUFFIX,127.net,🎯 全球直连
  - DOMAIN-SUFFIX,163.com,🎯 全球直连
  - DOMAIN-SUFFIX,163yun.com,🎯 全球直连
  - DOMAIN-SUFFIX,lofter.com,🎯 全球直连
  - DOMAIN-SUFFIX,netease.com,🎯 全球直连
  - DOMAIN-SUFFIX,ydstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,youdao.com,🎯 全球直连
  - DOMAIN-SUFFIX,pplive.com,🎯 全球直连
  - DOMAIN-SUFFIX,pptv.com,🎯 全球直连
  - DOMAIN-SUFFIX,pinduoduo.com,🎯 全球直连
  - DOMAIN-SUFFIX,yangkeduo.com,🎯 全球直连
  - DOMAIN-SUFFIX,leju.com,🎯 全球直连
  - DOMAIN-SUFFIX,miaopai.com,🎯 全球直连
  - DOMAIN-SUFFIX,sina.com,🎯 全球直连
  - DOMAIN-SUFFIX,sina.com.cn,🎯 全球直连
  - DOMAIN-SUFFIX,sina.cn,🎯 全球直连
  - DOMAIN-SUFFIX,sinaapp.com,🎯 全球直连
  - DOMAIN-SUFFIX,sinaapp.cn,🎯 全球直连
  - DOMAIN-SUFFIX,sinaimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,sinaimg.cn,🎯 全球直连
  - DOMAIN-SUFFIX,weibo.com,🎯 全球直连
  - DOMAIN-SUFFIX,weibo.cn,🎯 全球直连
  - DOMAIN-SUFFIX,weibocdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,weibocdn.cn,🎯 全球直连
  - DOMAIN-SUFFIX,xiaoka.tv,🎯 全球直连
  - DOMAIN-SUFFIX,go2map.com,🎯 全球直连
  - DOMAIN-SUFFIX,sogo.com,🎯 全球直连
  - DOMAIN-SUFFIX,sogou.com,🎯 全球直连
  - DOMAIN-SUFFIX,sogoucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,sohu-inc.com,🎯 全球直连
  - DOMAIN-SUFFIX,sohu.com,🎯 全球直连
  - DOMAIN-SUFFIX,sohucs.com,🎯 全球直连
  - DOMAIN-SUFFIX,sohuno.com,🎯 全球直连
  - DOMAIN-SUFFIX,sohurdc.com,🎯 全球直连
  - DOMAIN-SUFFIX,v-56.com,🎯 全球直连
  - DOMAIN-SUFFIX,playstation.com,🎯 全球直连
  - DOMAIN-SUFFIX,playstation.net,🎯 全球直连
  - DOMAIN-SUFFIX,playstationnetwork.com,🎯 全球直连
  - DOMAIN-SUFFIX,sony.com,🎯 全球直连
  - DOMAIN-SUFFIX,sonyentertainmentnetwork.com,🎯 全球直连
  - DOMAIN-SUFFIX,cm.steampowered.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamcontent.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamusercontent.com,🎯 全球直连
  - DOMAIN-SUFFIX,steamchina.com,🎯 全球直连
  - DOMAIN,csgo.wmsj.cn,🎯 全球直连
  - DOMAIN,dota2.wmsj.cn,🎯 全球直连
  - DOMAIN,wmsjsteam.com,🎯 全球直连
  - DOMAIN,dl.steam.clngaa.com,🎯 全球直连
  - DOMAIN,dl.steam.ksyna.com,🎯 全球直连
  - DOMAIN,st.dl.bscstorage.net,🎯 全球直连
  - DOMAIN,st.dl.eccdnx.com,🎯 全球直连
  - DOMAIN,st.dl.pinyuncloud.com,🎯 全球直连
  - DOMAIN,steampipe.steamcontent.tnkjmec.com,🎯 全球直连
  - DOMAIN,steampowered.com.8686c.com,🎯 全球直连
  - DOMAIN,steamstatic.com.8686c.com,🎯 全球直连
  - DOMAIN-SUFFIX,foxmail.com,🎯 全球直连
  - DOMAIN-SUFFIX,gtimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,idqqimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,igamecj.com,🎯 全球直连
  - DOMAIN-SUFFIX,myapp.com,🎯 全球直连
  - DOMAIN-SUFFIX,myqcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  - DOMAIN-SUFFIX,qqmail.com,🎯 全球直连
  - DOMAIN-SUFFIX,qqurl.com,🎯 全球直连
  - DOMAIN-SUFFIX,smtcdns.com,🎯 全球直连
  - DOMAIN-SUFFIX,smtcdns.net,🎯 全球直连
  - DOMAIN-SUFFIX,soso.com,🎯 全球直连
  - DOMAIN-SUFFIX,tencent-cloud.net,🎯 全球直连
  - DOMAIN-SUFFIX,tencent.com,🎯 全球直连
  - DOMAIN-SUFFIX,tencentmind.com,🎯 全球直连
  - DOMAIN-SUFFIX,tenpay.com,🎯 全球直连
  - DOMAIN-SUFFIX,wechat.com,🎯 全球直连
  - DOMAIN-SUFFIX,weixin.com,🎯 全球直连
  - DOMAIN-SUFFIX,weiyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,appsimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,appvipshop.com,🎯 全球直连
  - DOMAIN-SUFFIX,vip.com,🎯 全球直连
  - DOMAIN-SUFFIX,vipstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,ximalaya.com,🎯 全球直连
  - DOMAIN-SUFFIX,xmcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,00cdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,88cdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,kanimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,kankan.com,🎯 全球直连
  - DOMAIN-SUFFIX,p2cdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,sandai.net,🎯 全球直连
  - DOMAIN-SUFFIX,thundercdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,xunlei.com,🎯 全球直连
  - DOMAIN-SUFFIX,got001.com,🎯 全球直连
  - DOMAIN-SUFFIX,p4pfile.com,🎯 全球直连
  - DOMAIN-SUFFIX,rrys.tv,🎯 全球直连
  - DOMAIN-SUFFIX,rrys2020.com,🎯 全球直连
  - DOMAIN-SUFFIX,yyets.com,🎯 全球直连
  - DOMAIN-SUFFIX,zimuzu.io,🎯 全球直连
  - DOMAIN-SUFFIX,zimuzu.tv,🎯 全球直连
  - DOMAIN-SUFFIX,zmz001.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmz002.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmz003.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmz004.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmz2019.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmzapi.com,🎯 全球直连
  - DOMAIN-SUFFIX,zmzapi.net,🎯 全球直连
  - DOMAIN-SUFFIX,zmzfile.com,🎯 全球直连
  - DOMAIN-KEYWORD,announce,🎯 全球直连
  - DOMAIN-KEYWORD,torrent,🎯 全球直连
  - DOMAIN-KEYWORD,tracker,🎯 全球直连
  - DOMAIN-SUFFIX,animebytes.tv,🎯 全球直连
  - DOMAIN-SUFFIX,animetorrents.me,🎯 全球直连
  - DOMAIN-SUFFIX,awesome-hd.me,🎯 全球直连
  - DOMAIN-SUFFIX,beitai.pt,🎯 全球直连
  - DOMAIN-SUFFIX,bittorrent.com,🎯 全球直连
  - DOMAIN-SUFFIX,broadcasthe.net,🎯 全球直连
  - DOMAIN-SUFFIX,chdbits.co,🎯 全球直连
  - DOMAIN-SUFFIX,classix-unlimited.co.uk,🎯 全球直连
  - DOMAIN-SUFFIX,empornium.me,🎯 全球直连
  - DOMAIN-SUFFIX,gazellegames.net,🎯 全球直连
  - DOMAIN-SUFFIX,hd4fans.org,🎯 全球直连
  - DOMAIN-SUFFIX,hdchina.org,🎯 全球直连
  - DOMAIN-SUFFIX,hdhome.org,🎯 全球直连
  - DOMAIN-SUFFIX,hdsky.me,🎯 全球直连
  - DOMAIN-SUFFIX,hdtime.org,🎯 全球直连
  - DOMAIN-SUFFIX,hdzone.me,🎯 全球直连
  - DOMAIN-SUFFIX,icetorrent.org,🎯 全球直连
  - DOMAIN-SUFFIX,jpopsuki.eu,🎯 全球直连
  - DOMAIN-SUFFIX,keepfrds.com,🎯 全球直连
  - DOMAIN-SUFFIX,leaguehd.com,🎯 全球直连
  - DOMAIN-SUFFIX,m-team.cc,🎯 全球直连
  - DOMAIN-SUFFIX,madsrevolution.net,🎯 全球直连
  - DOMAIN-SUFFIX,msg.vg,🎯 全球直连
  - DOMAIN-SUFFIX,nanyangpt.com,🎯 全球直连
  - DOMAIN-SUFFIX,ncore.cc,🎯 全球直连
  - DOMAIN-SUFFIX,open.cd,🎯 全球直连
  - DOMAIN-SUFFIX,ourbits.club,🎯 全球直连
  - DOMAIN-SUFFIX,passthepopcorn.me,🎯 全球直连
  - DOMAIN-SUFFIX,privatehd.to,🎯 全球直连
  - DOMAIN-SUFFIX,pthome.net,🎯 全球直连
  - DOMAIN-SUFFIX,redacted.ch,🎯 全球直连
  - DOMAIN-SUFFIX,springsunday.net,🎯 全球直连
  - DOMAIN-SUFFIX,tjupt.org,🎯 全球直连
  - DOMAIN-SUFFIX,totheglory.im,🎯 全球直连
  - DOMAIN-SUFFIX,trontv.com,🎯 全球直连
  - DOMAIN-SUFFIX,teamviewer.com,🎯 全球直连
  - IP-CIDR,109.239.140.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,139.220.243.27/32,🎯 全球直连,no-resolve
  - IP-CIDR,172.16.102.56/32,🎯 全球直连,no-resolve
  - IP-CIDR,185.188.32.1/28,🎯 全球直连,no-resolve
  - IP-CIDR,221.226.128.146/32,🎯 全球直连,no-resolve
  - IP-CIDR6,2a0b:b580::/48,🎯 全球直连,no-resolve
  - IP-CIDR6,2a0b:b581::/48,🎯 全球直连,no-resolve
  - IP-CIDR6,2a0b:b582::/48,🎯 全球直连,no-resolve
  - IP-CIDR6,2a0b:b583::/48,🎯 全球直连,no-resolve
  - DOMAIN-SUFFIX,baomitu.com,🎯 全球直连
  - DOMAIN-SUFFIX,bootcss.com,🎯 全球直连
  - DOMAIN-SUFFIX,jiasule.com,🎯 全球直连
  - DOMAIN-SUFFIX,staticfile.org,🎯 全球直连
  - DOMAIN-SUFFIX,upaiyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,10010.com,🎯 全球直连
  - DOMAIN-SUFFIX,115.com,🎯 全球直连
  - DOMAIN-SUFFIX,12306.com,🎯 全球直连
  - DOMAIN-SUFFIX,17173.com,🎯 全球直连
  - DOMAIN-SUFFIX,178.com,🎯 全球直连
  - DOMAIN-SUFFIX,17k.com,🎯 全球直连
  - DOMAIN-SUFFIX,360doc.com,🎯 全球直连
  - DOMAIN-SUFFIX,36kr.com,🎯 全球直连
  - DOMAIN-SUFFIX,3dmgame.com,🎯 全球直连
  - DOMAIN-SUFFIX,51cto.com,🎯 全球直连
  - DOMAIN-SUFFIX,51job.com,🎯 全球直连
  - DOMAIN-SUFFIX,51jobcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,56.com,🎯 全球直连
  - DOMAIN-SUFFIX,8686c.com,🎯 全球直连
  - DOMAIN-SUFFIX,abchina.com,🎯 全球直连
  - DOMAIN-SUFFIX,abercrombie.com,🎯 全球直连
  - DOMAIN-SUFFIX,acfun.tv,🎯 全球直连
  - DOMAIN-SUFFIX,air-matters.com,🎯 全球直连
  - DOMAIN-SUFFIX,air-matters.io,🎯 全球直连
  - DOMAIN-SUFFIX,aixifan.com,🎯 全球直连
  - DOMAIN-SUFFIX,algocasts.io,🎯 全球直连
  - DOMAIN-SUFFIX,babytree.com,🎯 全球直连
  - DOMAIN-SUFFIX,babytreeimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,baicizhan.com,🎯 全球直连
  - DOMAIN-SUFFIX,baidupan.com,🎯 全球直连
  - DOMAIN-SUFFIX,baike.com,🎯 全球直连
  - DOMAIN-SUFFIX,biqudu.com,🎯 全球直连
  - DOMAIN-SUFFIX,biquge.com,🎯 全球直连
  - DOMAIN-SUFFIX,bitauto.com,🎯 全球直连
  - DOMAIN-SUFFIX,c-ctrip.com,🎯 全球直连
  - DOMAIN-SUFFIX,camera360.com,🎯 全球直连
  - DOMAIN-SUFFIX,cdnmama.com,🎯 全球直连
  - DOMAIN-SUFFIX,chaoxing.com,🎯 全球直连
  - DOMAIN-SUFFIX,che168.com,🎯 全球直连
  - DOMAIN-SUFFIX,chinacache.net,🎯 全球直连
  - DOMAIN-SUFFIX,chinaso.com,🎯 全球直连
  - DOMAIN-SUFFIX,chinaz.com,🎯 全球直连
  - DOMAIN-SUFFIX,chinaz.net,🎯 全球直连
  - DOMAIN-SUFFIX,chuimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,cibntv.net,🎯 全球直连
  - DOMAIN-SUFFIX,clouddn.com,🎯 全球直连
  - DOMAIN-SUFFIX,cloudxns.net,🎯 全球直连
  - DOMAIN-SUFFIX,cn163.net,🎯 全球直连
  - DOMAIN-SUFFIX,cnblogs.com,🎯 全球直连
  - DOMAIN-SUFFIX,cnki.net,🎯 全球直连
  - DOMAIN-SUFFIX,cnmstl.net,🎯 全球直连
  - DOMAIN-SUFFIX,coolapk.com,🎯 全球直连
  - DOMAIN-SUFFIX,coolapkmarket.com,🎯 全球直连
  - DOMAIN-SUFFIX,csdn.net,🎯 全球直连
  - DOMAIN-SUFFIX,ctrip.com,🎯 全球直连
  - DOMAIN-SUFFIX,dangdang.com,🎯 全球直连
  - DOMAIN-SUFFIX,dfcfw.com,🎯 全球直连
  - DOMAIN-SUFFIX,dianping.com,🎯 全球直连
  - DOMAIN-SUFFIX,dilidili.wang,🎯 全球直连
  - DOMAIN-SUFFIX,douban.com,🎯 全球直连
  - DOMAIN-SUFFIX,doubanio.com,🎯 全球直连
  - DOMAIN-SUFFIX,dpfile.com,🎯 全球直连
  - DOMAIN-SUFFIX,duowan.com,🎯 全球直连
  - DOMAIN-SUFFIX,dxycdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,dytt8.net,🎯 全球直连
  - DOMAIN-SUFFIX,easou.com,🎯 全球直连
  - DOMAIN-SUFFIX,eastday.com,🎯 全球直连
  - DOMAIN-SUFFIX,eastmoney.com,🎯 全球直连
  - DOMAIN-SUFFIX,ecitic.com,🎯 全球直连
  - DOMAIN-SUFFIX,ewqcxz.com,🎯 全球直连
  - DOMAIN-SUFFIX,fang.com,🎯 全球直连
  - DOMAIN-SUFFIX,fantasy.tv,🎯 全球直连
  - DOMAIN-SUFFIX,feng.com,🎯 全球直连
  - DOMAIN-SUFFIX,fengkongcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,fir.im,🎯 全球直连
  - DOMAIN-SUFFIX,frdic.com,🎯 全球直连
  - DOMAIN-SUFFIX,fresh-ideas.cc,🎯 全球直连
  - DOMAIN-SUFFIX,ganji.com,🎯 全球直连
  - DOMAIN-SUFFIX,ganjistatic1.com,🎯 全球直连
  - DOMAIN-SUFFIX,geetest.com,🎯 全球直连
  - DOMAIN-SUFFIX,geilicdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,ghpym.com,🎯 全球直连
  - DOMAIN-SUFFIX,godic.net,🎯 全球直连
  - DOMAIN-SUFFIX,guazi.com,🎯 全球直连
  - DOMAIN-SUFFIX,gwdang.com,🎯 全球直连
  - DOMAIN-SUFFIX,gzlzfm.com,🎯 全球直连
  - DOMAIN-SUFFIX,haibian.com,🎯 全球直连
  - DOMAIN-SUFFIX,haosou.com,🎯 全球直连
  - DOMAIN-SUFFIX,hollisterco.com,🎯 全球直连
  - DOMAIN-SUFFIX,hongxiu.com,🎯 全球直连
  - DOMAIN-SUFFIX,huajiao.com,🎯 全球直连
  - DOMAIN-SUFFIX,hupu.com,🎯 全球直连
  - DOMAIN-SUFFIX,huxiucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,huya.com,🎯 全球直连
  - DOMAIN-SUFFIX,ifeng.com,🎯 全球直连
  - DOMAIN-SUFFIX,ifengimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,images-amazon.com,🎯 全球直连
  - DOMAIN-SUFFIX,infzm.com,🎯 全球直连
  - DOMAIN-SUFFIX,ipip.net,🎯 全球直连
  - DOMAIN-SUFFIX,it168.com,🎯 全球直连
  - DOMAIN-SUFFIX,ithome.com,🎯 全球直连
  - DOMAIN-SUFFIX,ixdzs.com,🎯 全球直连
  - DOMAIN-SUFFIX,jianguoyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,jianshu.com,🎯 全球直连
  - DOMAIN-SUFFIX,jianshu.io,🎯 全球直连
  - DOMAIN-SUFFIX,jianshuapi.com,🎯 全球直连
  - DOMAIN-SUFFIX,jiathis.com,🎯 全球直连
  - DOMAIN-SUFFIX,jmstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,jumei.com,🎯 全球直连
  - DOMAIN-SUFFIX,kaola.com,🎯 全球直连
  - DOMAIN-SUFFIX,knewone.com,🎯 全球直连
  - DOMAIN-SUFFIX,koowo.com,🎯 全球直连
  - DOMAIN-SUFFIX,ksyungslb.com,🎯 全球直连
  - DOMAIN-SUFFIX,kuaidi100.com,🎯 全球直连
  - DOMAIN-SUFFIX,kugou.com,🎯 全球直连
  - DOMAIN-SUFFIX,lancdns.com,🎯 全球直连
  - DOMAIN-SUFFIX,landiannews.com,🎯 全球直连
  - DOMAIN-SUFFIX,lanzou.com,🎯 全球直连
  - DOMAIN-SUFFIX,lanzoui.com,🎯 全球直连
  - DOMAIN-SUFFIX,lanzoux.com,🎯 全球直连
  - DOMAIN-SUFFIX,lemicp.com,🎯 全球直连
  - DOMAIN-SUFFIX,letitfly.me,🎯 全球直连
  - DOMAIN-SUFFIX,lizhi.fm,🎯 全球直连
  - DOMAIN-SUFFIX,lizhi.io,🎯 全球直连
  - DOMAIN-SUFFIX,lizhifm.com,🎯 全球直连
  - DOMAIN-SUFFIX,luoo.net,🎯 全球直连
  - DOMAIN-SUFFIX,lvmama.com,🎯 全球直连
  - DOMAIN-SUFFIX,lxdns.com,🎯 全球直连
  - DOMAIN-SUFFIX,maoyan.com,🎯 全球直连
  - DOMAIN-SUFFIX,meilishuo.com,🎯 全球直连
  - DOMAIN-SUFFIX,meituan.com,🎯 全球直连
  - DOMAIN-SUFFIX,meituan.net,🎯 全球直连
  - DOMAIN-SUFFIX,meizu.com,🎯 全球直连
  - DOMAIN-SUFFIX,migucloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,miguvideo.com,🎯 全球直连
  - DOMAIN-SUFFIX,mobike.com,🎯 全球直连
  - DOMAIN-SUFFIX,mogu.com,🎯 全球直连
  - DOMAIN-SUFFIX,mogucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,mogujie.com,🎯 全球直连
  - DOMAIN-SUFFIX,moji.com,🎯 全球直连
  - DOMAIN-SUFFIX,moke.com,🎯 全球直连
  - DOMAIN-SUFFIX,msstatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,mubu.com,🎯 全球直连
  - DOMAIN-SUFFIX,myunlu.com,🎯 全球直连
  - DOMAIN-SUFFIX,nruan.com,🎯 全球直连
  - DOMAIN-SUFFIX,nuomi.com,🎯 全球直连
  - DOMAIN-SUFFIX,onedns.net,🎯 全球直连
  - DOMAIN-SUFFIX,onlinedown.net,🎯 全球直连
  - DOMAIN-SUFFIX,oracle.com,🎯 全球直连
  - DOMAIN-SUFFIX,oschina.net,🎯 全球直连
  - DOMAIN-SUFFIX,ourdvs.com,🎯 全球直连
  - DOMAIN-SUFFIX,polyv.net,🎯 全球直连
  - DOMAIN-SUFFIX,qbox.me,🎯 全球直连
  - DOMAIN-SUFFIX,qcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,qcloudcdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,qdaily.com,🎯 全球直连
  - DOMAIN-SUFFIX,qdmm.com,🎯 全球直连
  - DOMAIN-SUFFIX,qhimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,qianqian.com,🎯 全球直连
  - DOMAIN-SUFFIX,qidian.com,🎯 全球直连
  - DOMAIN-SUFFIX,qihucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,qin.io,🎯 全球直连
  - DOMAIN-SUFFIX,qiniu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qiniucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,qiniudn.com,🎯 全球直连
  - DOMAIN-SUFFIX,qiushibaike.com,🎯 全球直连
  - DOMAIN-SUFFIX,quanmin.tv,🎯 全球直连
  - DOMAIN-SUFFIX,qunar.com,🎯 全球直连
  - DOMAIN-SUFFIX,qunarzz.com,🎯 全球直连
  - DOMAIN-SUFFIX,repaik.com,🎯 全球直连
  - DOMAIN-SUFFIX,ruguoapp.com,🎯 全球直连
  - DOMAIN-SUFFIX,runoob.com,🎯 全球直连
  - DOMAIN-SUFFIX,sankuai.com,🎯 全球直连
  - DOMAIN-SUFFIX,segmentfault.com,🎯 全球直连
  - DOMAIN-SUFFIX,sf-express.com,🎯 全球直连
  - DOMAIN-SUFFIX,shumilou.net,🎯 全球直连
  - DOMAIN-SUFFIX,simplecd.me,🎯 全球直连
  - DOMAIN-SUFFIX,smzdm.com,🎯 全球直连
  - DOMAIN-SUFFIX,snwx.com,🎯 全球直连
  - DOMAIN-SUFFIX,soufunimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,sspai.com,🎯 全球直连
  - DOMAIN-SUFFIX,startssl.com,🎯 全球直连
  - DOMAIN-SUFFIX,suning.com,🎯 全球直连
  - DOMAIN-SUFFIX,synology.com,🎯 全球直连
  - DOMAIN-SUFFIX,taihe.com,🎯 全球直连
  - DOMAIN-SUFFIX,th-sjy.com,🎯 全球直连
  - DOMAIN-SUFFIX,tianqi.com,🎯 全球直连
  - DOMAIN-SUFFIX,tianqistatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,tianyancha.com,🎯 全球直连
  - DOMAIN-SUFFIX,tianyaui.com,🎯 全球直连
  - DOMAIN-SUFFIX,tietuku.com,🎯 全球直连
  - DOMAIN-SUFFIX,tiexue.net,🎯 全球直连
  - DOMAIN-SUFFIX,tmiaoo.com,🎯 全球直连
  - DOMAIN-SUFFIX,trip.com,🎯 全球直连
  - DOMAIN-SUFFIX,ttmeiju.com,🎯 全球直连
  - DOMAIN-SUFFIX,tudou.com,🎯 全球直连
  - DOMAIN-SUFFIX,tuniu.com,🎯 全球直连
  - DOMAIN-SUFFIX,tuniucdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,umengcloud.com,🎯 全球直连
  - DOMAIN-SUFFIX,upyun.com,🎯 全球直连
  - DOMAIN-SUFFIX,uxengine.net,🎯 全球直连
  - DOMAIN-SUFFIX,videocc.net,🎯 全球直连
  - DOMAIN-SUFFIX,wandoujia.com,🎯 全球直连
  - DOMAIN-SUFFIX,weather.com,🎯 全球直连
  - DOMAIN-SUFFIX,weico.cc,🎯 全球直连
  - DOMAIN-SUFFIX,weidian.com,🎯 全球直连
  - DOMAIN-SUFFIX,weiphone.com,🎯 全球直连
  - DOMAIN-SUFFIX,weiphone.net,🎯 全球直连
  - DOMAIN-SUFFIX,womai.com,🎯 全球直连
  - DOMAIN-SUFFIX,wscdns.com,🎯 全球直连
  - DOMAIN-SUFFIX,xdrig.com,🎯 全球直连
  - DOMAIN-SUFFIX,xhscdn.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiachufang.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiaohongshu.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiaojukeji.com,🎯 全球直连
  - DOMAIN-SUFFIX,xinhuanet.com,🎯 全球直连
  - DOMAIN-SUFFIX,xip.io,🎯 全球直连
  - DOMAIN-SUFFIX,xitek.com,🎯 全球直连
  - DOMAIN-SUFFIX,xiumi.us,🎯 全球直连
  - DOMAIN-SUFFIX,xslb.net,🎯 全球直连
  - DOMAIN-SUFFIX,xueqiu.com,🎯 全球直连
  - DOMAIN-SUFFIX,yach.me,🎯 全球直连
  - DOMAIN-SUFFIX,yeepay.com,🎯 全球直连
  - DOMAIN-SUFFIX,yhd.com,🎯 全球直连
  - DOMAIN-SUFFIX,yihaodianimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,yinxiang.com,🎯 全球直连
  - DOMAIN-SUFFIX,yinyuetai.com,🎯 全球直连
  - DOMAIN-SUFFIX,yixia.com,🎯 全球直连
  - DOMAIN-SUFFIX,ys168.com,🎯 全球直连
  - DOMAIN-SUFFIX,yuewen.com,🎯 全球直连
  - DOMAIN-SUFFIX,yy.com,🎯 全球直连
  - DOMAIN-SUFFIX,yystatic.com,🎯 全球直连
  - DOMAIN-SUFFIX,zealer.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhangzishi.cc,🎯 全球直连
  - DOMAIN-SUFFIX,zhanqi.tv,🎯 全球直连
  - DOMAIN-SUFFIX,zhaopin.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhihu.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhimg.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhongsou.com,🎯 全球直连
  - DOMAIN-SUFFIX,zhuihd.com,🎯 全球直连
# 中国云服务商ip端
# 阿里
# 腾讯 qq
# 百度 Baidu
# 华为 huwei
# 网易 NetEase
# 360
  - IP-CIDR,8.128.0.0/10,🎯 全球直连,no-resolve
  - IP-CIDR,8.208.0.0/12,🎯 全球直连,no-resolve
  - IP-CIDR,14.1.112.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,41.222.240.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,41.223.119.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,43.242.168.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,45.112.212.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,47.52.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,47.56.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,47.74.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,47.76.0.0/14,🎯 全球直连,no-resolve
  - IP-CIDR,47.80.0.0/12,🎯 全球直连,no-resolve
  - IP-CIDR,47.235.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,47.236.0.0/14,🎯 全球直连,no-resolve
  - IP-CIDR,47.240.0.0/14,🎯 全球直连,no-resolve
  - IP-CIDR,47.244.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,47.246.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,47.250.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,47.252.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,47.254.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,59.82.0.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,59.82.240.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,59.82.248.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,72.254.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,103.38.56.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.52.76.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.206.40.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,110.76.21.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,110.76.23.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,112.125.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,116.251.64.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,119.38.208.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,119.38.224.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,119.42.224.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,139.95.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,140.205.1.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,140.205.122.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,147.139.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,149.129.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,155.102.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,161.117.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,163.181.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,170.33.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,198.11.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,205.204.96.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,19.28.0.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,45.40.192.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,49.51.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,62.234.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,94.191.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,103.7.28.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.116.50.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.231.60.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,109.244.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,111.30.128.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,111.30.136.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,111.30.139.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,111.30.140.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,115.159.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,119.28.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,120.88.56.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,121.51.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,129.28.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,129.204.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,129.211.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,132.232.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,134.175.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,146.56.192.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,148.70.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,150.109.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,152.136.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,162.14.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,162.62.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,170.106.130.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,182.254.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,188.131.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,203.195.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,203.205.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,210.4.138.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,211.152.128.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,211.152.132.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,211.152.148.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,212.64.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,212.129.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,45.113.192.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,63.217.23.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,63.243.252.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,103.235.44.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,104.193.88.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,106.12.0.0/15,🎯 全球直连,no-resolve
  - IP-CIDR,114.28.224.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,119.63.192.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,180.76.0.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,180.76.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,182.61.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,185.10.104.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,202.46.48.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,203.90.238.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,43.254.0.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,45.249.212.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,49.4.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,78.101.192.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,78.101.224.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,81.52.161.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,85.97.220.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.31.200.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.69.140.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.218.216.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,114.115.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,114.116.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,116.63.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,116.66.184.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.96.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.128.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.136.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.141.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.142.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.243.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.244.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,116.71.251.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,117.78.0.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,119.3.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,119.8.0.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,119.8.32.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,121.36.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,121.36.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,121.37.0.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,122.112.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.0.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.64.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.100.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.104.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.112.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.192.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.224.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.240.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,139.9.248.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.128.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.160.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.164.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.168.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.176.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,139.159.192.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.0.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.64.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.79.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.80.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.96.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.112.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.125.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.192.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.223.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,159.138.224.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,168.195.92.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,185.176.76.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,197.199.0.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,197.210.163.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,197.252.1.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,197.252.2.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,197.252.4.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,197.252.8.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,200.32.52.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,200.32.54.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,200.32.57.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.0.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.4.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.8.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.11.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.13.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.20.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.22.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.24.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.26.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.29.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.33.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.38.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.40.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.43.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.48.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,203.135.50.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,42.186.0.0/16,🎯 全球直连,no-resolve
  - IP-CIDR,45.127.128.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,45.195.24.0/24,🎯 全球直连,no-resolve
  - IP-CIDR,45.253.132.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,45.253.240.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,45.254.48.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,59.111.0.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,59.111.128.0/17,🎯 全球直连,no-resolve
  - IP-CIDR,103.71.120.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,103.71.128.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.71.196.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.71.200.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.12.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.18.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.24.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.28.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.38.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.40.0/23,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.44.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.48.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,103.72.128.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,103.74.24.0/21,🎯 全球直连,no-resolve
  - IP-CIDR,103.74.48.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.126.92.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.129.252.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.131.252.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.135.240.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,103.196.64.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,106.2.32.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,106.2.64.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,114.113.196.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,114.113.200.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,115.236.112.0/20,🎯 全球直连,no-resolve
  - IP-CIDR,115.238.76.0/22,🎯 全球直连,no-resolve
  - IP-CIDR,123.58.160.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,223.252.192.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,101.198.128.0/18,🎯 全球直连,no-resolve
  - IP-CIDR,101.198.192.0/19,🎯 全球直连,no-resolve
  - IP-CIDR,101.199.196.0/22,🎯 全球直连,no-resolve
  - GEOIP,CN,🎯 全球直连
  - MATCH,🐟 漏网之鱼"

# 检测文件是否存在
if [ -e "$file" ]; then
  line_count=$(wc -l < "$file")
  if [ "$ipv6" = "null" ]; then
    processing_node_count=$((line_count / 12))
  else
    processing_node_count=$((line_count / 13))
  fi
  echo "Warp节点数量：$processing_node_count"
#  sed -i "1i $content_to_insert_home" "$file"

	# 创建临时文件并将要插入的内容写入临时文件
	tmpfile=$(mktemp)
	echo "$content_to_insert_home" > "$tmpfile"

	# 使用cat命令将临时文件的内容插入到文件开头
	cat "$tmpfile" "$file" > "$file.tmp"
	mv "$file.tmp" "$file"

	# 删除临时文件
	rm "$tmpfile"

	echo "内容已插入到文件开头: $file"

  echo "$content_to_insert_end" >> "$file"

  for ((i=1; i<=processing_node_count; i++)); do
    node_name="Warp$(printf "%02d" $i)"
    echo "      - $node_name" >> "$file"
  done
  
  echo "$rules" >> "$file"
  
else
  echo "$file 不存在"
fi

rmxx "ip.txt"
rmxx "result.csv"
rmxx "wgcf-account.toml"
rmxx "wgcf-profile.conf"
cp "Warp2Clash.yaml" "/sdcard/"
