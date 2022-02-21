#!/bin/bash

# 安装QA
# 1. 下载docker-compose.yaml文件
# wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml  # 不会覆盖已有文件
wget https://gitee.com/xiongyifan/quantaxis-study/raw/master/docker/docker-compose.yaml -O docker-compose.yaml  # 会覆盖已有文件
# 2. 创建数据卷
sudo docker volume create --name=qamg
sudo docker volume create --name=qacode
sudo docker volume create --name=pg-data
sudo docker volume create --name=qadag
sudo docker volume create --name=qaconf
sudo docker volume create --name=qauser
sudo docker volume create --name=qalog
# 3. 下载并创建docker容器
sudo docker-compose up -d
# 4. 安装群文件中的pytdx，quantaxis
# 4.1 获取pytdx，quantaxis的文件名
fileNames=$(ls)
qaFileName=''
pytdxFileName=''

for fileName in $fileNames
do
	if [ ${fileName:0:5} == 'pytdx' ]
	then
   		pytdxFileName=$fileName
  fi

  if [ "${fileName:0:9}" == 'quantaxis' ]
	then
   		qaFileName=$fileName
  fi
done

echo ${pytdxFileName}
echo ${qaFileName}

# 4.2 安装函数
installNewPytdxQA(){
  # findStr，当容器日志中出现指定字符串时说明容器启动完成了，这个时候可以开始安装群文件中的qa和pytdx版本。
  # 这么做的原因是容器自己也会安装qa和pytdx，要等它先装完，然后你再卸载安装，否则你装的会被容器安装的覆盖掉。
	findStr=$1
	# containerName, 容器名，这个容器名在docker-compose.yaml中container_name中指定
	containerName=$2
	# isInstallQA，是否安装群文件中的qa。qamarketcollector容器可以不安装群中qa版本，因为不影响使用。
	isInstallQA=$3
	echo ${containerName}
	# 找到容器对应的日志文件
	findFile=$(sudo docker inspect --format='{{.LogPath}}' ${containerName})
	echo ${findFile}
	# 在日志文件中不断的查到findStr，找到后说明容器已经初始化完成，可以开始安装qa和pytdx。
	while :
	do
		# 判断匹配函数，匹配函数不为0，则包含给定字符
		if [ `sudo grep -c "${findStr}" ${findFile}` -ne '0' ];then
		  # 安装pytdx
			sudo docker cp ./${pydtxFileName} ${containerName}:/root
			sudo docker exec ${containerName} pip uninstall pytdx -y
			sudo docker exec ${containerName} pip install /root/${pydtxFileName}

      # 安装qa
			if [ ${isInstallQA} = "true" ];then
				sudo docker cp ./${quantaxisFileName} ${containerName}:/root
				sudo docker exec ${containerName} pip uninstall quantaxis -y
				sudo docker exec ${containerName} pip install /root/${quantaxisFileName}
			fi
			break
		fi
		sleep 1s
	done
}
# 4.3 安装
# 以，使用control-c停止此服务器，作用findStr，是根据容器首次启动的日志提取出来的，
# 当日志不再打印时，说明容器首次启动完成，在日志末尾找一段文本，测试能够在卸载后重新安装即可。
installNewPytdxQA "使用control-c停止此服务器" "qacommunity-rust" "true"
# mingle: all alone，同理
installNewPytdxQA "mingle: all alone" "qaweb" "true"
installNewPytdxQA "if you use ssh" "qamarketcollector" "false"

# Step 5: 重启容器
sudo docker-compose restart
# Step 6: 手动初始化
