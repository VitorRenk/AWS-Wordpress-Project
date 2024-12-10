#!/bin/bash
# Atualiza os pacotes do sistema
sudo apt update -y && sudo apt upgrade -y

# Instala pacotes necessários
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Adiciona a chave GPG oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adiciona o repositório do Docker informando para o apt onde buscar os pacotes
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza novamente os pacotes para incluir o repositório do Docker
sudo apt update -y

# Instala o Docker CE (Community Edition)
# Instala o docker daemon, linha de comando e a ferramenta de tempo de execução de conteiners usada pelo docker
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Inicia e habilita o serviço Docker para iniciar no boot
sudo systemctl start docker
sudo systemctl enable docker

# Adiciona o usuário ao grupo docker para evitar uso do sudo
sudo usermod -aG docker ubuntu

sudo apt install -y mysql-client-core-8.0

docker pull wordpress

# Criação do EFS
sudo mkdir -p /efs
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y nfs-common
sudo mount -t nfs4 -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport (EFS-DNS-name):/ /efs

# Criar diretório onde o docker-compose.yaml será salvo
sudo mkdir -p /home/ubuntu/myapp

# Criar o arquivo docker-compose.yaml com o conteúdo necessário
cat > /home/ubuntu/myapp/docker-compose.yaml <<EOL
version: '3.8'

services:
wordpress:
    image: wordpress:latest
    restart: always
    ports:
    - "80:80"
    environment:
        WORDPRESS_DB_HOST: rds/endpoint:3306
        WORDPRESS_DB_NAME: your/database/name
        WORDPRESS_DB_USER: your/database/user
        WORDPRESS_DB_PASSWORD: your/database/password
    volumes:
        - /efs/efs_wordpress:/var/www/html


EOL

#Instala o Docker compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


# Iniciar o Docker Compose
cd /home/ubuntu/myapp
docker compose up -d
