import csv
import sys
import ipaddress

# 获取命令行参数
private_key = sys.argv[1]
public_key = sys.argv[2]
ipv6 = sys.argv[3] if len(sys.argv) > 3 else None

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
                
                try:
                    # 分割 IPv6 地址和端口号
                    parts = ip_port.split(':')
                    ip, port = parts[0].strip(), parts[1].strip()
                    
                    # 验证 IPv6 地址是否有效
                    if ipaddress.ip_address(ip).version == 6:
                        # 构造新的 WireGuard 配置行
                        warp_name = "Warp" + str(reader.line_num)
                        new_line = f"- name: {warp_name}\n  type: wireguard\n"
                        new_line += f"  server: {ip}\n  port: {port}\n"
                        new_line += f"  ip: 2606:4700:110:82e9:54c1:9d99:8fb4:9606/128\n"
                        if ipv6:
                            new_line += f"  ipv6: {ipv6}\n"
                        new_line += f"  private-key: {private_key}\n  public-key: {public_key}\n"
                        new_line += "  udp: true\n  mtu: 1280\n  remote-dns-resolve: true\n  dns: [ 1.1.1.1, 1.0.0.1 ]\n\n"
                        
                        output_file.write(new_line)
                    else:
                        print(f"跳过无效的 IPv6 地址: {ip}")
                except ValueError:
                    print(f"跳过无效的行: {ip_port}")
            
            print("结果已保存到 Warp2Clash.yaml 文件")

file_path = 'result.csv'
process_csv(file_path, ipv6)
