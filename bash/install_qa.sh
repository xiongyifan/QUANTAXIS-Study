#!/bin/bash

# 安装QA
# Step 1: 下载docker-compose.yaml文件
# wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml  # 不会覆盖已有文件
wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml -O docker-compose.yaml  # 会覆盖已有文件
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
			sudo docker exec ${container} pip uninstall pytdx -y
			sudo docker exec ${container} pip install /root/pytdx-1.72r1-py3-none-any.whl

			if [ ${isInstallQA} = "true" ];then
				sudo docker cp ./quantaxis-1.10.19r0-py3-none-any.whl ${container}:/root
				sudo docker exec ${container} pip uninstall quantaxis -y
				sudo docker exec ${container} pip install /root/quantaxis-1.10.19r0-py3-none-any.whl
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
