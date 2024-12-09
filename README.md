# Atividade AWS - Projeto para subir uma aplicação do Wordpress pelo Docker

## Apresentação

### A proposta desse projeto é de subir instâncias EC2 privadas na AWS com um container, utilizando a imagem do Wordpress. Para isso deve-se atender a algumas requisições, como conectar ao serviço RDS da Amazon, utilização do EFS para os arquivos estáticos, criação e configuração da VPC alocando as instâncias e os serviços nas redes privadas/seguras, criação de um Load Balancer para a conexão externa das instâncias privadas, e por último o Auto Scalling Group. Tudo isso com o intuito de tornar esse sistema seguro e escalável.

### Imagem (proposta)
---

### [1. Security Groups]
### [2. Instância EC2 e User Data]

---

### 1. Security Groups

Os grupos de segurança são extremamente importantes para garantir que a nossa aplicação do Wordpress seja efetuada com segurança, garantindo nossa integridade a um acesso seguro e confiável. Portanto é necessário alocar as ports corretas nas **Inbound rules**. Segue os Security Groups utilizados nesse projeto:

### Inbound do Security Group EC2 privado

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|SSH             |10.0.0.0/16               |22              |
|HTTP            |SG-LoadBalancer           |80              |
|Custom TCP      |SG-LoadBalancer           |8080            |

### Inbound do Security Group LoadBalancer

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|HTTP            |0.0.0.0/0                 |80              |
|Custom TCP      |0.0.0.0/0                 |8080            |

### Inbound do Security Group EFS

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|NFS             |10.0.0.0/16               |2049            |

### Inbound do Security Group RDS

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|MYSQL           |10.0.0.0/16               |3306            |

### Inbound do Security Group Bastion Host

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|SSH             |10.0.0.0/16               |22              |

### 2. VPC - Virtual Private Cloud

A VPC se trata de uma rede virtual isolada dentro da infraestrutura da AWS, como se fosse um *datacenter privado* na nuvem, e é nela onde vamos criar as nossas subredes privadas e públicas para alocar os nossos serviços da aplicação. Portanto para começar vamos criar ela do zero, conforme os seguintes passo a passo:
 - Vá até a aba da VPC
 - Your VPCs
 - Create VPC
    - Resources to create: VPC only
    - Name tag: nomeie sua VPC
    - O bloco de endereço IPv4 nos permite selecionar o bloco que será criada a nossa VPC, e é crucial escolher aquele que nos melhor atenderá, como o 10.0.0.0/16, pois esse bloco evita a sobreposição com outras redes locais ou VPCs que você possa criar no futuro, ideal para ambiente de produção, desenvolvimento e testes.
    - No IPv6 CIDR block
    - Tenancy: Default
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |Nome da VPC          |
    - Create VPC
- Agora com ela criada, devemos configurar as Subnets, portanto vá até a aba das Subnets
- Create Subnet
- Selecione a sua VPC
- Subnet 1:
    - Subnet name: Pública-1
    - Availability Zone us-east-1a
    - Subnet CIDR block: 10.0.0.0/24
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |Pública-1            |
- Subnet 2:
    - Subnet name: Privada-1
    - Availability Zone us-east-1a
    - Subnet CIDR block: 10.0.1.0/24
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |Privada-1            |
- Subnet 3:
    - Subnet name: Pública-2
    - Availability Zone us-east-1b
    - Subnet CIDR block: 10.0.2.0/24
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |Pública-2            |
- Subnet 4:
    - Subnet name: Privada-2
    - Availability Zone us-east-1b
    - Subnet CIDR block: 10.0.3.0/24
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |Privada-2            |

### 3. Instância EC2 e User Data

A criação da EC2 é uma das etapas mais importantes, pois é aqui onde vamos configurar toda a parte da instância privada que vai subir o container do wordpress, para isso é necessário executar uma série de comandos que instalarão os pacotes necessários para que tudo funcione corretamente. 
Para isso vamos utilizar inicialmente o template, para nos auxiliar na criação das EC2 durante todo o processo, portanto deve-se seguir os seguintes passos:

- Dirija-se a aba da EC2 após conectar na sua conta da Amazon
- Launch Templates
- Create launch template
  - Informe o nome
  - Sistema operacional Ubuntu: AMI Ubuntu Server 24.04 LTS
  - Tipo de instância t2.micro
  - Criação da chave key pair, utilizada para conectar as suas instâncias
  - Network setting
    - Selecionar uma das suas subnet privada do seu VPC
    - Security Group da EC2
  - As Resource tags foram utilizadas da Compass UOL para criação das instâncias, por se tratar de uma conta administrada por eles:

    |Key         |Value                      |Resource types            |
    |------------|---------------------------|--------------------------|
    |CostCenter  |*Fornecido pela Compass*   |Instances & Volumes       |
    |Project     |*Fornecido pela Compass*   |Instances & Volumes       |
    |Name        |EC2                        |Instances & Volumes       |

  - User Data, é a parte onde devemos colocar todos os nossos comandos para que a instância EC2 execute ao iniciar, portanto colocamos primeiramente para atualizar os pacotes e as instalações necessárias para a execução do container.
    ```
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
    sudo mount -t nfs4 -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport (your_file_system_ID):/ /efs

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
        - "8080:80"
        environment:
        WORDPRESS_DB_HOST: (your_RDS_endpoint):3306
        WORDPRESS_DB_NAME: (your_RDS_name)
        WORDPRESS_DB_USER: (your_RDS_user)
        WORDPRESS_DB_PASSWORD: (your_RDS_password)
        volumes:
        - /efs/efs_wordpress:/var/www/html

    EOL

    #Instala o Docker compose
    sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose


    # Iniciar o Docker Compose
    cd /home/ubuntu/myapp
    docker compose up -d

    ```


















