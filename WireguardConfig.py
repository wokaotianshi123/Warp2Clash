import csv

def process_csv(file_path):
    with open(file_path, 'r') as file:
        reader = csv.reader(file)

        next(reader)

        with open('clash_yaml.txt', 'w') as output_file:
            for i, row in enumerate(reader, start=1):
                ip_port = row[0].strip()
                ip, port = ip_port.split(":")
                warp_name = f"Warp{i:02d}"
                new_line = f"- name: {warp_name}\n  type: wireguard\n  server: {ip}\n  port: {port}\n  ip: 172.16.0.2\n  ipv6: 2606:4700:110:8db8:9c99:ddd0:61b1:9eae\n  private-key: xxxxxx\n  public-key: xxxxxx\n  udp: true\n  mtu: 1280\n  remote-dns-resolve: true\n  dns: [ 1.1.1.1, 1.0.0.1 ]\n\n"
                output_file.write(new_line)

    print("结果已保存到 clash_yaml.txt 文件")


file_path = 'result.csv'

process_csv(file_path)


  
