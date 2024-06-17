import csv
import sys
import re
import ipaddress

# 获取命令行参数
private_key = sys.argv[1]
public_key = sys.argv[2]
ipv6 = sys.argv[3] if len(sys.argv) > 3 else None

def is_valid_ipv6(address):
    try:
        ipaddress.ip_address(address)
        return True
    except ValueError:
        return False

def process_csv(file_path, ipv6):
    with open(file_path, 'r') as file:
        reader = csv.reader(file)
        next(reader)  # 跳过标题行

        with open('Warp2Clash.yaml', 'w') as output_file:
            output_file.write("proxies:\n")
            
            for row in reader:
                # 检查行是否包含至少一个冒号，且以方括号开始
                if ':' not in row[0] or not row[0].startswith('['):
                    continue
                
                # 使用正则表达式匹配 IPv6 地址和端口
                match = re.match(r'\[([^\]]+)\]:(\d+)', row[0])
                if match:
                    ip, port = match.groups()
                    ip = ip.strip()  # 移除可能的空白字符
                    port = int(port)  # 确保端口号为整数
                    
                    # 验证 IPv6 地址是否有效
                    if is_valid_ipv6(ip):
                        # 构造新的 WireGuard 配置行
                        warp_name = f"Warp{reader.line_num}"
                        new_line = f"- name: {warp_name}\n  type: wireguard\n"
                        new_line += f"  ip: 2606:4700:110:82e9:54c1:9d99:8fb4:9606/128\n"
                        new_line += f"  server: {ip}\n  port: {port}\n"
                        if ipv6:
                            new_line += f"  ipv6: {ipv6}\n"
                        new_line += f"  private-key: {private_key}\n  public-key: {public_key}\n"
                        new_line += "  udp: true\n  mtu: 1280\n  remote-dns-resolve: true\n  dns: [ 1.1.1.1, 1.0.0.1 ]\n\n"
                        
                        output_file.write(new_line)
                        print(f"已添加 IPv6 地址 {ip} 到配置文件")
                    else:
                        print(f"跳过无效的 IPv6 地址: {ip}")
                else:
                    print(f"跳过不匹配的行: {row[0]}")

            print("结果已保存到 Warp2Clash.yaml 文件")

file_path = 'result.csv'
process_csv(file_path, ipv6)
