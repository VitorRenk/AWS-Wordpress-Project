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
