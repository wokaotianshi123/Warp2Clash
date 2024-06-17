import csv
import sys

# 获取命令行参数
private_key = sys.argv[1]
public_key = sys.argv[2]
ipv6 = None
if len(sys.argv) >= 4:
    ipv6 = sys.argv[3]

def process_csv(file_path, ipv6):
    with open(file_path, 'r') as file:
        reader = csv.reader(file)
        next(reader)  # 跳过标题行

        with open('Warp2Clash.yaml', 'w') as output_file:
            output_file.write("proxies:\n")  # 写入代理配置的开始
            count = 0
            for row in reader:
                # 假设 CSV 文件包含 IPv6 地址和端口号，格式为 "IPv6地址:端口"
                if not row:
                    continue
                ip_port = row[0].strip()
                if ':' not in ip_port:
                    continue
                ip, port = ip_port.split(':')
                if not is_valid_ipv6(ip):  # 确保是有效的 IPv6 地址
                    continue
                
                count += 1
                warp_name = f"Warp{count:02d}"
                new_line = f"- name: {warp_name}\n  type: wireguard\n"
                new_line += f"  server: {ip}\n  port: {port}\n  ip: 2606:4700:110:82e9:54c1:9d99:8fb4:9606/128\n  ipv6: {ipv6}\n"
                new_line += f"  private-key: {private_key}\n  public-key: {public_key}\n"
                new_line += "  udp: true\n  mtu: 1280\n  remote-dns-resolve: true\n  dns: [ 1.1.1.1, 1.0.0.1 ]\n\n"
                
                output_file.write(new_line)

            output_file.write("\nproxy-groups:\n")  # 写入代理组的开始
            # ... 这里可以添加其他代理组的配置 ...

            print("结果已保存到 Warp2Clash.yaml 文件")

def is_valid_ipv6(address):
    # 简单的 IPv6 地址验证，实际使用中可能需要更严格的验证
    try:
        return ':' in address and len(address.split(':')) == 8
    except:
        return False

file_path = 'result.csv'
process_csv(file_path, ipv6)
