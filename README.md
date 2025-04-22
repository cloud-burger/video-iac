# 📦 Video Infrastructure as Code (IaC)

Repositório de infraestrutura como código (IaC) para provisionamento de uma aplicação serverless de processamento de vídeos. A infraestrutura é declarada em Terraform e provisionada na AWS, com foco em modularidade, reutilização e automação via CI/CD.

---

## ⚙️ Funcionalidades

- Modularização de componentes de infraestrutura (ex: Lambda, S3, DynamoDB).
- Automação de deploy via GitHub Actions.
- Reutilização de módulos com variáveis parametrizadas.
- Suporte a múltiplos ambientes (ex: `dev`, `prod`).
- Gerenciamento de estado remoto via Terraform Cloud ou S3.

---

## 🏗️ Arquitetura

Este repositório é focado na orquestração da infraestrutura das uma aplicações de processamento de vídeos baseadas em AWS dos seguintes repositórios:
- [Video-notification](https://github.com/cloud-burger/video-notification)
- [Video-converter](https://github.com/cloud-burger/video-converter)

### Componentes provisionados:

| Serviço     | Finalidade                                                 |
|-------------|------------------------------------------------------------|
| Lambda      | Executar funções de processamento assíncrono dos vídeos   |
| S3          | Armazenar vídeos e arquivos `.zip` com screenshots        |
| DynamoDB    | Registro de notificações e controle de estado             |
| PostgreSQL  | Armazenar metadados e status dos vídeos                   |
| Cognito     | Autenticação e autorização de usuários                    |
| API Gateway | Exposição de endpoints REST                               |
| SQS         | Disparo de eventos para notificações                      |

---

## 📂 Estrutura do Repositório

```
video-iac/
├── apps/                   # Aplicações (ex: código das Lambdas)
├── modules/                # Módulos Terraform reutilizáveis
│   └── lambda/             # Módulo para funções Lambda
├── shared/                 # Infraestrutura compartilhada
├── .github/workflows/      # Pipelines CI/CD com GitHub Actions
└── main.tf / variables.tf  # Arquivos principais do Terraform
```

---

## 🚀 Como usar

### 1. Clone o repositório:

```bash
git clone https://github.com/cloud-burger/video-iac.git
cd video-iac
```

### 2. Configure suas variáveis de ambiente:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edite com suas configurações de ambiente
```

### 3. Inicialize e aplique:

```bash
terraform init
terraform plan
terraform apply
```

---

## 🛠️ Requisitos

- [Terraform](https://www.terraform.io/downloads)
- Conta AWS com permissões apropriadas
- [GitHub CLI](https://cli.github.com/) (opcional para workflows locais)

---

## 📄 Licença

Distribuído sob a licença MIT. Veja `LICENSE` para mais detalhes.
