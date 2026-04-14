# Convenções do Rails — Por que o comando é escrito assim?

```bash
rails generate model User full_name:string email:string password_digest:string
```

Esse comando parece estranho no início, mas cada parte segue uma convenção bem definida do Rails. Entender o **porquê** vai te ajudar a não decorar, mas sim a raciocinar.

---

## Por que `User` com letra maiúscula?

### A resposta curta

Porque `User` é o nome de uma **classe Ruby**, e em Ruby toda classe começa com letra maiúscula. Essa é uma regra da linguagem, não do Rails.

### A resposta completa

Quando você roda `rails generate model User`, o Rails vai criar o arquivo `app/models/user.rb` com este conteúdo:

```ruby
class User < ApplicationRecord
end
```

Em Ruby, classes são constantes, e **constantes sempre começam com letra maiúscula**. Se você tentasse criar uma classe `user` (minúsculo), o Ruby lançaria um erro de sintaxe:

```ruby
class user  # ERRO: SyntaxError — class/module name must be CONSTANT
end
```

### Convenção de nomenclatura do Rails (importante)

O Rails segue a convenção de **CamelCase** (cada palavra começa maiúscula) para nomes de modelos, e converte automaticamente para o formato correto em cada camada:

| O que você escreve | O Rails cria |
|---|---|
| `User` | classe `User`, tabela `users` |
| `BlogPost` | classe `BlogPost`, tabela `blog_posts` |
| `ProductCategory` | classe `ProductCategory`, tabela `product_categories` |

Perceba: o Rails é inteligente o suficiente para:
- Converter `CamelCase` → `snake_case` (para o nome do arquivo e da tabela)
- Pluralizar automaticamente o nome da tabela (`User` → `users`, `BlogPost` → `blog_posts`)

Isso é chamado de **Convention over Configuration** — um dos pilares do Rails. Você não precisa dizer ao Rails que a tabela se chama `users`, ele **deduz** isso a partir do nome da classe `User`.

---

## Por que os parâmetros são escritos com `:`?

```bash
full_name:string   email:string   password_digest:string
```

### O que esse formato representa

Cada argumento `nome:tipo` é uma instrução para o Rails criar **uma coluna no banco de dados**. A sintaxe é:

```
nome_da_coluna:tipo_de_dado
```

O `:` é apenas um **separador** — ele divide o nome da coluna do tipo de dado esperado. Não é sintaxe Ruby aqui, é apenas uma convenção do gerador de código do Rails para ser curto e legível na linha de comando.

### Os tipos disponíveis

| Tipo | O que armazena | Exemplo de uso |
|---|---|---|
| `string` | Texto curto (até ~255 chars) | nome, email, título |
| `text` | Texto longo | descrição, conteúdo de post |
| `integer` | Número inteiro | idade, quantidade |
| `float` | Número decimal | preço (prefira `decimal`) |
| `decimal` | Decimal com precisão | valores monetários |
| `boolean` | true / false | ativo, admin |
| `date` | Apenas data | data de nascimento |
| `datetime` | Data + horário | created_at, scheduled_at |
| `references` | Chave estrangeira (FK) | `user:references` → `user_id` |

### O que o Rails faz com essa informação

Quando você roda o comando, o Rails gera automaticamente a **migration** — um arquivo que descreve a criação da tabela no banco. Para o comando:

```bash
rails generate model User full_name:string email:string password_digest:string
```

Ele gera:

```ruby
# db/migrate/20260414_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :full_name        # <- full_name:string
      t.string :email            # <- email:string
      t.string :password_digest  # <- password_digest:string

      t.timestamps  # cria created_at e updated_at automaticamente
    end
  end
end
```

Você escreveu `full_name:string` na linha de comando → o Rails traduziu para `t.string :full_name` na migration. O `:` foi só o separador que ele usou para entender o que é nome e o que é tipo.

---

## Por que `password_digest` e não `password`?

Esse é um detalhe importante de segurança:

- `password` seria o campo com a senha em **texto puro** → nunca faça isso
- `password_digest` é o campo onde o `bcrypt` armazena o **hash** da senha

O método `has_secure_password` do Rails procura **especificamente** uma coluna chamada `password_digest`. Se você nomear diferente, o bcrypt não vai funcionar. O nome `digest` vem do inglês e significa "resumo criptográfico" — é exatamente isso que um hash é.

```
senha original: "senha123"
armazenado no banco: "$2a$12$K8e3zQ7mN...XOplWq9uD"  ← isso é o digest
```

---

## Resumo visual

```
rails generate model  User        full_name    :    string
                  │     │             │         │      │
                  │   Nome da      Nome da    sep.  Tipo da
              Gerador  classe      coluna            coluna
              de code  (Ruby —
                       maiúsculo)
```

---

## Outros exemplos para fixar

```bash
# Modelo de Post com título, conteúdo e referência ao autor
rails generate model Post title:string body:text published:boolean user:references

# Modelo de Produto com preço decimal
rails generate model Product name:string price:decimal stock:integer active:boolean

# Modelo de Comentário
rails generate model Comment content:text post:references user:references
```

Para cada um, o Rails vai:
1. Criar a classe com o nome exato que você passou (maiúsculo, CamelCase)
2. Criar a tabela no plural e em snake_case (`posts`, `products`, `comments`)
3. Criar cada coluna com o tipo especificado após o `:`
