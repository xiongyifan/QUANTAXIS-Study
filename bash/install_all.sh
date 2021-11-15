#!/bin/bash

# 安装Docker
# step 1: 安装必要的一些系统工具
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
# step 2: 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# Step 3: 写入软件源信息
sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# Step 4: 更新并安装Docker-CE
sudo apt-get -y update
sudo apt-get -y install docker-ce
# Step 5: 非root用户操作docker
### 官方说明里的设置方法，开始 ###
# 这里没有使用这种方法，因为会使脚本中断，原因不明
# 这种方法的好处是docker不用重启
# sudo groupadd docker
# sudo usermod -aG docker $USER
# newgrp docker
### 官方说明里的设置方法，结束 ### 
# 下面是非官方做法，好处是脚本不会中断，装完docker可以再接着装别的
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo systemctl restart docker
sudo chmod a+rw /var/run/docker.sock
# Step 6: 镜像加速
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
# Step 7: 安装docker-compose
sudo apt-get -y install docker-compose


# 安装QA
# Step 1: 下载docker-compose.yaml文件
wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml  # 不会覆盖已有文件
# wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml -O docker-compose.yaml  # 会覆盖已有文件
# Step 2: 创建数据卷
sudo docker volume create --name=qamg
sudo docker volume create --name=qacode
sudo docker volume create --name=pg-data
sudo docker volume create --name=qadag
sudo docker volume create --name=qaconf
sudo docker volume create --name=qauser
sudo docker volume create --name=qalog
# Step 3: 下载并创建docker容器
sudo docker-compose up -d
# Step 4: 安装新版pytdx，quantaxis
installNewPytdxQA(){
    # qacommunity-rust
	find_str=$1
	container=$2
	isInstallQA=$3
	echo ${container}
	find_file=`sudo docker inspect --format='{{.LogPath}}' ${container}`
	while :
	do
		# 判断匹配函数，匹配函数不为0，则包含给定字符
		if [ `sudo grep -c "${find_str}" ${find_file}` -ne '0' ];then
			sudo docker cp ./pytdx-1.72r1-py3-none-any.whl ${container}:/root
			sudo docker exec -it ${container} pip uninstall pytdx -y
			sudo docker exec -it ${container} pip install /root/pytdx-1.72r1-py3-none-any.whl

			if [ ${isInstallQA} = "true" ];then
				sudo docker cp ./quantaxis-1.10.19r0-py3-none-any.whl ${container}:/root
				sudo docker exec -it ${container} pip uninstall quantaxis -y
				sudo docker exec -it ${container} pip install /root/quantaxis-1.10.19r0-py3-none-any.whl
			fi
			break
		fi
		sleep 1s
	done
}
installNewPytdxQA "使用control-c停止此服务器" "qacommunity-rust" "true"
installNewPytdxQA "mingle: all alone" "qaweb" "true"
installNewPytdxQA "if you use ssh" "qamarketcollector" "false"

# Step 5: 重启容器
sudo docker-compose restart
# Step 6: 手动初始化
