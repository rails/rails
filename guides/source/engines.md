**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Rails Engines Overview
======================

In this guide you will learn about engines and how they can be used to provide
additional functionality to their host applications through a clean and very
easy-to-use interface.

After reading this guide, you will know:

* What makes an engine.
* How to generate an engine.
* How to build features for the engine.
* How to hook the engine into an application.
* How to override engine functionality in the application.
* How to avoid loading Rails frameworks with Load and Configuration Hooks.

--------------------------------------------------------------------------------

What are Engines?
-----------------

Engines can be thought of as miniature applications that encapsulate specific
functionality and integrate with a larger Rails application. A Rails application
is essentially a "supercharged" engine, with the `Rails::Application` class
inheriting a lot of its behavior from `Rails::Engine`, which in turn [inherits
from `Rails::Railtie`](engines.html#the-inheritance-hierarchy).


The main application is always the final authority in a Rails environment. While
engines can extend or enhance the application's functionality, they are meant to
support the app — not override or redefine its behavior. Engines exist to serve
the application, not the other way around.

Some examples of engines in action:

* [Devise](https://github.com/plataformatec/devise) which provides authentication for its parent applications
* [Thredded](https://github.com/thredded/thredded) which provides forum functionality
* [Spree](https://github.com/spree/spree) which provides an e-commerce platform
* [Refinery CMS](https://github.com/refinery/refinerycms) which provides a CMS engine

### The Inheritance Hierarchy

At the base of this hierarchy,
[`Railtie`](https://api.rubyonrails.org/classes/Rails/Railtie.html) is the core
building block of the Rails framework. It provides hooks into the Rails
initialization process and allows extensions, such as frameworks (e.g., Active
Record, Action Mailer) or third-party libraries, to tie into the Rails boot
sequence.

The [`Rails Engine`](https://api.rubyonrails.org/classes/Rails/Engine.html) builds on
`Railtie` by adding support for things like routes, isolated namespaces, and
load paths, making it possible to package complete Rails components. Engines and
applications also share a common structure.

Finally,
[`Application`](https://api.rubyonrails.org/classes/Rails/Application.html)
extends `Engine` with additional responsibilities like middleware setup,
configuration loading, and application initialization. Engines and
applications also share a common structure.

### Engines and Plugins

Engines are also closely related to plugins - all engines are plugins, but not
all plugins are engines. The two share a common `lib` directory structure, and
are both generated using the `rails plugin new` generator.

While a plugin is generated using `rails plugin new <plugin_name>`, an engine is
generated using `rails plugin new <engine_name> --full` or `rails plugin new
<engine_name> --mountable`. The `--full` option tells the generator that you
want to create an engine that needs its own models/controllers but shares the
host app's namespace, while the `--mountable` option tells the generator that
you want to create a fully isolated, mountable engine with its own namespace.
You can read more about the different generator options in the [Rails Plugins
Generator Options](plugins.html#generator-options) section.

### How do you use an Engine in a host app?

You add it to your host app’s `Gemfile`, and then mount it in the main app's routes:

Once mounted, any routes, controllers, views, or assets defined in the engine become available at that mount point in the host application.

Since the engine has an isolated namespace, this means that an
application is able to have a path provided by a routing helper such as
`articles_path` and the engine can have a path also called
`articles_path` without clashing. Along with this, controllers, models
and table names are also namespaced. You'll see how to do this later in this
guide.

Generating an Engine
--------------------

In the following example, we'll be building an engine, called "blorgh" that
provides blogging functionality to its host applications, allowing for new
articles and comments to be created. We'll be using the [`--mountable`
option](plugins.html#generator-options) to generate the engine.

To generate an engine, you will need to run the plugin generator and pass it
options as appropriate to the need. For the "blorgh" example, you will need to
create a "mountable" engine, running this command in a terminal:

```bash
$ rails plugin new blorgh --mountable
```

The `--mountable` option will allow our engine to behave like a self-contained mini-application that can be easily integrated into a host Rails application without polluting its global namespace. It will:

- namespace all controllers, routes, views, helpers, and assets under the `Blorgh` module, preventing conflicts with similarly named components in the host app.
- isolate routing to the engine, allowing you to mount it at a specific path in the host app (e.g., `/blorgh`), while keeping its internal route structure independent.
- make the engine more modular and reusable, so it can be plugged into different applications with minimal configuration.

### The Structure

The structure of the `--mountable` engine will be as follows:

```
blorgh/
├── app/
│   ├── assets/
│   │   ├── javascripts/
│   │   │   ├── blorgh/
│   │   │   │   └── application.js
│   │   │   └── blorgh_manifest.js
│   │   └── stylesheets/
│   │       ├── blorgh/
│   │       │   └── application.css
│   │       └── application.css
│   ├── controllers/
│   │   └── blorgh/
│   │       └── application_controller.rb
│   ├── helpers/
│   │   └── blorgh/
│   │       └── application_helper.rb
│   ├── mailers/
│   ├── models/
│   └── views/
│       └── layouts/
│           └── blorgh/
│               └── application.html.erb
├── bin/
├── blorgh.gemspec
├── config/
│   ├── initializers/
│   └── routes.rb
├── lib/
│   ├── blorgh/
│   │   └── engine.rb
│   ├── blorgh.rb
│   └── tasks/
│       └── blorgh_tasks.rake
├── MIT-LICENSE
├── Rakefile
├── README.md
├── test/
│   ├── dummy/
│   │   ├── app/
│   │   ├── bin/
│   │   ├── config/
│   │   ├── db/
│   │   ├── public/
│   │   └── ... (full Rails app)
│   ├── integration/
│   └── test_helper.rb
└── tmp/
```

It provides the following:

  * An `app` directory tree
  * A `config/routes.rb` file:

    ```ruby
    Rails.application.routes.draw do
    end
    ```

  * A file at `lib/blorgh/engine.rb`, which is identical in function to a
    standard Rails application's `config/application.rb` file:

    ```ruby
    module Blorgh
      class Engine < ::Rails::Engine
      end
    end
    ```

`-- mountable` engines, like above, contain some files that are not present in
the `--full` option, these are:

  * Asset manifest files (`blorgh_manifest.js` and `application.css`)
  * A namespaced `ApplicationController` stub
  * A namespaced `ApplicationHelper` stub
  * A layout view template for the engine
  * Namespace isolation to `config/routes.rb`:

    ```ruby
    Blorgh::Engine.routes.draw do
    end
    ```

  * Namespace isolation to `lib/blorgh/engine.rb`:

    ```ruby
    module Blorgh
      class Engine < ::Rails::Engine
        isolate_namespace Blorgh
      end
    end
    ```

Additionally, the `--mountable` option tells the generator to mount the engine
inside the dummy testing application located at `test/dummy` by adding the
following to the dummy application's routes file at
`test/dummy/config/routes.rb`:

```ruby
mount Blorgh::Engine => "/blorgh"
```

A full list of options for the plugin generator can be seen by running:

```bash
$ rails plugin --help
```

### The Core Setup

#### The `.gemspec` File

At the root of your engine, you’ll find a file named `blorgh.gemspec`. This file defines your engine as a gem. It includes metadata like the gem name, version, authors, dependencies, and which files to include when it's packaged.

To use this engine in a host Rails application, you reference it in the app’s `Gemfile` like so:

```ruby
gem "blorgh", path: "engines/blorgh"
```

Then run:

```bash
bundle install
```

This tells Bundler to treat the engine as a gem and load it accordingly.

#### The Engine Entry Point: `lib/blorgh.rb`:

Bundler looks for a file matching the gem name, `lib/blorgh.rb`. This file is the main entry point of the engine. It typically requires the engine definition and sets up a base module:

```ruby
require "blorgh/engine"

module Blorgh
end
```

TIP: Some engines choose to use this file to put global configuration options
for their engine. It's a relatively good idea, so if you want to offer
configuration options, the file where your engine's `module` is defined is
perfect for that. Place the methods inside the module and you'll be good to go.

#### The Engine Class Definition: `lib/blorgh/engine.rb`

This file defines the engine class and tells Rails how to load and isolate it:

```ruby
module Blorgh
  class Engine < ::Rails::Engine
    isolate_namespace Blorgh
  end
end
```

By inheriting from the `Rails::Engine` class, this gem notifies Rails that
there's an engine at the specified path. Rails will automatically:

* Add the engine’s `app/` folder to the load path.
* Load the engine’s models, mailers, controllers, and views.
* Mount the engine at the specified path when used in a host app.

The `isolate_namespace Blorgh` from the Engine class is crucial. It prevents your engine’s components — like models, routes, helpers, and controllers, from clashing with those in the host application or other engines.

For example:

* A generated model becomes `Blorgh::Article` rather than `Article`.
* The table name is `blorgh_articles`, not `articles`.
* A controller becomes `Blorgh::ArticlesController`, with views in `app/views/blorgh/articles`.
* A helper becomes `Blorgh::ArticlesHelper`, with views in `app/helpers/blorgh/articles_helper.rb`.
* Mailers and Jobs are namespaced as well.
* Engine routes are kept isolated and don’t mix with the main app’s routes. This is discussed later in the [Routes](#routes) section of this guide.

Without this isolation, files from the engine might "leak" into the host app’s namespace or identically named classes might override each other.

NOTE: It is **highly** recommended that the `isolate_namespace` line be left
within the `Engine` class definition. Without it, classes generated in an engine
**may** conflict with an application.

### Understanding the `app` Directory

The `app` directory in a mountable engine mirrors the familiar structure of a standard Rails application. It includes subdirectories like `assets`, `controllers`, `helpers`, `jobs`, `mailers`, `models`, and `views`.

Here’s what you should know about each of these, especially in the context of a namespaced engine like `blorgh`:

#### `app/assets`

Inside `app/assets`, you’ll find directories for `images`, `javascripts`, and `stylesheets`. Each of these contains a subdirectory named after your engine—`blorgh` in this case.

This namespacing is important: it ensures that your engine’s assets don’t conflict with those from other engines or the host application. For example:

```
app/assets/stylesheets/blorgh/application.css
app/assets/javascripts/blorgh/application.js
```

#### `app/controllers`

The `controllers` folder contains a `blorgh/` subdirectory where all engine controllers live. It starts with an `application_controller.rb`:

```ruby
module Blorgh
  class ApplicationController < ActionController::Base
  end
end
```

This controller acts as the base for all controllers in the engine, much like `ApplicationController` does in a full app. Placing it (and all other controllers) in the `blorgh/` namespace ensures they won’t clash with similarly named controllers in the host app or other engines.

#### Other Namespaced Directories

Similar to `app/controllers`, you’ll find a `blorgh/` subdirectory under these other top-level folders:

* `app/helpers/blorgh/`
* `app/jobs/blorgh/`
* `app/mailers/blorgh/`
* `app/models/blorgh/`

Each of these may include a corresponding `application_*.rb` file (e.g., `application_helper.rb`) for defining shared behavior.

This consistent namespacing helps prevent naming collisions and keeps your engine modular and encapsulated.

#### `app/views`

Inside `app/views/layouts`, you’ll find a layout file for the engine:

```
app/views/layouts/blorgh/application.html.erb
```

This is the default layout used by views inside the engine. It’s useful if your engine is meant to be used as a self-contained application (e.g., admin dashboards, wikis, etc.). If this engine is to be used as a stand-alone engine, then you would add any customization to its layout in this file, rather than the application's `app/views/layouts/application.html.erb` file.

If you don't want to force a layout on to users of the engine, then you can delete this file and reference a different layout in the controllers of your engine.

#### `/bin`

This directory contains one file, `bin/rails`, which enables you to use the
`rails` sub-commands and generators just like you would within an application.
This means that you will be able to generate new controllers and models for this
engine very easily by running commands like this:

```bash
$ bin/rails generate model
```

Keep in mind, of course, that anything generated with these commands inside of
an engine that has `isolate_namespace` in the `Engine` class will be namespaced.

#### `/test`

The `test` directory is where tests for the engine will go. To test the engine,
there is a cut-down version of a Rails application embedded within it at
`test/dummy`. This application will mount the engine in the
`test/dummy/config/routes.rb` file:

```ruby
Rails.application.routes.draw do
  mount Blorgh::Engine => "/blorgh"
end
```

This line mounts the engine at the path `/blorgh`, which will make it accessible
through the application only at that path.

Inside the test directory there is the `test/integration` directory, where
integration tests for the engine should be placed. Other directories can be
created in the `test` directory as well. For example, you may wish to create a
`test/models` directory for your model tests.

Providing Engine Functionality
------------------------------

The engine that we'll build, `blorgh`, will allow you to add article submissions and
comment functionality when added to any Rails application.

### Generating an Article Resource

The first thing to generate for a blog engine is the `Article` model and related
controller. To quickly generate this, you can use the Rails scaffold generator.

```bash
$ bin/rails generate scaffold article title:string text:text
```

This command will output this information:

```
invoke  active_record
create    db/migrate/[timestamp]_create_blorgh_articles.rb
create    app/models/blorgh/article.rb
invoke    test_unit
create      test/models/blorgh/article_test.rb
create      test/fixtures/blorgh/articles.yml
invoke  resource_route
 route    resources :articles
invoke  scaffold_controller
create    app/controllers/blorgh/articles_controller.rb
invoke    erb
create      app/views/blorgh/articles
create      app/views/blorgh/articles/index.html.erb
create      app/views/blorgh/articles/edit.html.erb
create      app/views/blorgh/articles/show.html.erb
create      app/views/blorgh/articles/new.html.erb
create      app/views/blorgh/articles/_form.html.erb
create      app/views/blorgh/articles/_article.html.erb
invoke    resource_route
invoke    test_unit
create      test/controllers/blorgh/articles_controller_test.rb
create      test/system/blorgh/articles_test.rb
invoke    helper
create      app/helpers/blorgh/articles_helper.rb
invoke      test_unit
```

#### The migration and model

The scaffold generator invokes the `active_record` generator, which generates a
_migration_ and a _model_ for the resource.

NOTE: The migration is named `create_blorgh_articles` instead of the usual
`create_articles`, and the model is located at `app/models/blorgh/article.rb`
rather than `app/models/article.rb`. </br></br> This is due to the use of the
`isolate_namespace` method in the `Blorgh::Engine` class, which ensures that
models, migrations, and other components are properly namespaced under `Blorgh`.

#### The test and fixture

Next, the `test_unit` generator is invoked for this model, generating a model
test at `test/models/blorgh/article_test.rb` (rather than
`test/models/article_test.rb`) and a fixture at `test/fixtures/blorgh/articles.yml`
(rather than `test/fixtures/articles.yml`).

#### The route

Thereafter, a line `resources :articles`, for the `article` resource, is
inserted into the `config/routes.rb` file for the engine.

```ruby
Blorgh::Engine.routes.draw do
  resources :articles
end
```

NOTE: The routes are created on the `Blorgh::Engine` object rather than the
`YourApp::Application` class. This ensures that the engine routes are confined
to the engine itself and can be mounted at a specific point, as shown in the
[test directory](#test-directory) section. It also allows the engine's routes to
be isolated from routes that are within the application. The
[Routes](#routes) section of this guide describes it in detail.

#### The controller and views

Next, the `scaffold_controller` generator is
invoked, generating a controller called `Blorgh::ArticlesController` (at
`app/controllers/blorgh/articles_controller.rb`) and its related views are
created at `app/views/blorgh/articles`.

This generator also generates tests for
the controller (`test/controllers/blorgh/articles_controller_test.rb` and
`test/system/blorgh/articles_test.rb`) and a helper
(`app/helpers/blorgh/articles_helper.rb`).

Once again, everything is namespaced. The controller's class is defined within
the `Blorgh` module:

```ruby
module Blorgh
  class ArticlesController < ApplicationController
    # ...
  end
end
```

NOTE: The `ArticlesController` class inherits from
`Blorgh::ApplicationController`, not the application's `ApplicationController`.

#### The helper

The helper inside `app/helpers/blorgh/articles_helper.rb` is also namespaced:

```ruby
module Blorgh
  module ArticlesHelper
    # ...
  end
end
```

This prevents conflicts with any other engine or application that may have
an article resource as well.

#### Exploring the engine in the browser

You can explore the engine by running `bin/rails db:migrate` at the root of the
engine, and then running `bin/rails server` in the engine's root directory.

When you open `http://localhost:3000/blorgh/articles` you will see the default scaffold that
has been generated.

![The landing page](images/engines/engine_article_page.png)

Congratulations, you've just generated your first engine!

#### Exploring the engine in the console

If you'd rather explore in the console, you can run `bin/rails console`.
Remember: the `Article` model is namespaced, so to reference it you must call it
as `Blorgh::Article`.

```ruby
irb> Blorgh::Article.create(title: "Hello, world!", text: "This is a test article.")
=>  #<Blorgh::Article id: 1, title: "Hello, world!", text: "This is a test article.", created_at: "2025-07-13 07:55:27.610591000 +0000", updated_at: "2025-07-13 07:55:27.610591000 +0000">

irb> Blorgh::Article.find(1)
=> #<Blorgh::Article id: 1, title: "Hello, world!" ...>
```

Whenever someone goes to the root path where the engine is
mounted, they should be shown a list of articles. To do this, add this line

```ruby
root to: "articles#index"
```

to the `config/routes.rb` file inside the engine.

Now you will only need to go to the root of the engine to see all the articles,
rather than visiting `/articles`. This means that instead of visiting
`http://localhost:3000/blorgh/articles`, you only need to go to
`http://localhost:3000/blorgh` now.

![The landing page](images/engines/engine_root_page.png)

### Generating a Comments Resource

Now that the engine can create new articles, let's add the ability to comment.
To do this, you'll need to generate a comment model, a comment controller, and
then modify the articles scaffold to display comments and allow people to create
new ones.

From the engine root, run the model generator to generate a `Comment` model,
with the related table having two columns: an `article` references column and a
`text` text column.

```bash
$ bin/rails generate model Comment article:references text:text
```

This will output the following:

```
invoke  active_record
create    db/migrate/[timestamp]_create_blorgh_comments.rb
create    app/models/blorgh/comment.rb
invoke    test_unit
create      test/models/blorgh/comment_test.rb
create      test/fixtures/blorgh/comments.yml
```

This will generate a `Blorgh::Comment` model and a migration to create the
`blorgh_comments` table.

The generated migration will look like this:

```ruby
class CreateBlorghComments < ActiveRecord::Migration[8.0]
  def change
    create_table :blorgh_comments do |t|
      t.references :article, null: false, foreign_key: true
      t.text :text

      t.timestamps
    end
  end
end
```

However, since you're building an isolated engine, the model `Blorgh::Comment`
references `Blorgh::Article`, so the `article_id` foreign key should point to
the `blorgh_articles` table, not an `articles` table.

To fix this, you can modify the migration to look like this:

```ruby
class CreateBlorghComments < ActiveRecord::Migration[8.0]
  def change
    create_table :blorgh_comments do |t|
      t.references :article, null: false, foreign_key: { to_table: :blorgh_articles }
      t.text :text

      t.timestamps
    end
  end
end
```

Now, you can run the migration to create the `blorgh_comments` table:

```bash
$ bin/rails db:migrate
```

#### Updating the view to show the comments

To show the comments on an article, edit `app/views/blorgh/articles/show.html.erb`
and add this line before the "Edit" link:

```html+erb
<h3>Comments</h3>
<%= render @article.comments %>
```

To get the comments to display on an article, you'll need to define a `has_many`
association for comments on the `Blorgh::Article` model. To do this, open
`app/models/blorgh/article.rb` and add the `has_many` association:

```ruby
module Blorgh
  class Article < ApplicationRecord
    has_many :comments
  end
end
```

NOTE: Because the `has_many` association is defined inside a class that is inside
the `Blorgh` module, Rails will know that you want to use the `Blorgh::Comment`
model for these objects, so there's no need to specify the `:class_name` option.

#### Adding a form and resource route to create comments

Next, create a form so that comments can be added to an article. Render the
`blorgh/comments/form` partial in `app/views/blorgh/articles/show.html.erb`
underneath the `render @article.comments` line.

```erb
...
  <%= render @article.comments %>

  <!-- Render the comments form -->
  <%= render "blorgh/comments/form" %>
...
```

Next, create the `blorgh/comments/form` partial that we just referenced.
To do this, create a new directory at `app/views/blorgh/comments` and in it a
new file called `_form.html.erb` with the following content:

```html+erb
<h3>New comment</h3>
<%= form_with model: [@article, @article.comments.build] do |form| %>
  <p>
    <%= form.label :text %><br>
    <%= form.textarea :text %>
  </p>
  <%= form.submit %>
<% end %>
```

When this form is submitted, it will attempt to perform a `POST` request to the
`/articles/:article_id/comments` route within the engine. You can read more
about the [`form_with` helper](form_helpers.html#working-with-basic-forms) in
the guides.

However, this route doesn't exist as yet. You can create it by nesting the
`comments` resource inside the `articles` resource in `config/routes.rb`:

```ruby
resources :articles do
  resources :comments
end
```

Now, create the controller that will handle the `POST` request to the
`/articles/:article_id/comments` route:

```bash
$ bin/rails generate controller comments
```

This will generate the following things:

```
create  app/controllers/blorgh/comments_controller.rb
invoke  erb
 exist    app/views/blorgh/comments
invoke  test_unit
create    test/controllers/blorgh/comments_controller_test.rb
invoke  helper
create    app/helpers/blorgh/comments_helper.rb
invoke    test_unit
```

As mentioned, the form will make a `POST` request to
`/articles/:article_id/comments`, so we'll need a `create` action in
`Blorgh::CommentsController`:

```ruby
# app/controllers/blorgh/comments_controller.rb

def create
  @article = Article.find(params[:article_id])
  @comment = @article.comments.create(comment_params)
  flash[:notice] = "Comment has been created!"
  redirect_to articles_path
end

private
  def comment_params
    params.expect(comment: [:text])
  end
```

However, if you were to create a comment, you would see an error where the engine
is unable to find the partial required for rendering the comments:

```
Missing partial blorgh/comments/_comment with {:locale=>[:en], :formats=>[:html], :variants=>[], :handlers=>[:raw, :erb, :html, :builder, :ruby]}.
```

NOTE: Rails will first look in the application's (`test/dummy`) `app/views`
directory and then in the engine's `app/views` directory. When it can't find the
file, it will throw this error. The engine looks for `blorgh/comments/_comment`
because the comment object it's rendering is an instance of the
`Blorgh::Comment` class.

Create a new file at `app/views/blorgh/comments/_comment.html.erb` and add the
following line to display the comment text:

```erb
<%= comment_counter + 1 %>. <%= comment.text %>
```

The `comment_counter` local variable is given to us by the `<%= render
@article.comments %>` call, which will define it automatically and increment the
counter as it iterates through each comment. It's used in this example to
display a small number next to each comment when it's created.

That completes the comment functionality of the blogging engine. Now it's time
to use it within an application.

![The article with comments](images/engines/engine_article_comment_page.png)

Hooking Into an Application
---------------------------

Using an engine within an application is very easy. This section covers how to
mount the engine into an application and the initial setup required, as well as
linking the engine to a `User` class provided by the application to provide
ownership for articles and comments within the engine.

### Mounting the Engine

First, the engine needs to be specified inside the application's `Gemfile`. If
there isn't an application handy to test this out in, generate one using the
`rails new` command outside of the engine directory like this:

```bash
$ rails new unicorn
```

Usually, specifying the engine inside the `Gemfile` would be done by specifying it
as a normal, everyday gem.

```ruby
gem "devise"
```

However, because you are developing the `blorgh` engine on your local machine,
you will need to specify the `:path` option in your `Gemfile`:

```ruby
gem "blorgh", path: "engines/blorgh"
```

Then run `bundle` to install the gem.

As described earlier, by placing the gem in the `Gemfile` it will be loaded when
Rails is loaded. It will first require `lib/blorgh.rb` from the engine, then
`lib/blorgh/engine.rb`, which is the file that defines the major pieces of
functionality for the engine.

To make the engine's functionality accessible from within an application, it
needs to be mounted in that application's `config/routes.rb` file:

```ruby
mount Blorgh::Engine, at: "/blog"
```

This line will mount the engine at `/blog` in the application. Making it
accessible at `http://localhost:3000/blog` when the application runs with `bin/rails
server`.

NOTE: Other engines, such as Devise, handle this a little differently by making
you specify custom helpers (such as `devise_for`) in the routes. These helpers
do exactly the same thing, mounting pieces of the engines's functionality at a
pre-defined path which may be customizable.

### Engine Setup

The engine contains migrations for the `blorgh_articles` and `blorgh_comments`
table which need to be created in the application's database so that the
engine's models can query them correctly. To copy these migrations into the
application run the following command from the application's root:

```bash
$ bin/rails blorgh:install:migrations
```

If you have multiple engines that need migrations copied over, use
`railties:install:migrations` instead:

```bash
$ bin/rails railties:install:migrations
```

You can specify a custom path in the source engine for the migrations by specifying MIGRATIONS_PATH.

```bash
$ bin/rails railties:install:migrations MIGRATIONS_PATH=db_blourgh
```

If you have multiple databases you can also specify the target database by specifying DATABASE.

```bash
$ bin/rails railties:install:migrations DATABASE=animals
```

This command, when run for the first time, will copy over all the migrations
from the engine. When run the next time, it will only copy over migrations that
haven't been copied over already. The first run for this command will output
something such as this:

```
Copied migration [timestamp_1]_create_blorgh_articles.blorgh.rb from blorgh
Copied migration [timestamp_2]_create_blorgh_comments.blorgh.rb from blorgh
```

The first timestamp (`[timestamp_1]`) will be the current time, and the second
timestamp (`[timestamp_2]`) will be the current time plus a second. The reason
for this is so that the migrations for the engine are run after any existing
migrations in the application.

To run these migrations within the context of the application, simply run `bin/rails
db:migrate`. When accessing the engine through `http://localhost:3000/blog`, the
articles will be empty. This is because the table created inside the application is
different from the one created within the engine. Go ahead, play around with the
newly mounted engine. You'll find that it's the same as when it was only an
engine.

If you would like to run migrations only from one engine, you can do it by
specifying `SCOPE`:

```bash
$ bin/rails db:migrate SCOPE=blorgh
```

This may be useful if you want to revert engine's migrations before removing it.
To revert all migrations from blorgh engine you can run code such as:

```bash
$ bin/rails db:migrate SCOPE=blorgh VERSION=0
```

### Using a Class Provided by the Application

#### Using a Model Provided by the Application

When an engine is created, it may want to use specific classes from an
application to provide links between the pieces of the engine and the pieces of
the application. In the case of the `blorgh` engine, making articles and comments
have authors would make a lot of sense.

A typical application might have a `User` class that would be used to represent
authors for an article or a comment. But there could be a case where the
application calls this class something different, such as `Person`. For this
reason, the engine should not hardcode associations specifically for a `User`
class.

To keep it simple in this case, the application will have a class called `User`
that represents the users of the application (we'll get into making this
configurable further on). It can be generated using this command inside the
application:

```bash
$ bin/rails generate model user name:string
```

The `bin/rails db:migrate` command needs to be run here to ensure that our
application has the `users` table for future use.

Also, to keep it simple, the articles form will have a new text field called
`author_name`, where users can elect to put their name. The engine will then
take this name and either create a new `User` object from it, or find one that
already has that name. The engine will then associate the article with the found or
created `User` object.

First, the `author_name` text field needs to be added to the
`app/views/blorgh/articles/_form.html.erb` partial inside the engine. This can be
added above the `title` field with this code:

```html+erb
<div class="field">
  <%= form.label :author_name %><br>
  <%= form.text_field :author_name %>
</div>
```

Next, we need to update our `Blorgh::ArticlesController#article_params` method to
permit the new form parameter:

```ruby
def article_params
  params.expect(article: [:title, :text, :author_name])
end
```

The `Blorgh::Article` model should then have some code to convert the `author_name`
field into an actual `User` object and associate it as that article's `author`
before the article is saved. It will also need to have an `attr_accessor` set up
for this field, so that the setter and getter methods are defined for it.

To do all this, you'll need to add the `attr_accessor` for `author_name`, the
association for the author and the `before_validation` call into
`app/models/blorgh/article.rb`. The `author` association will be hard-coded to the
`User` class for the time being.

```ruby
attr_accessor :author_name
belongs_to :author, class_name: "User"

before_validation :set_author

private
  def set_author
    self.author = User.find_or_create_by(name: author_name)
  end
```

By representing the `author` association's object with the `User` class, a link
is established between the engine and the application. There needs to be a way
of associating the records in the `blorgh_articles` table with the records in the
`users` table. Because the association is called `author`, there should be an
`author_id` column added to the `blorgh_articles` table.

To generate this new column, run this command within the engine:

```bash
$ bin/rails generate migration add_author_id_to_blorgh_articles author_id:integer
```

NOTE: Due to the migration's name and the column specification after it, Rails
will automatically know that you want to add a column to a specific table and
write that into the migration for you. You don't need to tell it any more than
this.

This migration will need to be run on the application. To do that, it must first
be copied using this command:

```bash
$ bin/rails blorgh:install:migrations
```

Notice that only _one_ migration was copied over here. This is because the first
two migrations were copied over the first time this command was run.

```
NOTE Migration [timestamp]_create_blorgh_articles.blorgh.rb from blorgh has been skipped. Migration with the same name already exists.
NOTE Migration [timestamp]_create_blorgh_comments.blorgh.rb from blorgh has been skipped. Migration with the same name already exists.
Copied migration [timestamp]_add_author_id_to_blorgh_articles.blorgh.rb from blorgh
```

Run the migration using:

```bash
$ bin/rails db:migrate
```

Now with all the pieces in place, an action will take place that will associate
an author - represented by a record in the `users` table - with an article,
represented by the `blorgh_articles` table from the engine.

Finally, the author's name should be displayed on the article's page. Add this code
above the "Title" output inside `app/views/blorgh/articles/_article.html.erb`:

```html+erb
<p>
  <strong>Author:</strong>
  <%= article.author.name %>
</p>
```

#### Using a Controller Provided by the Application

Because Rails controllers generally share code for things like authentication
and accessing session variables, they inherit from `ApplicationController` by
default. Rails engines, however are scoped to run independently from the main
application, so each engine gets a scoped `ApplicationController`. This
namespace prevents code collisions, but often engine controllers need to access
methods in the main application's `ApplicationController`. An easy way to
provide this access is to change the engine's scoped `ApplicationController` to
inherit from the main application's `ApplicationController`. For our Blorgh
engine this would be done by changing
`app/controllers/blorgh/application_controller.rb` to look like:

```ruby
module Blorgh
  class ApplicationController < ::ApplicationController
  end
end
```

By default, the engine's controllers inherit from
`Blorgh::ApplicationController`. So, after making this change they will have
access to the main application's `ApplicationController`, as though they were
part of the main application.

This change does require that the engine is run from a Rails application that
has an `ApplicationController`.

### Configuring an Engine

This section covers how to make the `User` class configurable, followed by
general configuration tips for the engine.

#### Setting Configuration Settings in the Application

The next step is to make the class that represents a `User` in the application
customizable for the engine. This is because that class may not always be
`User`, as previously explained. To make this setting customizable, the engine
will have a configuration setting called `author_class` that will be used to
specify which class represents users inside the application.

To define this configuration setting, you should use a `mattr_accessor` inside
the `Blorgh` module for the engine. Add this line to `lib/blorgh.rb` inside the
engine:

```ruby
mattr_accessor :author_class
```

This method works like its siblings, `attr_accessor` and `cattr_accessor`, but
provides a setter and getter method on the module with the specified name. To
use it, it must be referenced using `Blorgh.author_class`.

The next step is to switch the `Blorgh::Article` model over to this new setting.
Change the `belongs_to` association inside this model
(`app/models/blorgh/article.rb`) to this:

```ruby
belongs_to :author, class_name: Blorgh.author_class
```

The `set_author` method in the `Blorgh::Article` model should also use this class:

```ruby
self.author = Blorgh.author_class.constantize.find_or_create_by(name: author_name)
```

To save having to call `constantize` on the `author_class` result all the time,
you could instead just override the `author_class` getter method inside the
`Blorgh` module in the `lib/blorgh.rb` file to always call `constantize` on the
saved value before returning the result:

```ruby
def self.author_class
  @@author_class.constantize
end
```

This would then turn the above code for `set_author` into this:

```ruby
self.author = Blorgh.author_class.find_or_create_by(name: author_name)
```

Resulting in something a little shorter, and more implicit in its behavior. The
`author_class` method should always return a `Class` object.

Since we changed the `author_class` method to return a `Class` instead of a
`String`, we must also modify our `belongs_to` definition in the `Blorgh::Article`
model:

```ruby
belongs_to :author, class_name: Blorgh.author_class.to_s
```

To set this configuration setting within the application, an initializer should
be used. By using an initializer, the configuration will be set up before the
application starts and calls the engine's models, which may depend on this
configuration setting existing.

Create a new initializer at `config/initializers/blorgh.rb` inside the
application where the `blorgh` engine is installed and put this content in it:

```ruby
Blorgh.author_class = "User"
```

WARNING: It's very important here to use the `String` version of the class,
rather than the class itself. If you were to use the class, Rails would attempt
to load that class and then reference the related table. This could lead to
problems if the table didn't already exist. Therefore, a `String` should be
used and then converted to a class using `constantize` in the engine later on.

Go ahead and try to create a new article. You will see that it works exactly in the
same way as before, except this time the engine is using the configuration
setting in `config/initializers/blorgh.rb` to learn what the class is.

There are now no strict dependencies on what the class is, only what the API for
the class must be. The engine simply requires this class to define a
`find_or_create_by` method which returns an object of that class, to be
associated with an article when it's created. This object, of course, should have
some sort of identifier by which it can be referenced.

#### General Engine Configuration

Within an engine, there may come a time where you wish to use things such as
initializers, internationalization, or other configuration options. The great
news is that these things are entirely possible, because a Rails engine shares
much the same functionality as a Rails application. In fact, a Rails
application's functionality is actually a superset of what is provided by
engines!

If you wish to use an initializer - code that should run before the engine is
loaded - the place for it is the `config/initializers` folder. This directory's
functionality is explained in the [Initializers
section](configuring.html#initializers) of the Configuring guide, and works
precisely the same way as the `config/initializers` directory inside an
application. The same thing goes if you want to use a standard initializer.

For locales, simply place the locale files in the `config/locales` directory,
just like you would in an application.

Testing an Engine
-----------------

When an engine is generated, there is a smaller dummy application created inside
it at `test/dummy`. This application is used as a mounting point for the engine,
to make testing the engine extremely simple. You may extend this application by
generating controllers, models, or views from within the directory, and then use
those to test your engine.

The `test` directory should be treated like a typical Rails testing environment,
allowing for unit, functional, and integration tests.

### Functional Tests

A matter worth taking into consideration when writing functional tests is that
the tests are going to be running on an application - the `test/dummy`
application - rather than your engine. This is due to the setup of the testing
environment; an engine needs an application as a host for testing its main
functionality, especially controllers. This means that if you were to make a
typical `GET` to a controller in a controller's functional test like this:

```ruby
module Blorgh
  class FooControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    def test_index
      get foos_url
      # ...
    end
  end
end
```

It may not function correctly. This is because the application doesn't know how
to route these requests to the engine unless you explicitly tell it **how**. To
do this, you must set the `@routes` instance variable to the engine's route set
in your setup code:

```ruby
module Blorgh
  class FooControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    def test_index
      get foos_url
      # ...
    end
  end
end
```

This tells the application that you still want to perform a `GET` request to the
`index` action of this controller, but you want to use the engine's route to get
there, rather than the application's one.

This also ensures that the engine's URL helpers will work as expected in your
tests.

Improving Engine Functionality
------------------------------

This section explains how to add and/or override engine MVC functionality in the
main Rails application.

### Overriding Models and Controllers

Engine models and controllers can be reopened by the parent application to extend or decorate them.

Overrides may be organized in a dedicated directory `app/overrides`, ignored by the autoloader, and preloaded in a `to_prepare` callback:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    # ...

    overrides = "#{Rails.root}/app/overrides"
    Rails.autoloaders.main.ignore(overrides)

    config.to_prepare do
      Dir.glob("#{overrides}/**/*_override.rb").sort.each do |override|
        load override
      end
    end
  end
end
```

#### Reopening Existing Classes Using `class_eval`

For example, in order to override the engine model

```ruby
# Blorgh/app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    # ...
  end
end
```

you just create a file that _reopens_ that class:

```ruby
# MyApp/app/overrides/models/blorgh/article_override.rb
Blorgh::Article.class_eval do
  # ...
end
```

It is very important that the override _reopens_ the class or module. Using the `class` or `module` keywords would define them if they were not already in memory, which would be incorrect because the definition lives in the engine. Using `class_eval` as shown above ensures you are reopening.

#### Reopening Existing Classes Using ActiveSupport::Concern

Using `Class#class_eval` is great for simple adjustments, but for more complex
class modifications, you might want to consider using [`ActiveSupport::Concern`]
(https://api.rubyonrails.org/classes/ActiveSupport/Concern.html).
ActiveSupport::Concern manages load order of interlinked dependent modules and
classes at run time allowing you to significantly modularize your code.

**Adding** `Article#time_since_created` and **Overriding** `Article#summary`:

```ruby
# MyApp/app/models/blorgh/article.rb

class Blorgh::Article < ApplicationRecord
  include Blorgh::Concerns::Models::Article

  def time_since_created
    Time.current - created_at
  end

  def summary
    "#{title} - #{truncate(text)}"
  end
end
```

```ruby
# Blorgh/app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    include Blorgh::Concerns::Models::Article
  end
end
```

```ruby
# Blorgh/lib/concerns/models/article.rb

module Blorgh::Concerns::Models::Article
  extend ActiveSupport::Concern

  # `included do` causes the block to be evaluated in the context
  # in which the module is included (i.e. Blorgh::Article),
  # rather than in the module itself.
  included do
    attr_accessor :author_name
    belongs_to :author, class_name: "User"

    before_validation :set_author

    private
      def set_author
        self.author = User.find_or_create_by(name: author_name)
      end
  end

  def summary
    "#{title}"
  end

  module ClassMethods
    def some_class_method
      "some class method string"
    end
  end
end
```

### Autoloading and Engines

Please check the [Autoloading and Reloading Constants](autoloading_and_reloading_constants.html#autoloading-and-engines)
guide for more information about autoloading and engines.


### Overriding Views

When Rails looks for a view to render, it will first look in the `app/views`
directory of the application. If it cannot find the view there, it will check in
the `app/views` directories of all engines that have this directory.

When the application is asked to render the view for `Blorgh::ArticlesController`'s
index action, it will first look for the path
`app/views/blorgh/articles/index.html.erb` within the application. If it cannot
find it, it will look inside the engine.

You can override this view in the application by simply creating a new file at
`app/views/blorgh/articles/index.html.erb`. Then you can completely change what
this view would normally output.

Try this now by creating a new file at `app/views/blorgh/articles/index.html.erb`
and put this content in it:

```html+erb
<h1>Articles</h1>
<%= link_to "New Article", new_article_path %>
<% @articles.each do |article| %>
  <h2><%= article.title %></h2>
  <small>By <%= article.author %></small>
  <%= simple_format(article.text) %>
  <hr>
<% end %>
```

### Routes

Routes inside an engine are isolated from the application by default. This is
done by the `isolate_namespace` call inside the `Engine` class. This essentially
means that the application and its engines can have identically named routes and
they will not clash.

Routes inside an engine are drawn on the `Engine` class within
`config/routes.rb`, like this:

```ruby
Blorgh::Engine.routes.draw do
  resources :articles
end
```

By having isolated routes such as this, if you wish to link to an area of an
engine from within an application, you will need to use the engine's routing
proxy method. Calls to normal routing methods such as `articles_path` may end up
going to undesired locations if both the application and the engine have such a
helper defined.

For instance, the following example would go to the application's `articles_path`
if that template was rendered from the application, or the engine's `articles_path`
if it was rendered from the engine:

```erb
<%= link_to "Blog articles", articles_path %>
```

To make this route always use the engine's `articles_path` routing helper method,
we must call the method on the routing proxy method that shares the same name as
the engine.

```erb
<%= link_to "Blog articles", blorgh.articles_path %>
```

If you wish to reference the application inside the engine in a similar way, use
the `main_app` helper:

```erb
<%= link_to "Home", main_app.root_path %>
```

If you were to use this inside an engine, it would **always** go to the
application's root. If you were to leave off the `main_app` "routing proxy"
method call, it could potentially go to the engine's or application's root,
depending on where it was called from.

If a template rendered from within an engine attempts to use one of the
application's routing helper methods, it may result in an undefined method call.
If you encounter such an issue, ensure that you're not attempting to call the
application's routing methods without the `main_app` prefix from within the
engine.

### Assets

Assets within an engine work in an identical way to a full application. Because
the engine class inherits from `Rails::Engine`, the application will know to
look up assets in the engine's `app/assets` and `lib/assets` directories.

Like all of the other components of an engine, the assets should be namespaced.
This means that if you have an asset called `style.css`, it should be placed at
`app/assets/stylesheets/[engine name]/style.css`, rather than
`app/assets/stylesheets/style.css`. If this asset isn't namespaced, there is a
possibility that the host application could have an asset named identically, in
which case the application's asset would take precedence and the engine's one
would be ignored.

Imagine that you did have an asset located at
`app/assets/stylesheets/blorgh/style.css`. To include this asset inside an
application, just use `stylesheet_link_tag` and reference the asset as if it
were inside the engine:

```erb
<%= stylesheet_link_tag "blorgh/style.css" %>
```

You can also specify these assets as dependencies of other assets using Asset
Pipeline require statements in processed files:

```css
/*
 *= require blorgh/style
 */
```

INFO. Remember that in order to use languages like Sass or CoffeeScript, you
should add the relevant library to your engine's `.gemspec`.

### Separate Assets and Precompiling

There are some situations where your engine's assets are not required by the
host application. For example, say that you've created an admin functionality
that only exists for your engine. In this case, the host application doesn't
need to require `admin.css` or `admin.js`. Only the gem's admin layout needs
these assets. It doesn't make sense for the host app to include
`"blorgh/admin.css"` in its stylesheets. In this situation, you should
explicitly define these assets for precompilation.  This tells Sprockets to add
your engine assets when `bin/rails assets:precompile` is triggered.

You can define assets for precompilation in `engine.rb`:

```ruby
initializer "blorgh.assets.precompile" do |app|
  app.config.assets.precompile += %w( admin.js admin.css )
end
```

For more information, read the [Asset Pipeline guide](asset_pipeline.html).

### Other Gem Dependencies

Gem dependencies inside an engine should be specified inside the `.gemspec` file
at the root of the engine. The reason is that the engine may be installed as a
gem. If dependencies were to be specified inside the `Gemfile`, these would not
be recognized by a traditional gem install and so they would not be installed,
causing the engine to malfunction.

To specify a dependency that should be installed with the engine during a
traditional `gem install`, specify it inside the `Gem::Specification` block
inside the `.gemspec` file in the engine:

```ruby
s.add_dependency "moo"
```

To specify a dependency that should only be installed as a development
dependency of the application, specify it like this:

```ruby
s.add_development_dependency "moo"
```

Both kinds of dependencies will be installed when `bundle install` is run inside
of the application. The development dependencies for the gem will only be used
when the development and tests for the engine are running.

Note that if you want to immediately require dependencies when the engine is
required, you should require them before the engine's initialization. For
example:

```ruby
require "other_engine/engine"
require "yet_another_engine/engine"

module MyEngine
  class Engine < ::Rails::Engine
  end
end
```
