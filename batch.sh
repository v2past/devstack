#!/bin/bash

# 获取当前机器IP地址
DEFAULT_IP=$(hostname -I | awk '{print $1}')

# 提示用户输入主机IP地址和主机名
read -p "请输入管理 [$DEFAULT_IP]: " HOST_IP
HOST_IP=${HOST_IP:-$DEFAULT_IP}
read -p "请输入主机名: " HOST_NAME

# 修改主机名
hostnamectl set-hostname $HOST_NAME

# 修改hosts文件
echo -e "$HOST_IP\t$HOST_NAME" | sudo tee -a /etc/hosts > /dev/null

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root." 
   echo "Creating a non-root user with sudo privileges..."
   
   # 创建一个新用户 cloud，并为其赋予sudo权限，设置密码为 admin@123
   adduser cloud --gecos "" --disabled-password
   echo 'cloud:admin@123' | chpasswd
   usermod -aG sudo cloud
   
   # 切换到新用户并重新执行脚本
   su cloud << EOF
cd ~
$(tail -n +2 "$0")
EOF
   
   # 脚本执行完毕后，退出当前会话
   exit
fi

# 删除旧的DevStack文件夹
rm -rf devstack/

# 下载并安装DevStack
git clone https://git.openstack.org/openstack-dev/devstack
cd devstack && ./stack.sh

# 编辑local.conf文件
cat << EOL >> local.conf
[[local|localrc]]
ADMIN_PASSWORD=admin
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD
HOST_IP=$HOST_IP
MYSQL_HOST=\$HOST_IP
RABBIT_HOST=\$HOST_IP
SERVICE_HOST=\$HOST_IP

# 启用必要的服务
ENABLED_SERVICES=c-api,c-bak,c-sch,c-vol,ceilometer-acentral,ceilometer-acompute,ceilometer-collector,ceilometer-api,dstat,placement-api,placement-client,g-api,g-reg,key,n-api,n-cpu,s-account,s-container,s-object,s-proxy,tempest
EOL

# 运行stack.sh脚本
./stack.sh
