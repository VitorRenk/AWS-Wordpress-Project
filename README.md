# Atividade AWS - Projeto para instalação do Wordpress pela EC2 na AWS Services

## Apresentação

### A proposta desse projeto é de subir instâncias EC2 privadas na AWS com um container utilizando a imagem do Wordpress. Para isso deve-se atender a algumas requisições, como conectar ao serviço RDS da Amazon, utilização do EFS para os arquivos estáticos, criação e configuração da VPC alocando as instâncias e os serviços nas redes privadas/seguras, criação de um Load Balancer para a conexão externa das instâncias privadas, e por último o Auto Scalling Group, com o objetivo de concluir esse sistema de forma segura e escalável.

<p align="center">
  <img src="imagens/proposta.png" alt="Proposta" />
</p>


---

- [1- Security Groups](#1-security-groups)
- [2- VPC - Virtual Private Cloud](#2-vpc---virtual-private-cloud)
- [3- EFS - Elastic File System](#3-efs---elastic-file-system)
- [4- RDS - Relational Database](#4-rds---relational-database)
- [5- Instância EC2 e User Data](#5-instância-ec2-e-user-data)
- [6- Acesso ao EC2 e Bastion Host](#6-acesso-ao-ec2-e-bastion-host)
- [7- Load Balancer](#7-load-balancer)
- [8- ASG - Auto Scaling Group](#8-asg---auto-scaling-group)
- [Conclusão](#conclusão)

---

### 1. Security Groups

Os grupos de segurança são extremamente importantes para garantir que a nossa aplicação do Wordpress seja efetuada com segurança, garantindo nossa integridade a um acesso seguro e confiável. Portanto é necessário alocar as ports corretas nas **Inbound rules**. Segue os Security Groups utilizados nesse projeto:

### Inbound do Security Group EC2 privado

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|SSH             |10.0.0.x                  |22              |
|HTTP            |SG-LoadBalancer           |80              |
|Custom TCP      |SG-LoadBalancer           |8080            |
|NFS             |SG-EFS                    |2049            |
|MYSQL/AURORA    |SG-RDS                    |3306            |

### Inbound do Security Group LoadBalancer

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|HTTP            |0.0.0.0/0                 |80              |
|Custom TCP      |0.0.0.0/0                 |8080            |

### Inbound do Security Group EFS

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|NFS             |SG-EC2                    |2049            |

### Inbound do Security Group RDS

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|MYSQL/AURORA    |SG-EC2                    |3306            |

### Inbound do Security Group Bastion Host

|SERVIÇO         |MAPEAMENTO                |PORTA           |
|----------------|--------------------------|----------------|
|SSH             |0.0.0.0/0                 |22              |

Para as outbound rules deixamos all traffic 0.0.0.0/0.

---
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
            - Subnet CIDR block: 10.0.0.x
            - Tags:
                |KEY      |VALUE                |
                |---------|---------------------|
                |Name     |Pública-1            |
        - Subnet 2:
            - Subnet name: Privada-1
            - Availability Zone us-east-1a
            - Subnet CIDR block: 10.0.1.x
            - Tags:
                |KEY      |VALUE                |
                |---------|---------------------|
                |Name     |Privada-1            |
        - Subnet 3:
            - Subnet name: Pública-2
            - Availability Zone us-east-1b
            - Subnet CIDR block: 10.0.2.x
            - Tags:
                |KEY      |VALUE                |
                |---------|---------------------|
                |Name     |Pública-2            |
        - Subnet 4:
            - Subnet name: Privada-2
            - Availability Zone us-east-1b
            - Subnet CIDR block: 10.0.3.x
            - Tags:
                |KEY      |VALUE                |
                |---------|---------------------|
                |Name     |Privada-2            |
        - Create subnet

- Com as subnets criadas e alocadas na sua VPC, devemos agora criar as Route tables para estabelecer as conexões necessárias
- Vá até a aba Route tables
    - Create route table
        - Route-Pub
        - Sua VPC
        - Tags:
            |KEY      |VALUE                |
            |---------|---------------------|
            |Name     |Route-Pub            |
        - Agora mais uma para as subnets privadas
        - Create route table
        - Route-Priv
        - Sua VPC
        - Tags:
            |KEY      |VALUE                |
            |---------|---------------------|
            |Name     |Route-Priv           |
        - Agora com as route tables da nossa VPC criada, partimos para a etapa de configuração delas, sendo assim, devemos criar o internet gateway (IGW) para que a VPC crie conexão com o mundo externo
- Vá para a aba internet gateways
- Create internet gateway
    - Informe um nome para o IGW
    - Tags:
        |KEY      |VALUE                |
        |---------|---------------------|
        |Name     |IGW-Wordpress        |
    - Selecione o seu IGW
    - Attach to VPC, selecione sua VPC
    - Agora criamos um NAT gateway para que suas instâncias privadas crie a conexão necessária para a instalação dos pacotes do user data
- Vá para a aba NAT gateways
    - Create NAT gateway
        - Nomeie seu NAT
        - Selecione a subnet pública, pode ser qualquer uma
        - Allocate Elastic IP
        - Tags:
            |KEY      |VALUE                |
            |---------|---------------------|
            |Name     |NAT-Wordpress        |
- Retorne para as configurações da sua VPC
    - Selecione sua route table pública
        - Routes, edit route
        - Edit routes
            - 0.0.0.0/0 - Sua Internet Gateway
        - Subnet associations
            - Adicione as suas subnets públicas as suas explicit subnet associations
    - Agora selecione sua route table privada
        - Edit routes
            - 0.0.0.0/0 - Sua NAT gateway
        - Subnet associations
            - Adicione as suas subnets privadas as suas explicit subnet associations

<p align="center">
  <img src="imagens/vpc.png" alt="VPC" />
</p>


---
### 3. EFS - Elastic File System

O EFS é um serviço de sistema de arquivos escalável que permite que múltiplas instâncias EC2 acessem simultaneamente o mesmo sistema de arquivos compartilhado, nos auxiliando imensamente para a nossa aplicação, resguardando o nosso armazenamento.
- Create file system
    - Nomeie seu EFS
    - Selecione a sua VPC
    - Create

O EFS criado possui a Availability Zone Regional, determinando que o sistema de arquivos é projetado para estar disponível e replicado automaticamente em todas as AZs dentro dessa mesma região da AWS. Agora para a últimas etapas da configuração, devemos ir em:
- Network
    - Manage
        - Adicionar a sua VPC
        - Em Mount targets, selecionamos as availability zones disponíveis, portanto como criamos apenas a us-east-1a e us-east-1b, deixamos estas com as subnets privadas
        - Deixamos as duas zonas selecionadas com as subnets privadas com o seu respectivo security group EFS

---
### 4. RDS - Relational Database 

O RDS é um serviço da AWS que facilita a configuração, operação e escalabilidade de bancos de dados relacionais na nuvem. Ele automatiza tarefas administrativas, permitindo que o usuário se concentre no desenvolvimento e na otimização das suas aplicações. O Wordpress exige um banco de dados para funcionar, e o RDS nos proporciona um banco de dados do tipo MYSQL para esta tarefa.
- Procure por RDS na barra de pesquisa da AWS
- Databases
- Create Database
    - Engine:
        - MySQL
        - MySQL Community
        - Engine version: MySQL 8.0.39
    - Templates: Free tier
    - Settings:
        - DB instance identifier: selecione o identificador do seu banco de dados
        - Master username: admin
        - Credentials management: Self managed
        - Password: selecione sua senha
    - Instance configuration: db.t3.micro
    - Storage type: General Purpose SSD (gp2)
    - Connectivity:
        - Compute resource: Don't connect to an EC2 compute resource
        - VPC: Selecione sua VPC
        - DB subnet group: Create new DB Subnet Group
        - Public access: No
        - Security Group: RDS (como foi configurado anteriormente)
        - Availability zone: No preference
        - Certificate authority: Default
    - Additional configuration
        - **Initial database name:** Selecione o nome para o seu banco (muito importante)
    - Create database

---
### 5. Instância EC2 e User Data

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

  - User Data, é a parte onde devemos colocar todos os nossos comandos para que a instância EC2 execute ao iniciar, portanto colocamos primeiramente para atualizar os pacotes e as instalações necessárias para a execução correta do container.
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

    # Instalação dos pacotes do banco de dados
    sudo apt install -y mysql-client-core-8.0

    # Pull da imagem do wordpress
    docker pull wordpress

    ```
    Agora com o docker instalado, é necessário executar a instalação do nfs-common, utilizado nos pacotes do ubuntu para a ferramenta efs-utils. O comando do mount é visualizado na aba Attach no EFS. 

    ```
    # Criação do EFS
    sudo mkdir -p /efs
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install -y nfs-common
    sudo mount -t nfs4 -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport (EFS-DNS-name):/ /efs
    ```
    Agora parte para a última etapa do user data, de criar o arquivo docker compose e determinar suas configurações.

    <p align="center">
      <img src="imagens/docker-compose.png" alt="Docker-compose" />
    </p>


    O docker compose determina as configurações para o container que você vai subir, para isso, o Wordpress necessita alocar o volume em algum lugar, nesse projeto foi-se necessário o EFS, em conjunto com o banco de dados do RDS. As ports garantem que tráfego será lido e dessa forma criada a imagem. As variáveis do ambiente são configuradas a partir das informações mostradas na criação do RDS.


    ```

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

    ```

 Nesse modelo, o user data consegue criar o arquivo do docker compose através da linha:
 > cat > /home/ubuntu/myapp/docker-compose.yaml <<EOL
 
Para facilitar o processo de criação da EC2.

---
### 6. Acesso ao EC2 e Bastion Host

Caso queria acessar a instância privada pelo Ubuntu, foi estipulado o passo a passo para conexão da instância através do Bastion Host, que é uma instância de servidor especialmente configurada para atuar como ponto seguro de acesso. Para isso criamos o Bastion Host com as seguintes configurações:
- Launch instance
    - Application: Ubuntu 24.04 LTS
    - Instance type: t2.micro
    - Key pair: a mesma ja utilizada
    - Network settings:
        - Mesma VPC
        - Subnet pública
        - Auto-assign pyblic IP: Enable
        - Select existing security group: Bastion
    - Storage: 8 GiB gp3
    - Launch instance

> Uma dica é alocar um IP elástico diretamente ao bastion host para evitar travamentos durante seu uso.

Agora é possível conectar via ssh na máquina bastion host, mas para isso necessita configurar as permissões da sua chave key pair, localize ela na sua máquina, após isso utilizando o seu Ubuntu pela sua máquina local, utilize o seguinte comando:
```
sudo chmod 400 /caminho/para/a/chave/chave.pem
scp -i /caminho/para/a/chave/chave.pem /caminho/para/a/chave/chave.pem ubuntu@x.x.x.x:/home/ubuntu
```
Agora conecte via ssh na sua máquina Ubuntu:
```
ssh -i chave.pem ubuntu@x.x.x.x
```
> O x.x.x.x se trata do IPv4 público da máquina do bastion host

Conectado a máquina do bastion host, agora é possível se conectar via ssh na máquina privada da EC2:
```
ssh -i chave.pem ubuntu@x.x.x.x
```
> Dessa vez o x.x.x.x se trata do IPv4 privado da instância EC2

Para garantir que a máquina privada baixou os pacotes necessários pelo user data, podemos simplesmente utilizar um:
```
docker --version
ou
sudo app-get update
```
Assim teremos certeza de que não ocorreu nenhum erro na sua criação.
Também podemos conferir se o EFS e RBS foram instalados corretamente com os seguintes comandos:
```
df -h
e
mysql -h (database_endpoint) -u admin -p
```

---
### 7. Load Balancer

O Load Balancer é um recurso que distribui automaticamente o tráfego de entrada de aplicações por várias instâncias, contêineres, etc. Ele melhora a escalabilidade, disponibilidade e resiliência de aplicações. O LB utiliza um recurso dele chamado health check, que avalia a saúda das instâncias ou destinos configurados e garante que o tráfego só seja direcionados para aqueles que estão funcionando corretamente, expondo essas instâncias saudáveis externamente à internet. Para a criação do Load Balancer, foi escolhido por questão de custos e operabilidade o Classic Load Balancer:
- Create Classic Load Balancer
    - Basic configuration
        - Name
        - Internet-facing
    - Network mapping
        - VPC
        - Mappings: Selecione duas availability zones públicas
    - Security Groups: LB
    - Listeners and routing
        - Listener Protocol: HTTP
        - Listener port: 80
        - Instance protocol: HTTP
        - Instance port: 80
    - Health checks:
        - Ping protocol: HTTP
        - Ping port: 80
        - Ping path: /your/path
    - Create Load Balancer

---
### 8. ASG - Auto Scaling Group

O ASG permite gerenciar automaticamente a escalabilidade de um conjunto de instâncias EC2. Ele ajusta o número de instâncias para atender à demanda da sua aplicação, garantindo alta disponibilidade e otimizando custos. Sendo assim, o Auto Scaling criará automaticamente nossas instâncias privadas quando necessário.

Para a criação do ASG foi efetuado os seguintes passos:
- Create Auto Scaling Group
    - Step 1:
        - Name
        - Template: EC2
    - Step 2:
        - Network:
            - VPC
            - Availability zones: escolher suas duas privadas
            - Availability zone distribuiton: Balanced
    - Step 3:
        - Load Balancing:
            - Attach to an existing load balancer
        - Choose from Classic Load Balancers: Selecione a sua
        - No VPC Lattice service
        - Health checks:
            - Turn on Elastic Load Balancing health checks
    - Step 4:
        - Desired capacity: sua escolha
        - Min desired capacity: sua escolha
        - Max desired capacity: sua escolha
    - Create ASG

Com essa ferramenta as instâncias EC2 serão criadas automaticamente e estarão sendo colocadas como target instances pelo Load Balancer para a validação do health check.

<p align="center">
  <img src="imagens/diagrama.png" alt="Diagrama" />
</p>

---
### Conclusão

Com esse projeto, foi possível entender os conceitos básicos da utilizações de instâncias EC2, e sua arquitetura para aplicações escaláveis e seguras, com métodos práticos e eficazes no qual me exigiu um esforço considerável para concluir. 










