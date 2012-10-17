Release do Ruby on Rails versão 4
===============================

* Ruby 1.9.3 ou verões superiores.
* Parâmetros Fortes
* Fila API
* Melhorias com Caches

Estas notas de lançamento cobrem as grandes mudanças, mas não incluem cada correção de bugs e cada mudança. Se você quiser ver tudo, confira a <a href="https://github.com/rails/rails/commits/master">lista de commits</a> no repositório principal do <a href="https://github.com/rails/rails/">Rails</a> no GitHub.

--------------------------------------------------------------------------------

Atualização do Rails 4.0
----------------------

TODO. Este é um guia WIP.

Se você está atualizando uma aplicação que já existe, que é uma ótima idéia ter uma boa cobertura de testes antes de ir afundo. Você também deve
primeiro atualizar para o Rails 3.2, caso se você ainda não ter, e tenha certeza que sua aplicação ainda corre como o esperado antes de tentar uma atualização para Rails 4.0. Em seguida, leve em conta os seguintes alterações:

### Rails 4.0 requer pelo menos o Ruby 1.9.3 ou superior

Rails 4.0 requer o Ruby 1.9.3 ou superior. O suporte para todas as versões anteriores do Ruby foi descartado oficialmente e você deve atualizar o seu mais cedo possível.

### O que atualizar em seus aplicativos:

*   Atualize seu Gemfile que depende
    * `rails = 4.0.0`
    * `sass-rails ~> 3.2.3`
    * `coffee-rails ~> 3.2.1`
    * `uglifier >= 1.0.3`

TODO. Atualizar as versões anteriores.

*   Rails 4.0 remove vendor/plugins completamente. Você tem que substituir esses plugins, extraindo-os como gems e adicioná-los em seu Gemfile. Se você optar por não fazer gems, você pode movê-los para, digamos, `lib/my_plugin/*` e adicione um inicializador apropriado em `config/initializers/my_plugin.rb`. 

TODO. Alterações de configuração em arquivos de ambiente

Criando uma aplicação com Rails 4.0
----------------------

``` ruby 
 Você deve ter a gem 'rails' instalada
$ rails new myapp
$ cd myapp
```

### Fornecendo Gems

Rails agora usa um Gemfile na raiz do aplicativo para determinar as gems que você necessita para o seu aplicativo para iniciar. Este Gemfile é processado pela gem [Bundler](https://github.com/carlhuda/bundler), que em seguida, instala todas as suas dependências. Ele pode até mesmo instalar todas as dependências localmente para o seu aplicativo para que ele não dependa das gems do sistema.

Mais informações: [página inicial Bundler](http://gembundler.com/)

### Vivendo no Limite

Bundler e Gemfile congelam sua aplicação Rails fácil como a torta com o novo comando dedicado de bundle. Se você quiser agrupar direto do repositório Git, você pode passar o flag --edge:

``` ruby
$ rails new myapp --edge
```

Se você tem um check-out local do repositório Rails e quer gere um aplicativo usando isso, você pode passar o flag --dev:

``` ruby
$ ruby /path/to/rails/railties/bin/rails new myapp --dev
```

Características Principais
----------------------

Documentação
----------------------

Guias são reescritos usando Markdown do GitHub.

Railties
----------------------

*   Permitir gerar scaffold/model/migration para aceitar um modificador polimórfico para references / belongs_to, por exemplo

	``` ruby
	rails g model Product supplier:references{polymorphic}
	```

	logo irá gerar o modelo com belongs_to :supplier, associação polymorphic: true e migração adequada.

*   Definir config.active_record.migration_error para :page_load para o desenvolvimento.

*   Adiciona um corredor para Rails::Railtie como um hook chamado apenas após o início do corredor.

*   Adicionar um caminho /rails/info/routes que mostra a mesma informação como rake routes 

*   Melhoria rake routes de saída para redirecionamentos.

*   Coloca todos os ambientes disponíveis no config.paths["config/environments"].

*   Adiciona config.queue_consumer para permitir que o consumo padrão a seja configurável.

*   Adicionar Rails.queue como uma interface com uma implementação padrão que consome jobs em um segmento separado.

*   Remover Rack::SSL em favor de ActionDispatch::SSL.

*   Permitem definir a classe que será usada para executar no console, além do IRB, com Rails.application.config.console=. É melhor para adicioná-la em bloco para o console.

    ```ruby
    # it can be added to config/application.rb
    console do
      # this block is called only when running console,
      # so we can safely require pry here
      require "pry"
      config.console = Pry
    end
    ```
		
*   Adicionar um método hide! para geradores Rails para esconder o namespace padrão gerado será exibido ao executar rails generate.

*   Scaffold agora usa content_tag_for em index.html.erb .

*   Rails::Plugin foi removido. Em vez de adicionar plugins para vendor/plugins, use gems ou Bundler com o caminho ou git dependências.

### Deprecações

Action Mailer
----------------------

*   Permitem definir as opções padrão do Action Mailer via config.action_mailer.default_options=.

*   Eleva uma exceção ActionView::MissingTemplate quando nenhum modelo implícito poderia ser encontrado.

*   De forma assíncrona enviar mensagens através do Rails Queue.

*   Opções de entrega (como configurações de SMTP) agora pode ser definida dinamicamente pelo mailer action.

    Opções de entrega são definidas através da chave `:delivery_method_options` chave no correio.

    ``` ruby 
    def welcome_mailer(user,company)
      delivery_options = { user_name: company.smtp_user, password: company.smtp_password, address: company.smtp_host }
      mail(to: user.email, subject: "Welcome!", delivery_method_options: delivery_options)
    end
    ```

Action Pack
----------------------

### Action Controller

*   Adiciona o método ActionController::Flash.add_flash_types para permitir que as pessoas registrarem seus tipos próprio Flash. por exemplo:

    ``` ruby
    class ApplicationController
      add_flash_types :error, :warning
    end
    ```

    Se você adicionar o código acima, você pode usar <%= error %> em uma erb, e redirect_to /foo, :error => 'message' em um controller.

*   Removeido a dependência Active Model de Action Pack.

*   Suporte a caracteres Unicode em rotas. Rota será automaticamente escada, assim em vez de escapar manualmente:

    ``` ruby
    get Rack::Utils.escape('こんにちは') => 'home#index'
    ```

    Você apenas tem que escrever a rota unicode:

    ``` ruby
    get 'こんにちは' => 'home#index'
    ```

*   Retornar formato adequado em exceções.

*   Extraído redirecionar lógica de:
    ActionController::ForceSSL::ClassMethods.force_ssl em
    ActionController::ForceSSL#force_ssl_redirect.

*   Parâmetros de URL path com codificação inválida agora levantar ActionController::BadRequest.

*   Consulta malformada e parâmetro hashes de solicitação agora levantar ActionController::BadRequest.

*   respond_to e respond_with agora levantar ActionController::UnknownFormat em vez de diretamente retornando cabeçalho 406. A exceção é resgatada e convertida para 406 no middleware de manipulação de exceção.

*   JSONP agora usa application/javascript, em vez de application/json como o tipo de MIME.

*    Argumentos de sessão passados para processar chamadas em testes funcionais estão agora incorporadas a sessão existente, enquanto que anteriormente iriam substituir a sessão existente. Essa mudança pode quebrar alguns testes existentes, se eles estão afirmando o conteúdo exato da sessão, mas não deve quebrar os testes existentes que apenas afirmam chaves individuais.

*    Formas de persistir registros usa sempre PATCH (através do _method hack).

*    Para os recursos, tanto PATCH e PUT são encaminhadas para a action update.

*    Não ignore o force_ssl em desenvolvimento. Esta é uma mudança de comportamento - use uma condição :if para recriar o comportamento antigo.

    ``` ruby 
    class AccountsController < ApplicationController
      force_ssl :if => :ssl_configured?
    
      def ssl_configured?
        !Rails.env.development?
      end
    end
    ```

#### Deprecações

*   Obsoleto ActionController::Integration em favor da ActionDispatch::Integration.

*   Obsoleto ActionController::IntegrationTest em favor de ActionDispatch::IntegrationTest.

*   Obsoleta ActionController::PerformanceTest em favor de ActionDispatch::PerformanceTest.

*   Obsoleta ActionController::AbstractRequest em favor de ActionDispatch::Request.

*   Obsoleta ActionController::Request em favor de ActionDispatch::Request.

*   Obsoleta ActionController::AbstractResponse em favor de ActionDispatch::Response.

*   Obsoleta ActionController::Response em favor de ActionDispatch::Response.

*   Obsoleta ActionController::Routing em favor de ActionDispatch::Routing.


### Action Dispatch

*    Adicionado roteamento Concern para declarar rotas comuns que podem ser reutilizadas dentro de outros resources e routes.

    Codigo Antes:

    ``` ruby
    resources :messages do
      resources :comments
    end
     
    resources :posts do
      resources :comments
      resources :images, only: :index
    end
    ```

    Codigo Depois:

    ``` ruby
    concern :commentable do
      resources :comments
    end
 
    concern :image_attachable do
      resources :images, only: :index
    end
     
    resources :messages, concerns: :commentable
     
    resources :posts, concerns: [:commentable, :image_attachable]
    ```

*   Mostrar rotas na página de exceção durante a depuração de um RoutingError em desenvolvimento.

*   Incluído mounted_helpers (ajudantes para acessar engines montadas) em ActionDispatch::IntegrationTest por padrão.

*   Adicionado middleware ActionDispatch::SSL que quando incluídos forçar todos os pedidos de estar sob o protocolo HTTPS

*   Copía rota de Constantes literais para os padrões de modo que a geração da url sabe sobre elas. As restrições copiadas são :protocol, :subdomain,
	:domain, :host e :port

*   Permite assert_redirected_to para o jogo contra uma expressão regular.

*   Adiciona um backtrace para a página de erro de roteamento em desenvolvimento.

*   assert_generates , assert_recognizes e assert_routing tudo em Assertion vez de RoutingError.

*   Permite que a raiz ajude o caminho a tomar um argumento string. Por exemplo, `root 'pages#main'` como um atalho para `root to: 'pages#main'`.

*   Adiciona suporte para o verbo PATCH: pedido de objetos responde a patch?. Rotas tem agora um novo método patch, e compreende :patch nos lugares existentes onde um verbo está configurado, como :via. Testes funcionais têm um novo método patch e testes de integração têm um novo método patch_via_redirect. Se :patch é o verbo padrão para atualizações, as edições são tuneladas como PATCH e não como PUT e encaminhando de acordo com a conformidade.

*   Testes de integração suporta o método OPTIONS.

*   expires_in aceita um flag must_revalidate. Se for verdade, "deve-revalidar" é adicionado ao cabeçalho Cache-Control.

*   Padrão de resposta agora sempre usa o seu bloco substituído em respond_with para tornar a sua resposta.

*   Desligado o modo de detalhe de rack-cache, ainda temos X-Rack-Cache para verificar essa informação.

#### Deprecações

### Action View

*   Remove a dependência Active Model de Action Pack.

*   Permiti a utilização mounted_helpers (ajudantes para acessar engines montadas) em ActionView::TestCase.

*   Faz o objeto atual e contador (quando se aplica) variáveis acessíveis na renderização de modelos com :object ou :collection.

*   Permiti a carga lenta do default_form_builder passando uma string em vez de uma constante.

*   Adicionado método de índice para classe FormBuilder

*   Adicionado suporte para layouts ao renderizar um parcial com uma coleção.

*   Remover :disable_with em favor da opção data-disable-with dos ajudantes submit_tag, button_tag e button_to.

*   Remover opção :mouseover do helper image_tag.

*   Modelos sem uma extensão de manipulador levanta agora um aviso de reprovação, mas ainda padrões para ERb. Em versões futuras, ele simplesmente irá retornar o conteúdo do modelo.

*   Adicionado uma opção divider de grouped_options_for_select para gerar um separador optgroup automaticamente, e depreciado prompt como terceiro argumento, em favor do uso de um hash de opções.

*   Adicionado helpers time_field e time_field_tag que fazem com que uma tag input[type="time"].

*    Removido a obsoleta apis text_helper de highlight, excerpt e word_wrap.

*    Remover o \n principal acrescentado pelo textarea em assert_select.

*    Valor padrão mudou para config.action_view.embed_authenticity_token_in_remote_forms para falso. Esta alteração quebra formas remotas que precisam trabalhar também sem JavaScript, por isso, se você precisar de tal comportamento, você pode defini-lo como verdadeiro ou explicitamente passar :authenticity_token => true nas opções do formulário.

*    Possibilita o uso de um bloco em helper button_to se o texto do botão é difícil de encaixar no parâmetro nome:

    ``` ruby
    <%= button_to [:make_happy, @user] do %>
      Make happy <strong><%= @user.name %></strong>
    <% end %>
    # => "<form method="post" action="/users/1/make_happy" class="button_to">
    #      <div>
    #        <button type="submit">
    #          Make happy <strong>Name</strong>
    #        </button>
    #      </div>
    #    </form>"
    ```

*   Substituido argumento booleano include_seconds com opção :include_seconds => true na assinatura de distance_of_time_in_words e time_ago_in_words.

*   Removido helpers button_to_function e link_to_function.

*   truncate agora sempre retorna um string HTML escapada. A opção :escape pode ser utilizado como false a não escapar do resultado.

*   Adicionado helpers color_field e color_field_tag.

*   Adicionadi opção include_hidden para selecionar tag. Com :include_hidden => false selecionado com atributos múltiplos não gera entrada hidden com valor em branco.

*   Removida a opção de tamanho padrão dos helpers text_field, search_field, telephone_field, url_field, email_field.

*   Removido opções padrões cols e rows do helper text_area.

*   Adicionado tag's helpers ativa image_url, javascript_url, stylesheet_url, audio_url, video_url, e font_url. Essas URL helpers irá retornar o caminho completo para o seu assets. Isto é útil quando você está precisando referenciar este host externo ativo.

*   Permitido argumentos value_method e text_method do collection_select e options_from_collection_for_select para receber um objeto que responde :call como um proc, para avaliar a opção no contexto atual do elemento. Isso funciona da mesma forma com collection_radio_buttons e collection_check_boxes.

*   Adicionado helpers date_field e date_field_tag que renderizam uma tag input[type="date"].

*   Adicionado form helpers collection_check_boxes, semelhante a collection_select:

    ``` ruby 
    collection_check_boxes :post, :author_ids, Author.all, :id, :name
    # Outputs something like:
    <input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="1" />
    <label for="post_author_ids_1">D. Heinemeier Hansson</label>
    <input id="post_author_ids_2" name="post[author_ids][]" type="checkbox" value="2" />
    <label for="post_author_ids_2">D. Thomas</label>
    <input name="post[author_ids][]" type="hidden" value="" />
    ```

    Os pares de label/check_box pode ser personalizado com um bloco.

*   Adicionado form helpers collection_radio_buttons, semelhante a collection_select:

    ``` ruby 
    collection_radio_buttons :post, :author_id, Author.all, :id, :name
    # Outputs something like:
    <input id="post_author_id_1" name="post[author_id]" type="radio" value="1" />
    <label for="post_author_id_1">D. Heinemeier Hansson</label>
    <input id="post_author_id_2" name="post[author_id]" type="radio" value="2" />
    <label for="post_author_id_2">D. Thomas</label>
    ```

    Os pares de label/radio_button pode ser personalizado com um bloco.

*   check_box com um atributo HTML5 :form agora replica o :form de atributo para o campo oculto também.

*   helper de label do formulário aceita :for => nil para não gerar o atributo.

*   Adicionado opção :format de number_to_percentage.

*   Adicionado config.action_view.logger para configurar logger na Action View.

*   helper check_box com :disabled => true irá gerar um campo disabled oculto para se conformar com a convenção de HTML onde os campos com deficiência não foram apresentados com o formulário. Esta é uma mudança de comportamento, anteriormente a tag oculta tinha um valor da caixa de seleção deficientes.

*   helper favicon_link_tag irá agora usar o favicon em app/assets por padrão.

*   ActionView::Helpers::TextHelper#highlight agora padrões para os elementos HTML5.

#### Deprecações

### Sprockets

Mudou-se para uma gem separada chamada sprockets-rails.

Active Record
----------------------

*   Adicionado declarações add_reference e remove_reference do schema. Alias, add_belongs_to e remove_belongs_to são aceitáveis. Referências são reversíveis.

    ``` ruby
    # Criar uma coluna user_id
    add_reference(:products, :user)
    
    # Criar um supplier_id, colunas supplier_type e índice apropriado<
    add_reference(:products, :supplier, polymorphic: true, index: true)
     
    # Remove referência polimórfica
    remove_reference(:products, :supplier, polymorphic: true)
    ```

*   Adicionado opções :default e :null para column_exists?.

    ``` ruby
    column_exists?(:testings, :taggable_id, :integer, null: false)
    column_exists?(:testings, :taggable_type, :string, default: 'Photo')
    ```

*   ActiveRecord::Relation#inspect agora deixa claro que você está lidando com um objeto de Relation, em vez de um array:

    ``` ruby
    User.where(:age => 30).inspect
    # => <ActiveRecord::Relation [#<User ...>, #<User ...>]>
    
    User.where(:age => 30).to_a.inspect
    # => [#<User ...>, #<User ...>]
    ```

    Se mais de 10 itens são devolvidos pela relação, `inspect` mostrará apenas os 10 primeiros, seguidos de reticências.

*   Adicionado suporte :collation e :ctype ao PostgreSQL. Estes estão disponíveis para PostgreSQL 8.4 ou posterior.

    ``` ruby
    development:
      adapter: postgresql
      host: localhost
      database: rails_development
      username: foo
      password: bar
      encoding: UTF8
      collation: ja_JP.UTF8
      ctype: ja_JP.UTF8
    ```

*   FinderMethods#exists? agora retorna false com o argumento false.

*   Adicionado suporte para a especificação a precisão de um timestamp, no adaptador postgresql. Assim, em vez de ter de especificar a precisão incorretamente usando a opção :limit, você pode usar :precision, como pretendido. Por exemplo, em uma migração:

    ``` ruby
    def change
      create_table :foobars do |t|
        t.timestamps :precision => 0
      end
    end
    ```

*   Permiti ActiveRecord::Relation#pluck a aceitação de várias colunas. Retorna uma array de arrays contendo os valores typecasted:

    ``` ruby
    Person.pluck(:id, :name)
    # SELECT people.id, people.name FROM people
    # => [[1, 'David'], [2, 'Jeremy'], [3, 'Jose']]
    ```

*   Melhorar a derivação do nome da tabela HABTM de junção de ter em conta o assentamento. Ele agora leva os nomes de tabela dos dois modelos, classifica-as lexicalmente e depois se junta a eles, tirando qualquer prefixo comum do nome segunda tabela. Alguns exemplos:

    ``` ruby
    Melhores níveis de modelos (Category <=> Product)
    Antigo: categories_products
    Novo:   categories_products
    
    Melhores modelos de nível com um table_name_prefix global (Category <=> Product)
    Antigo: site_categories_products
    Novo:   site_categories_products
     
    Modelos aninhados em um módulo sem um método table_name_prefix (Admin::Category <=> Admin::Product)
    Antigo: categories_products
    Novo:   categories_products
    
    Modelos aninhados em um módulo com um método table_name_prefix (Admin::Category <=> Admin::Product)
    Antigo: categories_products
    Novo:   admin_categories_products
     
    Modelos aninhados em um modelo pai (Catalog::Category <=> Catalog::Product)
    Antigo: categories_products
    Novo:   catalog_categories_products
     
    Modelos aninhados em modelos de ligações diferentes (Catalog::Category <=> Content::Page)
    Antigo: categories_pages
    Novo:   catalog_categories_content_pages
    ```

*   Movido as verificações de validade HABTM para ActiveRecord::Reflection. Um efeito colateral disso é se mover quando as exceções são levantadas a partir do ponto de declaração quando a associação é construída. Isso é consistente com outras verificações de validade de associação.

*    Adicionado hash stored_attributes que contém os atributos armazenados usando ActiveRecord::Store. Isso permite que você recupere a lista de atributos que você definiu.

    ``` ruby
    class User < ActiveRecord::Base
      store :settings, accessors: [:color, :homepage]
    end
     
    User.stored_attributes[:settings] # [:color, :homepage]
    ```

*   Nível de registro padrão do PostgreSQL é agora "aviso", para ignora as mensagens `Notice`. Você pode alterar o nível de log usando a opção disponível min_messages no seu config/database.yml.

*   Adicionado suporte datatype uuid ao adaptador PostgreSQL.

*   Adicionado ActiveRecord::Migration.check_pending! que gera um erro se as migrações estão pendentes.

*   Adicionado #destroy! que atua como #destroy, mas irá gerar uma exceção ActiveRecord::RecordNotDestroyed em vez de retornar false.

*   Permitir blocos para a contagem com ActiveRecord::Relation, que trabalham semelhante ao Array#count:Person.where("age > 26").count{ |person| person.gender == 'female' }

*   Adicionado suporte para CollectionAssociation#delete para passar valores Fixnum ou String como IDs de registro. Este encontra os registros que respondem aos ids e exclui-los.

    ``` ruby
    class Person < ActiveRecord::Base
      has_many :pets
    end
     
    person.pets.delete("1")  # => [#<Pet id: 1>]
    person.pets.delete(2, 3) # => [#<Pet id: 2>, #<Pet id: 3>]
    ```

*   Não é mais possível para destruir um modelo marcado como somente leitura.

*   Adicionado a capacidade de ActiveRecord::Relation#from aceitar outro objetos ActiveRecord::Relation.

*   Adicionado suporte à codificadores personalizado para ActiveRecord::Store. Agora você pode definir o codificador personalizado como este:

    ``` ruby
    store :settings, accessors: [ :color, :homepage ], coder: JSON
    ```

*   Conexões mysql e mysql2 irá definir SQL_MODE=STRICT_ALL_TABLES por padrão, para evitar perda de dados. Isto pode ser desabilitado, especificando strict: false em config/database.yml.

*   Adicionado ordem padrão de ActiveRecord::Base#first para assegurar resultados consistentes entre as engines diferentes de banco de dados. Introduzido ActiveRecord::Base#take como um substituto para o comportamento antigo.

*   Adicionado uma opção :index para criar automaticamente índices para references e declarações belongs_to em migrações. Este pode ser um booleano ou um hash que é idêntico a opções disponíveis para o método add_index:

    ``` ruby
    create_table :messages do |t|
      t.references :person, :index => true
    end
    ```
    
    É o mesmo que:
    ``` ruby
    create_table :messages do |t|
      t.references :person
    end
    add_index :messages, :person_id
    ```
    
    Geradores também foram atualizados para usar a nova sintaxe.

*   Adicionado métodos bang para mutação de objetos ActiveRecord::Relation. Por exemplo, enquanto foo.where(:bar) irá retornar um novo objeto deixando foo inalterado, foo.where!(:bar) vai transformar o objeto foo.

*   Adicionado #find_by e #find_by! para espelhar a funcionalidade fornecida por finders dinâmicos de uma forma que permite a entrada dinâmica mais facilmente:

    ``` ruby
    Post.find_by name: 'Spartacus', rating: 4
    Post.find_by "published_at < ?", 2.weeks.ago
    Post.find_by! name: 'Spartacus'
    ```

*   Adicionado ActiveRecord::Base#slice para retornar um hash dos métodos indicados com seus nomes como chaves e valores retornados como valores.

*   Removido IdentityMap - IdentityMap nunca se formou para ser uma caracterísca "ativada-por-padrão", devido a algumas inconsistências com associações, conforme descrito neste [commit](https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6). Daí a retirada da base de código, até que tais questões são fixas.

*   Adicionou um recurso para o estado interno dump/load de exemplo de SchemaCache, porque queremos iniciar mais rapidamente quando temos muitos modelos.

    ``` ruby
    # executa rake task.
    RAILS_ENV=production bundle exec rake db:schema:cache:dump
    => generate db/schema_cache.dump
     
    # Adiciona config.use_schema_cache_dump = true em config / production.rb. BTW, true é default.
    
    # boot rails.
    RAILS_ENV=production bundle exec rails server
    => use db/schema_cache.dump
     
    # Se você remover o cache despejado claro, executar a tarefa rake.
    RAILS_ENV=production bundle exec rake db:schema:cache:clear
    => remove db/schema_cache.dump
    ```

*   Adicionado suporte para índices parciais para adaptador PostgreSQL.

*   O método add_index agora suporta uma opção where que recebe uma string com os critérios dos índices parciais.

*   Adicionado a classe implementar, o ActiveRecord::NullRelation, o padrão de objeto nulo para a classe Relation.

*   Implementado método ActiveRecord::Relation#none que retorna uma relação em cadeia com zero registros (uma instância da classe NullRelation). Qualquer condição subseqüente acorrentado a retorno de Relation continuará gerando uma relação vazia e não dispara qualquer consulta ao banco de dados.

*   Adicionado helper create_join_table de migração para criar tabelas juntadas HABTM.

    ``` ruby
    create_join_table :products, :categories
    # =>
    # create_table :categories_products, :id => false do |td|
    #   td.integer :product_id, :null => false
    #   td.integer :category_id, :null => false
    # end
    ```

*   A primary key sempre é inicializada no hash @attributes para zero (a menos que outro valor tenha sido especificado).

*   Em versões anteriores, o seguinte seria gerado uma única consulta com um OUTER JOIN comments, em vez de duas consultas distintas:

    ``` ruby
    Post.includes(:comments).where("comments.name = 'foo'")
    ```

    Este comportamento se baseia na correspondência de string de SQL, que é uma idéia intrinsecamente errada, a menos que escreva um parser de SQL, que não queremos fazer. Portanto, agora foi substituído.

    Para evitar avisos de remoção e para compatibilidade futura, você deve declarar explicitamente quais tabelas de referência, ao usar o trechos SQL:

    ``` ruby
    Post.includes(:comments).where("comments.name = 'foo'").references(:comments)
    ```

    Note que você não precisa especificar explicitamente as referências nos seguintes casos, como eles podem ser automaticamente inferidos:
    
    ``` ruby
    Post.where(comments: { name: 'foo' })
    Post.where('comments.name' => 'foo')
    Post.order('comments.name')
    ```
    
    Você também não precisa se preocupar com isso, a menos que você está carregando. Basicamente, não se preocupe se você ver um aviso de reprovação ou (em versões futuras) um erro de SQL devido a uma falta JOIN.

*   Apoio à tabela schema_info foi descartada. Por favor, mude para schema_migrations.

*   Conexões devem ser encerradas no final de um segmento. Se não, seu pool de conexão pode preencher e uma exceção será levantada.

*   Adicionado o módulo ActiveRecord::Model que pode ser incluído em uma classe como uma alternativa a herança de ActiveRecord::Base:

    ``` ruby
    class Post
      include ActiveRecord::Model
    end
    ```

*   Registros hstore PostgreSQL pode ser criado.

*   Tipos hstore PostgreSQL são automaticamente desserializado do banco de dados.

*   Adicionado método #update_columns que atualiza os atributos do hash passado sem salvar a chamada, portanto, ignorando validações e callbacks. ActiveRecordError será levantado quando chamado em objetos novos ou quando pelo menos um dos atributos for marcado como somente leitura.

    ``` ruby
    post.attributes # => {"id"=>2, "title"=>"My title", "body"=>"My content", "author"=>"Peter"}
    post.update_columns({title: 'New title', author: 'Sebastian'}) # => true
    post.attributes # => {"id"=>2, "title"=>"New title", "body"=>"My content", "author"=>"Sebastian"}
    ```

### Deprecações

*   Obsoleto a maioria dos métodos do "localizador dinâmico". Todos os métodos dinâmicos, exceto para find_by_... e find_by_...! estão obsoletos. Veja como você pode reescrever o código:

    ``` ruby
    find_all_by_... 					pode ser reescrito usando where(...)
    find_last_by_... 					pode ser reescrito usando where(...).last
    scoped_by_... 						pode ser reescrito usando where(...)
    find_or_initialize_by_... pode ser reescrito usando where(...).first_or_initialize
    find_or_create_by_... 		pode ser reescrito usando where(...).first_or_create
    find_or_create_by_...! 		pode ser reescrito usando where(...).first_or_create!
    ```

    A implementação do obsoleto finders dinâmicos foi movido para a gem active_record_deprecated_finders.

*   Deprecado o velho estilo hash com base localizador API. Isto significa que os métodos que previamente aceita "opções Finder" não fazem. Por exemplo este:

    ``` ruby
    Post.find(:all, :conditions => { :comments_count => 10 }, :limit => 5)
    ```
    
    Deve ser reescrito no novo estilo que existe desde o Rails 3:
    
    ``` ruby
    Post.where(comments_count: 10).limit(5)
    ```
    
    Note que como um passo intermediário, é possivel reescrever o código acima como:
    
    ``` ruby
    Post.scoped(:where => { :comments_count => 10 }, :limit => 5)
    ```
    
    Isso poderia poupar-lhe um monte de trabalho, se há um monte de estilo antigo usando #finder em sua aplicação.
    
    Chamando Post.scoped(options) é um atalho para Post.scoped.merge(options). Relation#merge agora aceita um hash de opções, mas eles devem ser idênticos aos nomes do método #finder equivalente. Estes são praticamente idênticos aos de estilo antigo de opções de nomes do #finder, exceto nos seguintes casos:

    ``` ruby
    :conditions torna-se :where
    :include torna-se :includes
    :extend torna-se :extending
    ```
    
    O código para implementar as funcionalidades depreciadas foi movido para a gem active_record_deprecated_finders. Esta gem é uma dependência de Active Record no Rails 4.0. Ela deixará de ser uma dependência do Rails 4.1, mas se seu aplicativo depende dos recursos preteridos, então você pode adicioná-lo ao seu próprio Gemfile. Ela será mantida pela equipe principal do Rails até o Rails 5.0 for lançado.

*   Depreciado scopes avaliados.

    Não use este:
    
    ``` ruby
    scope :red, where(color: 'red')
    default_scope where(color: 'red')
    ```
    
    Use este:
    
    ``` ruby
    scope :red, -> { where(color: 'red') }
    default_scope { where(color: 'red') }
    ```
    
    O primeiro tem inúmeras questões. É uma pegadinha comum de fazer o seguinte:
    
    ``` ruby
    scope :recent, where(published_at: Time.now - 2.weeks)
    ```
    
    Ou uma variante mais sutil:
    
    ``` ruby
    scope :recent, -> { where(published_at: Time.now - 2.weeks) }
    scope :recent_red, recent.where(color: 'red')
    ```
    
    Scopes também são muito complexo de implementar dentro do Active Record, e ainda existem bugs. Por exemplo, o seguinte não faz o que você espera:
    
    ``` ruby
    scope :remove_conditions, except(:where)
    where(...).remove_conditions # => ainda tem conditions
    ```

*   Depreciação adicional para a opção de associação :dependent => :restrict.

*   Até agora has_many e has_one, opção :dependent => :restrict levanta uma DeleteRestrictionError no momento de destruir o objeto. Em vez disso, ele irá adicionar um erro no modelo.

*   Para corrigir esse aviso, verifique se seu código não está contando com uma DeleteRestrictionError e adicione config.active_record.dependent_restrict_raises = false no seu config/application.rb.

*   Nova aplicação rails seria gerada com o config.active_record.dependent_restrict_raises = false no config/application.rb.

*   O gerador de migração agora cria uma tabela de junção com (comentado) índices cada vez que o nome de migração contém a palavra "join_table".

*   ActiveRecord::SessionStore foi removido do Rails 4.0 e é agora uma [gem](https://github.com/rails/activerecord-session_store) separada.

Active Model
----------------------

*   Mudou valor padrão AM::Serializers::JSON.include_root_in_json para false. Agora, serializadores AM e objetos AR têm o mesmo comportamento padrão.

    ``` ruby
    class User < ActiveRecord::Base; end
     
    class Person
      include ActiveModel::Model
      include ActiveModel::AttributeMethods
      include ActiveModel::Serializers::JSON
     
      attr_accessor :name, :age
     
      def attributes
        instance_values
      end
    end
     
    user.as_json
    => {"id"=>1, "name"=>"Konata Izumi", "age"=>16, "awesome"=>true}
    # root não é incluido
     
    person.as_json
    => {"name"=>"Francesco", "age"=>22}
    # root não é incluido
    ```

*   Passando valores de hash falsos para validates não mais permitir que os validadores correspondentes.

*   Mensagens ConfirmationValidator de erro irá anexar :#{attribute}_confirmation em vez de attribute.

*   Adicionado ActiveModel::Model, um mixin para fazer objetos Ruby trabalhar com Action Pack fora da caixa.

*   ActiveModel::Errors#to_json suporta um novo parâmetro :full_messages.

*   Guarnições abaixo da API, removido valid? e errors.full_messages.

### Deprecações

Active Resource
----------------------

*    Active Resource é removido do Rails 4.0 e é agora é separado em uma [gem](https://github.com/rails/activeresource).

Active Support
----------------------
    
*   Adicionado valores padrões para todos os métodos ActiveSupport::NumberHelper, para evitar erros com locais vazios ou falta de valores.

*   Time#change agora trabalha com valores de tempo com outros deslocamentos de UTC ou o fuso horário local.

*   Adicionado Time#prev_quarter e Time#next_quarter curto para months_ago(3) e months_since(3) .

*   Removido método require_association obsoleta e não de dependências.

*   Adicionado opção :instance_accessor para config_accessor.

    ``` ruby
    class User
      include ActiveSupport::Configurable
      config_accessor :allowed_access, instance_accessor: false
    end
     
    User.new.allowed_access = true # => NoMethodError
    User.new.allowed_access        # => NoMethodError
    ```

*   Métodos ActionView::Helpers::NumberHelper foram movidos para ActiveSupport::NumberHelper e agora estão disponíveis através Numeric#to_s.

*   Numeric#to_s agora aceita as opções de formatação  :phone, :currency, :percentage, :delimited, :rounded, :human, e :human_size.

*   Adicionado Hash#transform_keys, Hash#transform_keys!, Hash#deep_transform_keys e Hash#deep_transform_keys!.

*   Alterado xml tipo Datetime para dateTime (com letra T maiúscula).

*   Adicionado opção :instance_accessor para class_attribute.

*   Agora constantize olha na cadeia ancestral.

*   Adicionado Hash#deep_stringify_keys e Hash#deep_stringify_keys! para converter todas as chaves de uma instância Hash em strings.

*   Adicionado Hash#deep_symbolize_keys e Hash#deep_symbolize_keys! para converter todas as chaves de uma instância Hash em symbols.

*   Object#try não pode chamar métodos privados.

*   AS::Callbacks#run_callbacks removido argumento chave.

*   deep_dup trabalha mais agora expectavelmente e duplica também valores em instancias de Hash e elementos em ocorrências de Array.

*   Inflector não mais se aplica ice -> ouse a palavras como polícia, fatia.

*   Adicionado ActiveSupport::Deprecations.behavior = :silence para ignorar completamente depreciações Rails tempo de execução.

*   Torna Module#delegate parar de usar envio - já não pode delegar métodos privados.

*   AS::Callbacks depreciado opção :rescuable.

*   Adicionado Integer#ordinal para obter o sufixo ordinal de string de um inteiro.

*   Opção AS::Callbacks :per_key não é mais suportado.

*   AS::Callbacks#define_callbacks acrescentado opção :skip_after_callbacks_if_terminated.

*   Adicionado html_escape_once a ERB::Util, e a tag helper delega escape_once a ele.

*   Removido método ActiveSupport::TestCase#pending, utilize instancia de skip.

*   Excluído a compatibilidade método Module#method_names, utilize o Module#methods a partir de agora (que retorna símbolos).

*   Excluído a compatibilidade método Module#instance_method_names, utilize o Module#instance_methods a partir de agora (que retorna símbolos).

*   Banco de dados Unicode atualizado para 6.1.0.

*   Adiciona opção encode_big_decimal_as_string para forçar serialização JSON de BigDecimals como numérico em vez de envolvê-los em strings de segurança.

### Deprecações

*   ActiveSupport::Callbacks: uso deprecado de objeto de filtro com métodos #before e #after como callback around.

*   BufferedLogger está obsoleto. Use ActiveSupport::Logger ou o logger de Ruby stdlib.

*   Despreza a compatibilidade Module#local_constant_names e use Module#local_constants instancia (que retorna símbolos).

Créditos
----------------------

Veja a [lista completa de contribuidores do Rails](http://contributors.rubyonrails.org/) para as muitas pessoas que passam muitas horas contribuindo com o Rails, o quadro estável e robusto que é. Parabéns a todos eles.

Créditos da tradução para [Rodrigo Martins](http://github.com/rrmartins)