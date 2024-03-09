# cmliu/Warp2Clash 来自大佬们的代码

1.用手机安装termux运行，然后先安装python环境（首次运行需要，以后不需要），预计有600M，手机空间要足够。termux下载地址：https://github.com/termux/termux-app/releases
``` 
pkg install python
```
2.获取读写sd卡权限，允许
``` 
termux-setup-storage
``` 
3.复制运行下面代码
``` 
wget -N -P Warp2Clash https://gitjs.wokaotianshi123.cloudns.org/https://raw.githubusercontent.com/wokaotianshi23/Warp2Clash/main/W2C_start.sh && cd Warp2Clash && chmod +x W2C_start.sh && bash W2C_start.sh iGpo/8+r44JBwD2XndRoUanyf+r0PNdIcEX0Few/jFk= bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo= 
``` 
4.在手机根目录查看 Warp2Clash.yaml是否存在,将Warp2Clash.yaml上传到个人空间得到外链链接。http...，复制下来。以后每次更新就直接更新Warp2Clash.yaml内容即可。
5.下载安装最新版hiddify next，打开,右上角，剪贴板导入。hiddify next下载地址：https://github.com/hiddify/hiddify-next/releases/














# 以下是原版说明

白嫖总得来说不好，请不要公开传播，项目热度太高就删库

优选Cloudflare Warp节点并生成用于Clash的WireGuard配置

测试运行环境ubuntu-18.04-standard_18.04.1-1_amd64

# Usage
1. 下载脚本
``` bash
wget -N -P Warp2Clash https://raw.githubusercontent.com/cmliu/Warp2Clash/main/W2C_start.sh && cd Warp2Clash && chmod +x W2C_start.sh
```

2. 运行脚本

如果你有WARP账户许可证密钥，但是没有`PrivateKey`和`PublicKey`，可以运行一次以下命令后从`Warp2Clash.yaml`中提取记录`PrivateKey`和`PublicKey`的值
``` bash
sh W2C_start.sh [WARP账户许可证密钥]
```

如果您有PrivateKey和PublicKey，可按照以下命令执行

``` bash
sh W2C_start.sh [PrivateKey] [PublicKey] [IPv6]
```

| 参数名|  一键脚本参数必填项 | 备注(注意!参数必须按顺序填写)  |
|--------------------------|---------------------------------|-----------------|
| PrivateKey  | √ | 你的PrivateKey |
| PublicKey   | √ | 你的PublicKey |
| IPv6  | × | 没有可不填 |

3. 结果`Warp2Clash.yaml`
```
...

proxies:
- name: Warp01
  type: wireguard
  server: 162.159.192.139
  port: 859
  ip: 172.16.0.2
  ipv6: 2606:1111:1111:1111:1111:1111:1111:9eae
  private-key: 6FxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxFI=
  public-key: bmxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxyo=
  udp: true
  mtu: 1280
  remote-dns-resolve: true
  dns: [ 1.1.1.1, 1.0.0.1 ]

- name: Warp02
  type: wireguard
  server: 162.159.192.196
  port: 934
  ip: 172.16.0.2
  ipv6: 2606:1111:1111:1111:1111:1111:1111:9eae
  private-key: 6FxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxFI=
  public-key: bmxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxyo=
  udp: true
  mtu: 1280
  remote-dns-resolve: true
  dns: [ 1.1.1.1, 1.0.0.1 ]

...

- name: Warp64
  type: wireguard
  server: 188.114.98.66
  port: 859
  ip: 172.16.0.2
  ipv6: 2606:1111:1111:1111:1111:1111:1111:9eae
  private-key: 6FxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxFI=
  public-key: bmxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxyo=
  udp: true
  mtu: 1280
  remote-dns-resolve: true
  dns: [ 1.1.1.1, 1.0.0.1 ]

proxy-groups:
  - name: ⚖️ 负载均衡.Warp+
    type: load-balance
    url: http://www.google.com/generate_204
    interval: 300
    strategy: round-robin
    proxies:
    - Warp01
    - Warp02

...



    - Warp64

...
```


 # 感谢
 [plsy1](https://github.com/plsy1/warp)、[ViRb3](https://github.com/ViRb3/wgcf)、[MisakaNo](https://github.com/Misaka-blog)等
