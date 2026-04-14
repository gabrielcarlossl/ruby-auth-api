# API de Autenticação com Ruby on Rails

Guia completo para construir uma API de autenticação seguindo o padrão MVC, com testes automatizados.

---

## Sumário

1. [Pré-requisitos](#1-pré-requisitos)
2. [Criando o projeto](#2-criando-o-projeto)
3. [Configurando as Gems](#3-configurando-as-gems)
4. [Configurando o Banco de Dados](#4-configurando-o-banco-de-dados)
5. [Model — Camada M do MVC](#5-model--camada-m-do-mvc)
6. [Rotas — Definindo os endpoints](#6-rotas--definindo-os-endpoints)
7. [Controller — Camada C do MVC](#7-controller--camada-c-do-mvc)
8. [JWT — Autenticação com Token](#8-jwt--autenticação-com-token)
9. [Testando a API manualmente](#9-testando-a-api-manualmente)
10. [Testes Automatizados com RSpec](#10-testes-automatizados-com-rspec)
11. [Estrutura final do projeto](#11-estrutura-final-do-projeto)

---

## 1. Pré-requisitos

### 1.1 Instalando Ruby via rbenv (Linux)

O `rbenv` é o gerenciador de versões do Ruby recomendado. Ele permite instalar e alternar entre versões facilmente.

**Instale as dependências do sistema:**

```bash
sudo apt update
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev \
  autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
```

**Instale o rbenv e o ruby-build:**

```bash
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
```

**Adicione o rbenv ao seu shell (zsh):**

```bash
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc
```

**Instale o Ruby:**

```bash
rbenv install 3.2.2
rbenv global 3.2.2
```

Verifique a instalação:

```bash
ruby -v
# ruby 3.2.2 (...)
gem -v
```

### 1.2 Instalando o Rails e o Bundler

Com o Ruby instalado, o `gem` já estará disponível:

```bash
gem install rails bundler
rbenv rehash   # atualiza os shims do rbenv após instalar novas gems
rails -v
# Rails 8.x.x
```

### 1.3 Instalando o PostgreSQL (opcional)

Caso queira usar PostgreSQL em vez de SQLite:

```bash
sudo apt install -y postgresql postgresql-contrib libpq-dev
sudo service postgresql start

# Cria um usuário postgres com senha
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
```

> Durante os estudos, você pode usar `-d sqlite3` na criação do projeto para evitar configurar o PostgreSQL.

---

## 2. Criando o projeto

O flag `--api` cria um projeto Rails em modo API, removendo views, assets e middlewares desnecessários para uma API REST.

```bash
rails new ruby-auth-api --api -d postgresql
```

> Troque `-d postgresql` por `-d sqlite3` se quiser usar SQLite durante os estudos.

Entre na pasta do projeto:

```bash
cd ruby-auth-api
```

---

## 3. Configurando as Gems

Abra o arquivo `Gemfile` e adicione as seguintes gems:

```ruby
# Gemfile

# Autenticação com token JWT
gem 'jwt'

# Criptografia de senhas
gem 'bcrypt', '~> 3.1.7'

# Rack CORS — permite requisições de origens diferentes (frontend, Postman etc.)
gem 'rack-cors'

group :development, :test do
  # Framework de testes
  gem 'rspec-rails'

  # Fábrica de dados para testes
  gem 'factory_bot_rails'

  # Dados falsos para preencher factories
  gem 'faker'

  # Matchers extras para RSpec
  gem 'shoulda-matchers'
end
```

Instale as gems:

```bash
bundle install
```

---

## 4. Configurando o Banco de Dados

### 4.1 Variáveis de ambiente

Abra `config/database.yml` e configure as credenciais. Para desenvolvimento, o padrão já funciona com PostgreSQL local:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch("DB_USERNAME") { "postgres" } %>
  password: <%= ENV.fetch("DB_PASSWORD") { "" } %>
  host: localhost

development:
  <<: *default
  database: ruby_auth_api_development

test:
  <<: *default
  database: ruby_auth_api_test
```

### 4.2 Criar o banco

```bash
rails db:create
```

---

## 5. Model — Camada M do MVC

O **Model** representa os dados e as regras de negócio. Aqui ficam as validações, associações e a lógica relacionada ao usuário.

### 5.1 Gerando o Model User

```bash
rails generate model User full_name:string email:string password_digest:string
```

Esse comando gera:
- `app/models/user.rb` — o modelo
- `db/migrate/XXXXXXXXXXXXXX_create_users.rb` — a migration

> `password_digest` é o campo que o `bcrypt` usa para armazenar a senha criptografada. Nunca armazene senhas em texto puro.

### 5.2 Editando a Migration

Abra o arquivo em `db/migrate/..._create_users.rb` e deixe assim:

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :full_name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

Execute a migration para criar a tabela:

```bash
rails db:migrate
```

### 5.3 Editando o Model

Abra `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  # has_secure_password usa o bcrypt para criptografar a senha.
  # Ele adiciona automaticamente os atributos virtuais:
  # :password e :password_confirmation
  has_secure_password

  # Validações
  validates :full_name, presence: true, length: { minimum: 3, maximum: 100 }

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
            length: { minimum: 6 },
            allow_nil: true # permite atualizar outros campos sem re-informar senha

  # Normaliza o email para minúsculas antes de salvar
  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end
```

> **O que é `has_secure_password`?**
> É um método do Rails que integra o `bcrypt` ao modelo. Ele cria:
> - O atributo virtual `:password` (não salvo no banco)
> - O atributo virtual `:password_confirmation` (para comparação)
> - A validação automática de que `password` e `password_confirmation` são iguais
> - O método `authenticate(senha)` para verificar a senha no login

---

## 6. Rotas — Definindo os endpoints

Abra `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Cadastro de novo usuário
      post '/signup', to: 'users#create'

      # Login — retorna o token JWT
      post '/login',  to: 'auth#login'

      # Rota protegida de exemplo (requer autenticação)
      get  '/me',     to: 'users#show'
    end
  end
end
```

> **Por que `namespace :api` e `namespace :v1`?**
> É uma boa prática versionar sua API. Assim, futuramente você pode criar `/api/v2/...` sem quebrar clientes que usam a versão 1.

Verifique as rotas geradas:

```bash
rails routes
```

---

## 7. Controller — Camada C do MVC

O **Controller** recebe as requisições HTTP, chama o Model e devolve a resposta JSON.

### 7.1 Application Controller base

Abra `app/controllers/application_controller.rb` e configure os métodos de autenticação compartilhados:

```ruby
class ApplicationController < ActionController::API
  # Método chamado antes das ações protegidas
  def authenticate_request!
    token = extract_token_from_header
    decoded = JwtService.decode(token)

    if decoded
      @current_user = User.find_by(id: decoded[:user_id])
      render json: { error: 'Usuário não encontrado' }, status: :unauthorized unless @current_user
    else
      render json: { error: 'Token inválido ou expirado' }, status: :unauthorized
    end
  end

  private

  def extract_token_from_header
    # O token é enviado no header: Authorization: Bearer <token>
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end
end
```

### 7.2 Criando a estrutura de pastas

```bash
mkdir -p app/controllers/api/v1
```

### 7.3 UsersController — Cadastro e perfil

Crie `app/controllers/api/v1/users_controller.rb`:

```ruby
module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_request!, only: [:show]

      # POST /api/v1/signup
      def create
        user = User.new(user_params)

        if user.save
          token = JwtService.encode(user_id: user.id)
          render json: {
            message: 'Usuário criado com sucesso',
            token: token,
            user: user_response(user)
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/me
      def show
        render json: { user: user_response(@current_user) }, status: :ok
      end

      private

      # Strong Parameters — filtra apenas os campos permitidos da requisição
      def user_params
        params.require(:user).permit(:full_name, :email, :password, :password_confirmation)
      end

      # Serializa apenas os dados que devem ser retornados ao cliente
      # Nunca exponha password_digest na resposta
      def user_response(user)
        {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          created_at: user.created_at
        }
      end
    end
  end
end
```

### 7.4 AuthController — Login

Crie `app/controllers/api/v1/auth_controller.rb`:

```ruby
module Api
  module V1
    class AuthController < ApplicationController
      # POST /api/v1/login
      def login
        user = User.find_by(email: params[:email]&.downcase)

        # authenticate() é fornecido pelo has_secure_password
        # compara a senha enviada com o hash armazenado no banco
        if user&.authenticate(params[:password])
          token = JwtService.encode(user_id: user.id)
          render json: {
            message: 'Login realizado com sucesso',
            token: token,
            user: {
              id: user.id,
              full_name: user.full_name,
              email: user.email
            }
          }, status: :ok
        else
          # Mesmo erro para email não encontrado e senha errada
          # Evita enumerar quais emails existem no sistema (segurança)
          render json: { error: 'Email ou senha inválidos' }, status: :unauthorized
        end
      end
    end
  end
end
```

---

## 8. JWT — Autenticação com Token

O **JWT (JSON Web Token)** é o padrão para autenticação stateless em APIs. O servidor não guarda sessão — o próprio token carrega as informações do usuário de forma segura.

### 8.1 Criando o serviço JWT

Crie a pasta e o arquivo:

```bash
mkdir -p app/services
```

Crie `app/services/jwt_service.rb`:

```ruby
class JwtService
  # Segredo usado para assinar o token — NUNCA exponha em código fonte
  # Em produção, use: Rails.application.credentials.secret_key_base
  SECRET_KEY = Rails.application.secret_key_base

  # Gera um token JWT com os dados do payload
  # expires_in: tempo de validade (padrão: 24h)
  def self.encode(payload, expires_in: 24.hours)
    payload[:exp] = expires_in.from_now.to_i
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Decodifica e valida o token
  # Retorna o payload como HashWithIndifferentAccess ou nil se inválido
  def self.decode(token)
    return nil if token.blank?

    decoded = JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
```

> **Como o JWT funciona:**
> 1. No login, o servidor gera um token assinado com `SECRET_KEY` contendo o `user_id`
> 2. O cliente armazena esse token (localStorage, cookie etc.)
> 3. Em cada requisição protegida, o cliente envia o token no header `Authorization: Bearer <token>`
> 4. O servidor decodifica e valida o token sem precisar consultar banco de dados para validar a sessão

### 8.2 Configurando CORS

Abra `config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Em produção, substitua '*' pela URL do seu frontend
    origins '*'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization']
  end
end
```

---

## 9. Testando a API manualmente

Inicie o servidor:

```bash
rails server
# ou
rails s
```

### 9.1 Cadastro (POST /api/v1/signup)

```bash
curl -X POST http://localhost:3000/api/v1/signup \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "full_name": "Gabriel Silva",
      "email": "gabriel@email.com",
      "password": "senha123",
      "password_confirmation": "senha123"
    }
  }'
```

Resposta esperada (`201 Created`):

```json
{
  "message": "Usuário criado com sucesso",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "full_name": "Gabriel Silva",
    "email": "gabriel@email.com",
    "created_at": "2026-04-14T10:00:00.000Z"
  }
}
```

### 9.2 Login (POST /api/v1/login)

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "gabriel@email.com",
    "password": "senha123"
  }'
```

### 9.3 Rota protegida (GET /api/v1/me)

Use o token recebido no login:

```bash
curl -X GET http://localhost:3000/api/v1/me \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
```

---

## 10. Testes Automatizados com RSpec

Testes garantem que o código continua funcionando conforme você evolui o projeto.

### 10.1 Instalando o RSpec

```bash
rails generate rspec:install
```

Isso cria:
- `.rspec` — configurações do RSpec
- `spec/spec_helper.rb`
- `spec/rails_helper.rb`

### 10.2 Configurando o rails_helper

Abra `spec/rails_helper.rb` e adicione ao bloco `RSpec.configure`:

```ruby
RSpec.configure do |config|
  # Inclui helpers do FactoryBot sem precisar escrever FactoryBot.create(...)
  config.include FactoryBot::Syntax::Methods
end

# Configura o Shoulda Matchers para usar com RSpec e Rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### 10.3 Criando a Factory do User

Crie `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    full_name             { Faker::Name.full_name }
    email                 { Faker::Internet.unique.email }
    password              { 'senha123' }
    password_confirmation { 'senha123' }
  end
end
```

### 10.4 Teste do Model

Crie `spec/models/user_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  # Testa que a factory está configurada corretamente
  it 'possui uma factory válida' do
    expect(build(:user)).to be_valid
  end

  # Testes de presença
  describe 'validações de presença' do
    it { should validate_presence_of(:full_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:password_digest) }
  end

  # Testes de unicidade
  describe 'validações de unicidade' do
    subject { create(:user) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  # Testes de tamanho
  describe 'validações de tamanho' do
    it { should validate_length_of(:full_name).is_at_least(3).is_at_most(100) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  # Testa a autenticação de senha
  describe '#authenticate' do
    let(:user) { create(:user, password: 'minhasenha') }

    it 'retorna o usuário com senha correta' do
      expect(user.authenticate('minhasenha')).to eq(user)
    end

    it 'retorna false com senha errada' do
      expect(user.authenticate('senhaerrada')).to be_falsy
    end
  end

  # Testa a normalização do email
  describe 'normalização do email' do
    it 'salva o email em minúsculas' do
      user = create(:user, email: 'TESTE@EMAIL.COM')
      expect(user.email).to eq('teste@email.com')
    end
  end
end
```

### 10.5 Teste do JwtService

Crie `spec/services/jwt_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe JwtService do
  let(:payload) { { user_id: 1 } }

  describe '.encode' do
    it 'gera um token JWT' do
      token = JwtService.encode(payload)
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # header.payload.signature
    end
  end

  describe '.decode' do
    it 'decodifica um token válido' do
      token = JwtService.encode(payload)
      decoded = JwtService.decode(token)
      expect(decoded[:user_id]).to eq(1)
    end

    it 'retorna nil para token inválido' do
      expect(JwtService.decode('token.invalido.aqui')).to be_nil
    end

    it 'retorna nil para token expirado' do
      token = JwtService.encode(payload, expires_in: -1.hour)
      expect(JwtService.decode(token)).to be_nil
    end
  end
end
```

### 10.6 Testes de Request (Integração)

Os testes de request testam o fluxo completo da requisição HTTP até a resposta.

Crie `spec/requests/api/v1/users_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  describe 'POST /api/v1/signup' do
    let(:valid_params) do
      {
        user: {
          full_name: 'Gabriel Silva',
          email: 'gabriel@email.com',
          password: 'senha123',
          password_confirmation: 'senha123'
        }
      }
    end

    context 'com dados válidos' do
      it 'cria o usuário e retorna status 201' do
        post '/api/v1/signup', params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include('token', 'user')
      end

      it 'cria o usuário no banco de dados' do
        expect {
          post '/api/v1/signup', params: valid_params, as: :json
        }.to change(User, :count).by(1)
      end
    end

    context 'com email já cadastrado' do
      before { create(:user, email: 'gabriel@email.com') }

      it 'retorna status 422 e mensagem de erro' do
        post '/api/v1/signup', params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include('errors')
      end
    end

    context 'com senhas que não coincidem' do
      it 'retorna status 422' do
        params = valid_params.deep_merge(user: { password_confirmation: 'outrasenha' })
        post '/api/v1/signup', params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/me' do
    let(:user) { create(:user) }

    context 'com token válido' do
      it 'retorna os dados do usuário autenticado' do
        token = JwtService.encode(user_id: user.id)
        get '/api/v1/me', headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['user']['email']).to eq(user.email)
      end
    end

    context 'sem token' do
      it 'retorna status 401' do
        get '/api/v1/me'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

Crie `spec/requests/api/v1/auth_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  describe 'POST /api/v1/login' do
    let!(:user) { create(:user, email: 'gabriel@email.com', password: 'senha123') }

    context 'com credenciais válidas' do
      it 'retorna status 200 e o token JWT' do
        post '/api/v1/login',
             params: { email: 'gabriel@email.com', password: 'senha123' },
             as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to include('token')
        expect(body['token']).not_to be_empty
      end
    end

    context 'com senha errada' do
      it 'retorna status 401' do
        post '/api/v1/login',
             params: { email: 'gabriel@email.com', password: 'senhaerrada' },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'com email não cadastrado' do
      it 'retorna status 401' do
        post '/api/v1/login',
             params: { email: 'naoexiste@email.com', password: 'senha123' },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

### 10.7 Executando os testes

```bash
# Todos os testes
bundle exec rspec

# Somente testes do modelo
bundle exec rspec spec/models/

# Somente testes de request
bundle exec rspec spec/requests/

# Com saída detalhada
bundle exec rspec --format documentation
```

---

## 11. Estrutura final do projeto

```
ruby-auth-api/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb       # Autenticação compartilhada
│   │   └── api/
│   │       └── v1/
│   │           ├── users_controller.rb     # Cadastro e perfil
│   │           └── auth_controller.rb      # Login
│   ├── models/
│   │   └── user.rb                         # Validações e has_secure_password
│   └── services/
│       └── jwt_service.rb                  # Geração e decodificação de tokens
├── config/
│   ├── routes.rb                           # Endpoints da API
│   └── initializers/
│       └── cors.rb                         # Configuração de CORS
├── db/
│   └── migrate/
│       └── ..._create_users.rb             # Criação da tabela users
└── spec/
    ├── factories/
    │   └── users.rb                        # Dados de teste para User
    ├── models/
    │   └── user_spec.rb                    # Testes do Model
    ├── requests/
    │   └── api/
    │       └── v1/
    │           ├── users_spec.rb           # Testes de integração do cadastro
    │           └── auth_spec.rb            # Testes de integração do login
    └── services/
        └── jwt_service_spec.rb             # Testes do JwtService
```

---

## Conceitos aprendidos neste projeto

| Conceito | O que é |
|---|---|
| **MVC** | Separação entre Model (dados), View (apresentação, sem uso em API) e Controller (lógica HTTP) |
| **has_secure_password** | Integração nativa do Rails com bcrypt para hash de senhas |
| **Strong Parameters** | Filtragem de parâmetros para evitar mass assignment inseguro |
| **JWT** | Token stateless para autenticação sem sessão no servidor |
| **Namespace de rotas** | Versionamento da API com `/api/v1/...` |
| **before_action** | Hook chamado antes de uma action para autenticar a requisição |
| **RSpec** | Framework de testes BDD (describe/context/it) |
| **FactoryBot** | Criação de dados de teste sem duplicar código |
| **Teste de Request** | Teste de integração que cobre todo o ciclo request → response |
