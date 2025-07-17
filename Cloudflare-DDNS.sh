#!/bin/bash

#
# Cloudflare DDNS 一键配置脚本
# Github: https://github.com/0xdabiaoge/Cloudflare-DDNS
#
# 功能:
# 1. 交互式引导用户输入 Cloudflare 信息。
# 2. 自动检查并提示安装依赖 (curl, jq)。
# 3. 生成核心的 DDNS 更新脚本。
# 4. 自动添加 Cron 定时任务，实现周期性检查。
# 5. 提供清晰的日志和操作指引。
#

# --- 彩色输出定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- 脚本开始 ---

clear
echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}  Cloudflare DDNS (动态 DNS) 一键配置脚本                      ${NC}"
echo -e "${GREEN}  本脚本将引导您完成所有设置，自动更新您服务器的动态 IP 地址。 ${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""

# --- 步骤 1: 检查依赖 ---
echo -e "${YELLOW}--> 步骤 1: 检查系统依赖 (curl 和 jq)...${NC}"
# 检查 curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 'curl' 未安装。请先安装 curl 后再运行此脚本。${NC}"
    echo -e "${RED}Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y curl${NC}"
    echo -e "${RED}CentOS/RHEL: sudo yum install -y curl${NC}"
    exit 1
fi

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}检测到 'jq' 未安装。jq 是一个处理 JSON 数据的利器，脚本需要它。${NC}"
    read -p "是否要现在尝试自动安装 jq? (y/n): " install_jq
    if [[ "$install_jq" == "y" || "$install_jq" == "Y" ]]; then
        # 尝试使用常见的包管理器安装 jq
        if command -v apt-get &> /dev/null; then
            echo "正在使用 apt-get 安装 jq..."
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            echo "正在使用 yum 安装 jq..."
            sudo yum install -y jq
        elif command -v dnf &> /dev/null; then
            echo "正在使用 dnf 安装 jq..."
            sudo dnf install -y jq
        else
            echo -e "${RED}无法确定您的包管理器。请参照您系统的文档手动安装 jq 后再运行此脚本。${NC}"
            exit 1
        fi
        # 再次检查 jq 是否安装成功
        if ! command -v jq &> /dev/null; then
            echo -e "${RED}jq 安装失败。请检查错误信息并手动安装。${NC}"
            exit 1
        fi
        echo -e "${GREEN}jq 安装成功！${NC}"
    else
        echo -e "${RED}用户取消安装。脚本无法继续。${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}依赖检查通过！${NC}"
echo ""

# --- 步骤 2: 获取用户输入 ---
echo -e "${YELLOW}--> 步骤 2: 请输入您的 Cloudflare 配置信息。${NC}"
echo "--------------------------------------------------"
# 提示用户如何获取 API Token
echo "请前往 Cloudflare 仪表板 -> 我的个人资料 -> API 令牌"
echo "使用 '编辑区域 DNS' 模板创建一个新的令牌。"
echo "--------------------------------------------------"
read -s -p "请输入您的 Cloudflare API 令牌 (Token): " CF_API_TOKEN
echo ""
while [ -z "$CF_API_TOKEN" ]; do
    echo -e "${RED}API 令牌不能为空！${NC}"
    read -s -p "请重新输入您的 Cloudflare API 令牌: " CF_API_TOKEN
    echo ""
done

echo "--------------------------------------------------"
read -p "请输入您的根域名 (例如: yourdomain.com): " ZONE_NAME
while [ -z "$ZONE_NAME" ]; do
    echo -e "${RED}根域名不能为空！${NC}"
    read -p "请重新输入您的根域名: " ZONE_NAME
done

echo "--------------------------------------------------"
echo "这个域名必须是您已在 Cloudflare 上创建的 A 记录，且代理状态为“仅限DNS”。"
read -p "请输入您要用于 DDNS 的完整域名 (例如: server.yourdomain.com): " RECORD_NAME
while [ -z "$RECORD_NAME" ]; do
    echo -e "${RED}完整域名不能为空！${NC}"
    read -p "请重新输入您要用于 DDNS 的完整域名: " RECORD_NAME
done
echo "--------------------------------------------------"
echo ""

# --- 步骤 3: 创建 DDNS 核心脚本 ---
DDNS_SCRIPT_PATH="/root/cf_ddns.sh"
LOG_FILE="/var/log/cf_ddns.log"

echo -e "${YELLOW}--> 步骤 3: 正在生成 DDNS 核心更新脚本...${NC}"

# 使用 cat 和 EOF 创建脚本文件，可以保留格式并自动替换变量
cat << EOF > ${DDNS_SCRIPT_PATH}
#!/bin/bash

# --- Cloudflare DDNS 更新脚本 (由一键脚本自动生成) ---
CF_API_TOKEN="${CF_API_TOKEN}"
ZONE_NAME="${ZONE_NAME}"
RECORD_NAME="${RECORD_NAME}"
LOG_FILE="${LOG_FILE}"
# --- 配置结束 ---

# 日志记录函数
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> \${LOG_FILE}
}

log "--- 开始执行 DDNS 更新检查 ---"

# 获取当前公网 IPv4 地址
CURRENT_IP=\$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep "ip=" | cut -f2 -d'=')

if [ -z "\$CURRENT_IP" ]; then
    log "错误: 获取当前公网 IP 失败。请检查网络连接。"
    exit 1
fi

# 定义 Cloudflare API 相关变量
API_URL="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer \${CF_API_TOKEN}"
CONTENT_HEADER="Content-Type: application/json"

# 获取 Zone ID
ZONE_ID=\$(curl -s -X GET "\${API_URL}/zones?name=\${ZONE_NAME}" -H "\${AUTH_HEADER}" -H "\${CONTENT_HEADER}" | jq -r '.result[0].id')

if [ "\$ZONE_ID" == "null" ] || [ -z "\$ZONE_ID" ]; then
    log "错误: 无法获取 Zone ID。请检查您的根域名 ('\${ZONE_NAME}') 是否正确，或者 API 令牌是否有读取 Zone 的权限。"
    exit 1
fi

# 获取 DNS Record ID 和当前记录的 IP 地址
RECORD_INFO=\$(curl -s -X GET "\${API_URL}/zones/\${ZONE_ID}/dns_records?type=A&name=\${RECORD_NAME}" -H "\${AUTH_HEADER}" -H "\${CONTENT_HEADER}" | jq -r '.result[0] | .id + " " + .content')
RECORD_ID=\$(echo \$RECORD_INFO | cut -d' ' -f1)
OLD_IP=\$(echo \$RECORD_INFO | cut -d' ' -f2)

if [ "\$RECORD_ID" == "null" ] || [ -z "\$RECORD_ID" ]; then
    log "错误: 无法获取 Record ID。请检查您的完整域名 ('\${RECORD_NAME}') 是否已在 Cloudflare 的 DNS 记录中，并且类型为 'A'。"
    exit 1
fi

# 比较 IP 地址，如果不同则更新
if [ "\$CURRENT_IP" == "\$OLD_IP" ]; then
    log "IP 地址未变化 (\${CURRENT_IP})，无需更新。"
    exit 0
fi

log "IP 地址已变化: 旧 IP=\${OLD_IP}, 新 IP=\${CURRENT_IP}。正在更新..."

# 构建更新请求的数据
UPDATE_DATA=\$(printf '{"type":"A","name":"%s","content":"%s","ttl":120,"proxied":false}' "\$RECORD_NAME" "\$CURRENT_IP")

# 发送更新请求
RESPONSE=\$(curl -s -X PUT "\${API_URL}/zones/\${ZONE_ID}/dns_records/\${RECORD_ID}" -H "\${AUTH_HEADER}" -H "\${CONTENT_HEADER}" --data "\$UPDATE_DATA")

# 检查 API 返回结果
SUCCESS=\$(echo \$RESPONSE | jq -r '.success')

if [ "\$SUCCESS" == "true" ]; then
    log "成功: DNS 记录已更新！"
else
    # 提取并记录错误信息
    ERRORS=\$(echo \$RESPONSE | jq -r '.errors | .[] | .message' | paste -sd ", " -)
    log "失败: 更新失败。Cloudflare API 返回错误: \${ERRORS}"
    exit 1
fi

exit 0
EOF

# --- 步骤 4: 设置权限和日志文件 ---
chmod +x ${DDNS_SCRIPT_PATH}
touch ${LOG_FILE}
echo -e "${GREEN}DDNS 核心脚本已成功创建于 ${DDNS_SCRIPT_PATH}${NC}"
echo ""

# --- 步骤 5: 添加 Cron 定时任务 ---
echo -e "${YELLOW}--> 步骤 4: 正在设置定时任务 (Cron Job)...${NC}"
# 为防止重复添加，先尝试删除已存在的旧任务
(crontab -l 2>/dev/null | grep -v "${DDNS_SCRIPT_PATH}") | crontab -
# 添加新任务，每 5 分钟执行一次
(crontab -l 2>/dev/null; echo "*/5 * * * * ${DDNS_SCRIPT_PATH} >/dev/null 2>&1") | crontab -

# 验证是否添加成功
if crontab -l | grep -q "${DDNS_SCRIPT_PATH}"; then
    echo -e "${GREEN}定时任务设置成功！脚本将每 5 分钟自动运行一次。${NC}"
else
    echo -e "${RED}错误: 设置定时任务失败。请尝试手动运行 'crontab -e' 并添加以下行:${NC}"
    echo -e "${YELLOW}*/5 * * * * ${DDNS_SCRIPT_PATH} >/dev/null 2>&1${NC}"
fi
echo ""

# --- 步骤 6: 首次运行测试 ---
echo -e "${YELLOW}--> 步骤 5: 正在进行首次运行测试以验证配置...${NC}"
# 直接执行脚本，并将输出实时显示，同时也写入日志
${DDNS_SCRIPT_PATH}
echo "--------------------------------------------------"
echo -e "${GREEN}测试运行已完成。请检查下面的最新日志判断是否成功。${NC}"
# 暂停一秒，确保日志文件已写入
sleep 1
tail -n 5 ${LOG_FILE}
echo "--------------------------------------------------"
echo ""

# --- 完成 ---
echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}🎉 恭喜！所有配置已完成！ 🎉${NC}"
echo ""
echo -e "您的 DDNS 系统现在应该已经开始工作了。"
echo -e "您可以通过以下命令随时查看完整的运行日志:"
echo -e "${YELLOW}cat ${LOG_FILE}${NC}"
echo ""
echo -e "或者实时跟踪日志输出:"
echo -e "${YELLOW}tail -f ${LOG_FILE}${NC}"
echo ""
echo -e "您可以将此一键安装脚本 (${0}) 删除，但请务必保留核心的 DDNS 脚本:"
echo -e "${YELLOW}${DDNS_SCRIPT_PATH}${NC}"
echo -e "${GREEN}===================================================================${NC}"