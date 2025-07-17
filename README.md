## **Cloudflare DDNS 动态域名更新脚本**
- **一个简单、强大且“一劳永逸”的 Shell 脚本，用于自动更新 Cloudflare 上的 DNS 记录，使其始终指向您服务器的当前动态 IP 地址。**
## **解决什么问题？ 🤔**
- 很多时候，我们的 VPS 或家用服务器的公网 IP 地址不是固定的，会经常变化。这会导致我们无法通过固定的 IP 地址来 SSH 连接服务器或访问上面部署的服务。
- 本脚本通过利用 Cloudflare 强大的 API，完美地解决了这个问题。它会自动检测您服务器的 IP 变动，并更新您在 Cloudflare 上的 DNS 解析记录。从此，您只需记住一个域名，即可随时随地连接到您的服务器。
## **✨ 功能特性**
- **🚀 一键部署: 一行命令即可完成所有依赖安装和环境配置。**
- **💬 交互式配置: 脚本会像聊天一样引导您输入必要信息，无需手动修改任何配置文件。**
- **🧩 智能依赖检查: 自动检测并提示安装 curl, jq 等核心依赖。**
- **💻 跨平台兼容: 支持主流的 Linux 发行版，如 Debian, Ubuntu, CentOS, RHEL, Fedora 等。**
- **⏰ 稳定可靠: 使用系统内置的 cron 定时任务，每 5 分钟检查一次，稳定且资源占用极低。**
- **📄 清晰日志: 所有操作都会被记录到日志文件中，方便排查问题。**

## **快速开始 🚀**
- **在您的服务器上，根据对应的操作系统，复制并执行以下一行命令即可。快捷命令方式：cfddns**
- **适用于 Debian / Ubuntu**
```
apt update && apt -y install curl wget jq cron && wget -N -O /usr/local/bin/cf-ddns.sh https://raw.githubusercontent.com/0xdabiaoge/Cloudflare-DDNS/main/Cloudflare-DDNS.sh && chmod +x /usr/local/bin/cf-ddns.sh && ln -sf /usr/local/bin/cf-ddns.sh /usr/local/bin/cfddns && cfddns
```
- **适用于 CentOS / RHEL / Fedora**
```
yum -y install curl wget jq cronie || dnf -y install curl wget jq cronie && wget -N -O /usr/local/bin/cf-ddns.sh https://raw.githubusercontent.com/0xdabiaoge/Cloudflare-DDNS/main/Cloudflare-DDNS.sh && chmod +x /usr/local/bin/cf-ddns.sh && ln -sf /usr/local/bin/cf-ddns.sh /usr/local/bin/cfddns && cfddns
```
## **📝 使用方法**
- **复制上面对应您系统的“一键命令”，并粘贴到您的服务器终端中执行。**
- **脚本会自动开始，并引导您完成信息填写**
## **📜 日志与管理**
- **查看完整日志:**
```
cat /var/log/cf_ddns.log
```
- **实时跟踪日志:**
```
tail -f /var/log/cf_ddns.log
```
