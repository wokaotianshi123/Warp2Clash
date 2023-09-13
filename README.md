# warp
优选Cloudflare Warp节点并生成用于Clash的WireGuard配置
# Usage
1. 拉取仓库代码
``` bash
git clone https://github.com/cmliu/warp2clash.git && cd warp2clash && chmod +x W2C_start.sh && chmod +x warp-yxip.sh
```
2. 替换WireguardConfig.py中的privateKey、publicKey字段
3. 运行
``` bash
./W2C_start.sh
```
4. 结果clash_yaml.txt
