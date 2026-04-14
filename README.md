# Ruby Auth API

## Visão Geral

Este projeto é uma API de autenticação desenvolvida com Ruby on Rails (modo API), focada em fornecer endpoints para cadastro, login e consulta de perfil de usuários. A autenticação é feita via JWT (JSON Web Token), permitindo que clientes web ou mobile autentiquem e acessem rotas protegidas sem necessidade de sessão no servidor.

### Principais Funcionalidades
- Cadastro de usuário (`POST /api/v1/signup`)
- Login com e-mail e senha, retornando um token JWT (`POST /api/v1/login`)
- Consulta de perfil autenticado, protegida por token (`GET /api/v1/me`)

### Tecnologias e Padrões
- **Ruby on Rails** (API mode)
- **JWT** para autenticação stateless
- **bcrypt** para criptografia de senhas
- **PostgreSQL** como banco de dados padrão
- **RSpec**, **FactoryBot** e **Shoulda Matchers** para testes automatizados
- Estrutura de controllers versionada (`api/v1`), facilitando evolução da API

### Estrutura do Projeto
- `app/models/user.rb`: modelo do usuário, com validações e autenticação segura
- `app/controllers/api/v1/users_controller.rb`: cadastro e perfil
- `app/controllers/api/v1/auth_controller.rb`: login
- `app/services/jwt_service.rb`: geração e validação de tokens JWT
- `spec/`: testes automatizados

### Exemplos de Uso
**Cadastro:**
```http
POST /api/v1/signup
{
	"user": {
		"full_name": "Nome Exemplo",
		"email": "email@exemplo.com",
		"password": "senha123",
		"password_confirmation": "senha123"
	}
}
```

**Login:**
```http
POST /api/v1/login
{
	"email": "email@exemplo.com",
	"password": "senha123"
}
```

**Perfil (rota protegida):**
```http
GET /api/v1/me
Authorization: Bearer <seu_token_jwt>
```

---

## Como Rodar o Projeto

### Pré-requisitos

- Ruby 3.2.2 (recomendado via [rbenv](https://github.com/rbenv/rbenv))
- PostgreSQL em execução localmente
- Bundler (`gem install bundler`)

### 1. Instalar dependências

```bash
bundle install
```

### 2. Configurar variáveis de ambiente

O banco usa as variáveis `DB_USERNAME` e `DB_PASSWORD` (padrão: `postgres`/`postgres`). Para sobrescrever, exporte antes de rodar:

```bash
export DB_USERNAME=seu_usuario
export DB_PASSWORD=sua_senha
```

### 3. Criar e migrar o banco de dados

```bash
rails db:create
rails db:migrate
```

### 4. Iniciar o servidor

```bash
rails server
```

A API estará disponível em `http://localhost:3000`.

### 5. Rodar os testes

```bash
bundle exec rspec
```

### Docker (opcional)

```bash
docker build -t ruby_auth_api .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<valor de config/master.key> --name ruby_auth_api ruby_auth_api
```

---
Consulte o arquivo RUBY_ESTUDO.md para um guia detalhado de implementação, testes e convenções adotadas.
