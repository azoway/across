### 自动测速并应用最优的免费流媒体解锁服务DNS  

本脚本会自动获取最新的免费流媒体解锁服务 AKDNS 列表 → 并行测速 → 选出最快 3 个 DNS → 自动应用，全部超时回退 DEFAULT_DNS(8.8.8.8,1.1.1.1)

#### 使用方式
1. [注册 akile 账号](https://akile.io/register?aff_code=a1e2817f-c626-4f0b-b7ba-afce0951a583)
2. 在 akile 提供的免费流媒体解锁服务面板添加自己的 VPS 地址并打开需要解锁的服务 → [控制面板](https://dns.akile.ai/)
3. 在 VPS 执行以下脚本:
  
```bash
wget --no-check-certificate -O /etc/akdns-auto.sh https://raw.githubusercontent.com/azoway/across/master/akdns/akdns-auto.sh
chmod 755 /etc/akdns-auto.sh
(crontab -l ; echo "*/5 * * * * /etc/akdns-auto.sh") | crontab -
bash /etc/akdns-auto.sh
```


### Auto Speedtest & Apply Best Free Streaming-Unlock DNS

This script automatically fetches the latest Free-Streaming-Unlock AKDNS list → runs parallel DNS speed tests → selects the fastest 3 DNS servers → applies them automatically.  
If all DNS servers time out, it falls back to `DEFAULT_DNS`(8.8.8.8,1.1.1.1).

#### Usage

1.  [Register an akile account](https://akile.io/register?aff_code=a1e2817f-c626-4f0b-b7ba-afce0951a583)
2.  Add your VPS IP address to the free streaming-unlock DNS panel → [Control Panel](https://dns.akile.ai/)
3.  Run the following commands on your VPS:
  
```bash
wget --no-check-certificate -O /etc/akdns-auto.sh https://raw.githubusercontent.com/azoway/across/master/akdns/akdns-auto.sh
chmod 755 /etc/akdns-auto.sh
(crontab -l ; echo "*/5 * * * * /etc/akdns-auto.sh") | crontab -
bash /etc/akdns-auto.sh
```
