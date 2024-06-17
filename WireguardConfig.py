import csv
import sys

# 获取命令行参数
private_key = sys.argv[1]
public_key = sys.argv[2]
ipv6 = None
if len(sys.argv) >= 4:
    ipv6 = sys.argv[3]

def is_valid_ipv6(address):
    # 简单的 IPv6 地址验证
    try:
        import ipaddress
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
                # 假设 CSV 文件包含 IPv6 地址和端口号，格式为 "IPv6地址:端口"
                ip_port = row[0].strip()
                if not ip_port or ':' not in ip_port:
                    continue

                # 分割 IPv6 地址和端口号，考虑 IPv6 地址中可能包含多个冒号
                parts = ip_port.split(':')
                if len(parts) != 2:
                    continue

                ip, port = parts[0].strip(), parts[1].strip()
                if not is_valid_ipv6(ip):  # 确保是有效的 IPv6 地址
                    continue

                # 构造新的 WireGuard 配置行
                new_line = f"- name: Warp-{ip}\n  type: wireguard\n"
                new_line += f"  server: {ip}\n  port: {port}\n  ip: 2606:4700:110:82e9:54c1:9d99:8fb4:9606/128\n"
                if ipv6:
                    new_line += f"  ipv6: {ipv6}\n"
                new_line += f"  private-key: {private_key}\n  public-key: {public_key}\n"
                new_line += "  udp: true\n  mtu: 1280\n  remote-dns-resolve: true\n  dns: [ 1.1.1.1, 1.0.0.1 ]\n\n"
                
                output_file.write(new_line)

            print("结果已保存到 Warp2Clash.yaml 文件")

file_path = 'result.csv'
process_csv(file_path, ipv6)
