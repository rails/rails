**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Rails Engines Overview
======================

In this guide you will learn about engines and how they can be used to provide
additional functionality to their host applications through a clean and
easy-to-use interface.

After reading this guide, you will know:

* What is an engine.
* How to generate an engine.
* How to build features for the engine.
* How to hook the engine into an application.
* How to override engine functionality in the application.
* How to avoid loading Rails frameworks with Load and Configuration Hooks.

--------------------------------------------------------------------------------

What are Engines?
-----------------

Engines can be thought of as miniature applications that encapsulate specific
functionality and integrate with a larger Rails application. An engine extends a
[plugin](plugins.html), with the
[`Rails::Engine`](https://api.rubyonrails.org/classes/Rails/Engine.html) class
[inheriting](engines.html#the-inheritance-hierarchy) behavior from
[`Rails::Railtie`](https://api.rubyonrails.org/classes/Rails/Railtie.html).

Some examples of engines in action:

* [Devise](https://github.com/heartcombo/devise) which provides authentication
  for its parent applications
* [Thredded](https://github.com/thredded/thredded) which provides forum
  functionality
* [Refinery CMS](https://github.com/refinery/refinerycms) which provides a CMS
  engine
* [Active Storage](https://github.com/rails/rails/tree/main/activestorage) which
  provides file storage as an engine.
* [Action Text](https://github.com/rails/rails/tree/main/actiontext) which
  provides a rich text editor as an engine.
* [`Rails::Application`](https://api.rubyonrails.org/classes/Rails/Application.html)
  inheriting much of its behavior from `Rails::Engine`.


NOTE: The main application is always the final authority in a Rails environment.
While engines can extend or enhance the application's functionality, they are
meant to support the app — not override or redefine its behavior. Engines exist
to serve the application, not the other way around.

### Inheritance Hierarchy

At the base of this hierarchy,
[`Railtie`](https://api.rubyonrails.org/classes/Rails/Railtie.html) is the core
building block of the Rails framework. It provides hooks into the Rails
initialization process and allows extensions, such as frameworks (e.g. Active
Record, Action Mailer) or third-party libraries, to tie into the Rails boot
sequence.

The [`Rails Engine`](https://api.rubyonrails.org/classes/Rails/Engine.html)
builds on `Railtie` by adding support for things like routes, isolated
namespaces, and load paths, making it possible to package complete Rails
components. Engines and applications also share a common directory structure.

While an engine is packaged like a miniature Rails application, it runs inside a
host Rails application. The host
[Rails::Application](https://api.rubyonrails.org/classes/Rails/Application.html)
coordinates boot, executes engine initializers, and builds the overall
middleware stack. Engines can also define their own configuration and contribute
middleware, but these take effect when the host application boots.

### Engines and Plugins

Engines are also closely related to plugins - all engines are plugins, but not
all plugins are engines. The two share a common `lib` directory structure, and
are both generated using the `rails plugin new` generator.

While a plugin is generated using `rails plugin new <plugin_name>`, an engine is
generated using either:

```bash
rails plugin new <engine_name> --full
# or
rails plugin new <engine_name> --mountable
```

The `--full` option tells the generator to create an engine with its own
models/controllers that share the host app’s namespace. The `--mountable` option
creates a fully isolated, mountable engine with its own namespace.

You can read more about the different generator options in the [Rails Plugins
Generator Options](plugins.html#generator-options) section.

### Using an Engine

You add an engine to your host application's `Gemfile`, and depending on how the
engine is designed, you may need to mount it in the main app's routes. Mounting
is required when the engine provides its own routes, as this makes any routes,
controllers, views, or assets defined in the engine available at that mount
point in the host application. This is covered later in the section [Using the
Engine in a Host Application](#using-the-engine-in-a-host-application).

Some engines, however, don't need to be mounted. These are often backend-only
engines, such as those that provide Active Record models, rake tasks, or other
internal functionality without exposing routes. In these cases, adding the gem
to your application's Gemfile is enough to make its features available.

When an engine is mounted, it has an isolated namespace. This means the host
application and the mounted engine can have a routing helper with the same name
(such as `articles_path`) without clashing. Along with this, controllers,
models, and table names are also namespaced. You'll see how to do this later in
the [Routes section](#routes).

Generating an Engine
--------------------

In the following example, you will be building an engine, called "blorgh" that
provides blogging functionality to its host applications, allowing for new
articles and comments to be created. It will use the [`--mountable`
option](plugins.html#generator-options) to generate the engine.

To generate an engine, you will need to run the plugin generator and pass it
options as needed. For the "blorgh" example, you will need to create a
"mountable" engine, running this command in a terminal:

```bash
$ rails plugin new blorgh --mountable
```

The `--mountable` option allows the engine to behave like a self-contained
mini-application that can be easily integrated into a host Rails application
without polluting its global namespace. It will:

- namespace all controllers, routes, views, helpers, and assets under the
  `Blorgh` module, preventing conflicts with similarly named components in the
  host app.
- isolate routing to the engine, allowing you to mount it at a specific path in
  the host app (e.g., `/blorgh`), while keeping its internal route structure
  independent.
- make the engine more modular and reusable, so it can be plugged into different
  applications with minimal configuration.

### The Directory Structure

The structure of the `--mountable` engine will be as follows:

```
blorgh/
├── app/
│   ├── assets/
│   │   ├── images/
│   │   │   └── blorgh/
│   │   └── stylesheets/
│   │       └── blorgh/
│   │           └── application.css
│   ├── controllers/
│   │   ├── concerns/
│   │   └── blorgh/
│   │       └── application_controller.rb
│   ├── helpers/
│   │   └── blorgh/
│   │       └── application_helper.rb
│   ├── jobs/
│   │   └── blorgh/
│   │       └── application_job.rb
│   ├── mailers/
│   │   └── blorgh/
│   │       └── application_mailer.rb
│   ├── models/
│   │   ├── concerns/
│   │   └── blorgh/
│   │       └── application_record.rb
│   └── views/
│       └── layouts/
│           └── blorgh/
│               └── application.html.erb
├── bin/
│   ├── rails
│   └── rubocop
├── config/
│   └── routes.rb
├── lib/
│   └── tasks/
│       └── blorgh_tasks.rake
│   ├── blorgh/
│   │   ├── engine.rb
│   │   └── version.rb
│   ├── blorgh.rb
├── test/
│   ├── controllers/
│   └── dummy/
│       ├── app/
│       ├── bin/
│       ├── config/
│       ├── log/
│       ├── public/
│       ├── storage/
│       ├── tmp/
│   ├── fixtures/
│   │   └── files/
│   ├── helpers/
│   ├── integration/
│   │   └── navigation_test.rb
│   ├── mailers/
│   ├── models/
│   ├── blorgh_test.rb
│   ├── test_helper.rb
├── Gemfile
├── Rakefile
├── README.md
├── blorgh.gemspec
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
    # lib/blorgh/engine.rb

    module Blorgh
      class Engine < ::Rails::Engine
        isolate_namespace Blorgh
      end
    end
    ```

`--mountable` engines, like above, contain some files that are not present in
the `--full` option, these are:

  * A namespaced `ApplicationController` stub
  * A namespaced `ApplicationHelper` stub
  * A layout view template for the engine
  * Namespace isolation to `config/routes.rb`:

    ```ruby
    Blorgh::Engine.routes.draw do
    end
    ```

  * Namespace isolation to `lib/blorgh/engine.rb` as described above.

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

### Core Engine Setup

#### The `.gemspec` File

At the root of your engine, you’ll find a file named `blorgh.gemspec`. This file
defines your engine as a gem. It includes metadata like the gem name, version,
authors, dependencies, and which files to include when it's packaged.

To use this engine in a host Rails application, you reference it in the app’s
`Gemfile` like so:

```ruby
gem "blorgh", path: "../blorgh"
```

Then run:

```bash
bundle install
```

This tells Bundler to treat the engine as a gem and load it accordingly.

INFO: Instead of publishing an engine as a standalone gem, you can generate an
engine inside your application and deploy it for use by that application only.
For example, placing the engine under `engines/blorgh` and referencing it in
your `Gemfile` allows you to keep it within the same codebase.

#### The Engine Entry Point: `lib/blorgh.rb`:

Bundler looks for a file matching the gem name, `lib/blorgh.rb`. This file is
the main entry point of the engine. It typically requires the engine definition
and sets up a base module:

```ruby
# lib/blorgh.rb
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
# lib/blorgh/engine.rb
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

The `isolate_namespace Blorgh` from the Engine class is crucial. It prevents
your engine’s components (like models, routes, helpers, and controllers) from
clashing with those in the host application or other engines.

For example:

* A generated model becomes `Blorgh::Article` rather than `Article`.
* The table name is `blorgh_articles`, not `articles`.
* A controller becomes `Blorgh::ArticlesController`, with views in
  `app/views/blorgh/articles`.
* A helper becomes `Blorgh::ArticlesHelper`.
* Mailers and Jobs are namespaced as well.
* Engine routes are kept isolated and don’t mix with the main app’s routes. This
  is discussed later in the [Routes](#routes) section of this guide.

NOTE: It is recommended that the `isolate_namespace` line be left within the
`Engine` class definition. Without this isolation, files from the engine might
"leak" into the host app’s namespace or identically named classes might override
each other.

### Understanding the `app` Directory

The `app` directory in a mountable engine mirrors the familiar structure of a
standard Rails application. It includes subdirectories like `assets`,
`controllers`, `helpers`, `jobs`, `mailers`, `models`, and `views`.

Here’s what you should know about each of these, especially in the context of a
namespaced engine like `blorgh`:

#### `app/assets`

Inside `app/assets`, you’ll find directories for `images` and `stylesheets`.
Each of these contains a subdirectory named after your engine—`blorgh` in this
case.

This namespacing is important because it ensures that your engine’s assets don’t
conflict with those from other engines or the host application. For example:

```
app/assets/stylesheets/blorgh/application.css
```

#### `app/controllers`

The `controllers` folder contains a `blorgh/` subdirectory where all engine
controllers live. It starts with an `application_controller.rb`:

```ruby
# app/controllers/blorgh/application_controller.rb
module Blorgh
  class ApplicationController < ActionController::Base
  end
end
```

This controller acts as the base for all controllers in the engine, much like
`ApplicationController` does in a full app. Placing it (and all other
controllers) in the `blorgh/` module ensures they won’t clash with similarly
named controllers in the host app or other engines.

#### Other Namespaced Directories

Similar to `app/controllers`, you’ll find a `blorgh/` subdirectory under these
other top-level folders:

* `app/helpers/blorgh/`
* `app/jobs/blorgh/`
* `app/mailers/blorgh/`
* `app/models/blorgh/`

Each of these may include a corresponding `application_*.rb` file (e.g.,
`application_helper.rb`) for defining shared behavior.

This consistent namespacing helps prevent naming collisions and keeps your
engine modular and encapsulated.

#### `app/views`

Inside `app/views/layouts`, you’ll find a layout file for the engine:

```
app/views/layouts/blorgh/application.html.erb
```

This is the default layout used by views inside the engine. It’s useful if your
engine is meant to be used as a self-contained application (e.g., admin
dashboards, wikis, etc.). If this engine is to be used as a stand-alone engine,
then you would add any customization to its layout in this file, rather than the
application's `app/views/layouts/application.html.erb` file.

If you don't want to use a specific layout in the views of the engine, then you
can delete this file and reference a different layout in the controllers of your
engine.

#### `/bin`

This directory contains one file, `bin/rails`, which enables you to use the
`rails` sub-commands and generators just like you would within an application.
This means that you are able to generate new controllers and models for this
engine very easily by running commands like this:

```bash
$ bin/rails generate model
```

Keep in mind, of course, that anything generated with these commands inside of
an engine that has `isolate_namespace` in the `Engine` class will be namespaced.

#### `/test`

The `test` directory is where tests for the engine will go. To test the engine,
there is a cut-down version of a Rails application embedded within it at
`test/dummy`. This application will mount the engine at `/blorgh`, which will
make it accessible through the application's routes at that path.

```ruby
# test/dummy/config/routes.rb
Rails.application.routes.draw do
  mount Blorgh::Engine => "/blorgh"
end
```

Inside the test directory there is the `test/integration` directory, where
integration tests for the engine should be placed. Other directories can be
created in the `test` directory as well. For example, you may wish to create a
`test/models` directory for your model tests.

Providing Engine Functionality
------------------------------

The engine that we'll build, `blorgh`, will allow you to add article submissions
and comment functionality when added to any Rails application.

### Generating an Article Resource

The first thing to generate for a blog engine is the `Article` model and related
controller. To quickly generate this, you can use the Rails scaffold generator.

```bash
$ bin/rails generate scaffold article title:string text:text
```

This command will output this information:

```
invoke  active_record
create    db/migrate/<timestamp>_create_blorgh_articles.rb
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

#### The Migration and Model

The scaffold generator invokes the `active_record` generator, which generates a
_migration_ and a _model_ for the resource.

NOTE: The migration is named `create_blorgh_articles` instead of the usual
`create_articles`, and the model is located at `app/models/blorgh/article.rb`
rather than `app/models/article.rb`, since we used the `isolate_namespace`
method in the `Blorgh::Engine` class.

#### The Test and Fixture

Next, the `test_unit` generator is invoked for this model, generating a model
test at `test/models/blorgh/article_test.rb` (rather than
`test/models/article_test.rb`) and a fixture at
`test/fixtures/blorgh/articles.yml` (rather than `test/fixtures/articles.yml`).

#### The Route

Thereafter,`resources :articles`, for the `article` resource, is inserted into
the `config/routes.rb` file for the engine.

```ruby
Blorgh::Engine.routes.draw do
  resources :articles
end
```

NOTE: The routes are created on the `Blorgh::Engine` object rather than the
`YourApp::Application` class. This ensures that the engine routes are confined
to the engine itself and can be mounted at a specific point, as shown in the
[Writing Tests](#writing-tests) section. It also allows the engine's routes to
be isolated from routes that are within the application. The [Routes](#routes)
section of this guide describes it in detail.

#### The Controller and Views

Next, the `scaffold_controller` generator is invoked, generating a controller
called `Blorgh::ArticlesController` (at
`app/controllers/blorgh/articles_controller.rb`) and its related views are
created at `app/views/blorgh/articles`.

This generator also generates tests for the controller
(`test/controllers/blorgh/articles_controller_test.rb` and
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

#### The Helper

The helper inside `app/helpers/blorgh/articles_helper.rb` is also namespaced:

```ruby
module Blorgh
  module ArticlesHelper
    # ...
  end
end
```

This prevents conflicts with any other engine or application that may have an
article resource as well.

#### Exploring the Engine in the Browser

You can explore the engine by first running `bin/rails db:migrate` at the root
of the engine. Then run `bin/rails server` in the engine's root directory to
start the server.

When you open `http://localhost:3000/blorgh/articles` you will see the default
scaffold that has been generated.

Congratulations, you've just generated your first engine!

#### Exploring the Engine in the Console

If you'd rather explore in the console, you can run `bin/rails console` in the
root directory of the engine. Remember: the `Article` model is namespaced, so to
reference it you must call it as `Blorgh::Article`.

```irb
irb> Blorgh::Article.create(title: "Hello, world!", text: "This is a test article.")
=>  #<Blorgh::Article id: 1, title: "Hello, world!", text: "This is a test article.", created_at: "2025-07-13 07:55:27.610591000 +0000", updated_at: "2025-07-13 07:55:27.610591000 +0000">

irb> Blorgh::Article.find(1)
=> #<Blorgh::Article id: 1, title: "Hello, world!" ...>
```

Whenever someone goes to the root path where the engine is mounted, they should
be shown a list of articles. To do this, add the following line

```ruby
root to: "articles#index"
```

to the `config/routes.rb` file inside the engine.

Now you will only need to go to the root of the engine to see all the articles,
rather than visiting `/articles`. This means that instead of visiting
`http://localhost:3000/blorgh/articles`, you can now go to
`http://localhost:3000/blorgh`.

### Generating a Comments Resource

Now that the engine can create new articles, add the ability to comment. To do
this, you'll need to generate a comment model, a comment controller, and then
modify the articles scaffold to display comments and allow people to create new
ones.

From the engine root, run the model generator to generate a `Comment` model,
with the related table having two columns: an `article` references column and a
`text` text column.

```bash
$ bin/rails generate model Comment article:references text:text
```

This will output the following:

```
invoke  active_record
create    db/migrate/<timestamp>_create_blorgh_comments.rb
create    app/models/blorgh/comment.rb
invoke    test_unit
create      test/models/blorgh/comment_test.rb
create      test/fixtures/blorgh/comments.yml
```

This will generate a `Blorgh::Comment` model and a migration to create the
`blorgh_comments` table.

The generated migration will look like this:

```ruby
# db/migrate/<timestamp>_create_blorgh_comments.rb
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

To fix this, you can modify the existing migration file to look like this:

```ruby
# db/migrate/<timestamp>_create_blorgh_comments.rb
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

#### Updating the View to Show the Comments

To show the comments on an article, edit
`app/views/blorgh/articles/show.html.erb` and add this line before the "Edit"
link:

```html+erb
<h3>Comments</h3>
<%= render @article.comments %>
```

To get the comments to display on an article, define a `has_many` association on
the `Blorgh::Article` model:

```ruby
# app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    has_many :comments
  end
end
```

NOTE: Since the `has_many` association is defined inside a class that is inside
the `Blorgh` module, Rails knows that you want to use the `Blorgh::Comment`
model for these objects, so there's no need to specify the `:class_name` option.

#### Adding a Form and Resource Route to Create Comments

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

Next, create the `blorgh/comments/form` partial that we just referenced. To do
this, create a new directory at `app/views/blorgh/comments` and in it a new file
called `_form.html.erb` with the following content:

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

However, this route doesn't exist yet. You can create it by nesting the
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

However, if you were to create a comment, you would see an error where the
engine is unable to find the partial required for rendering the comments:

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

Using the Engine in a Host Application
--------------------------------------

This section explains how to mount the engine into an application, perform the
initial setup, and connect the engine to an existing class defined by the host
application.

### Mounting the Engine

To use the engine in a host application, add it to the application's `Gemfile`.
If you don't already have an application to test with, you can generate one
outside the engine directory using the `rails new` command:

```bash
$ cd .. # Exit the engine folder
$ rails new host_application
```

This means the host application and the engine will live side by side in your
filesystem, like this:

```bash
/your_project_root/
├── blorgh/           # The engine
└── host_application/ # The app where you test the engine
```

In a production application, once your gem has been published, you would add the
engine to your Gemfile, like you do with other gems. For example, to add Devise
to your application, you would add the following line to your Gemfile:

```ruby
gem "devise"
```

However, since the engine is not published as a gem yet, and you're developing
it locally, you need to link to it using a relative path in the host
application's Gemfile:

```ruby
gem "blorgh", path: "../blorgh"
```

Now that the local path to the gem is specified, run `bundle install` to install
it.

NOTE: By including the engine in the application's `Gemfile`, it will be loaded
automatically when Rails boots. Rails will first require the engine’s entry
point file at `lib/blorgh.rb`. This file typically sets up the namespace and
requires additional files, including `lib/blorgh/engine.rb`, which defines the
`Blorgh::Engine` class. This `Engine` class is responsible for hooking into the
Rails application and mounting the engine's initializers, and other
configurations.

To make the engine's functionality available within a host application, you need
to mount it in the application's `config/routes.rb` file:

```ruby
mount Blorgh::Engine, at: "/blog"
```

This mounts the engine at the `/blog` path, making its routes accessible at
`http://localhost:3000/blog` when the application is running.

NOTE: Some engines, like Devise, expose custom routing helpers (such as
`devise_for`) instead of using `mount`. These helpers internally mount parts of
the engine's functionality at specific paths and provide additional
configuration options tailored to the engine's domain.

However, if you try to run the application at this point, you will see an error
like this:

```bash
SQLite3::SQLException: no such table: blorgh_articles:
SELECT "blorgh_articles".* FROM "blorgh_articles" /*action='index',application='HostApplication',controller='articles'*/
```

This is because the engine's migrations haven't been copied over to the host
application's database yet. The next section explains how to do this.

### Engine Setup

The engine contains migrations for the `blorgh_articles` and `blorgh_comments`
tables which need to be created in the application's database so that the
engine's models can query them correctly.

#### Copying the Migrations

To copy these migrations into the application run the following command from the
application's root:

```bash
$ bin/rails blorgh:install:migrations
```

which will output something like this:

```
Copied migration <timestamp_1>_create_blorgh_articles.blorgh.rb from blorgh
Copied migration <timestamp_2>_create_blorgh_comments.blorgh.rb from blorgh
```

INFO: When run for the first time, `bin/rails blorgh:install:migrations` copies
over all the migrations from the engine. When run the next time, it will only
copy over migrations that haven't been copied over already. This is useful if
you want to revert the migrations from the engine.

#### Migrations for Multiple Engines

If you have multiple engines referenced in the host application, that need
migrations copied over, use `railties:install:migrations` instead:

```bash
$ bin/rails railties:install:migrations
```

This will save you from having to run a separate `install:migrations` task for
each engine individually.

#### Referencing a Custom Path for the Migrations

If your engine stores its migrations in the non-default location, you can
specify a custom path in the source engine for the migrations using
`MIGRATIONS_PATH`:

```bash
$ bin/rails railties:install:migrations MIGRATIONS_PATH=db_blorgh
```

#### Migrations for Multiple Databases

If you have multiple databases within an engine, you can specify the target
database by specifying the `DATABASE` option:

```bash
$ bin/rails railties:install:migrations DATABASE=animals
```

NOTE: These tasks are provided by
[`ActiveRecord::Railtie`](https://api.rubyonrails.org/classes/Rails/Railtie.html),
the Rails component responsible for managing how Active Record integrates into
an application. When run, it looks through all loaded engines and copies any
exposed migrations into the host application's `db/migrate` folder, saving you
from having to run a separate `install:migrations` task for each engine
individually.

#### Running Migrations

To run these migrations within the context of the application, run:

```bash
$ bin/rails db:migrate
```

#### Running and Reverting Migrations for Only One Engine

If you have multiple engines referenced in the host application, and you would
like to run migrations only from one engine, you can do it by specifying
`SCOPE`:

```bash
$ bin/rails db:migrate SCOPE=blorgh
```

This scope may also be useful if you want to revert an engine's migrations
before removing it.

To revert all migrations from blorgh engine you can run code such as:

```bash
$ bin/rails db:migrate SCOPE=blorgh VERSION=0
```

Once you've run the migrations, you can access the engine through
`http://localhost:3000/blog`.

The articles will be empty, because the table created inside the application is
different from the one created within the engine. You can explore the engine
through the host application, in the same way as you did when it was only an
engine.

### Connecting Engine Records to Application Models

When building a Rails engine, you may want to connect the engine's records to
models defined by the host application. For example, in the blorgh engine, you
might want each `article` or `comment` to have an associated `author`. While the
engine sets up the `author` relationship, the actual model, `User` in this case,
comes from the host application.

This section explains how to associate an `Article` from the engine with a
`User` from the host application. For simplicity, assume the host application
uses a model called `User`, but there could be a case where a different host
application calls this class something different, such as `Person`. For this
reason, the engine should not hardcode associations specifically for a `User`
class. Instead, it should be configurable. This is covered in the [next
section](#configuring-the-engine-to-use-a-custom-class).


#### Generating a User Model in the Host Application

To keep it simple in this case, the application will have a class called `User`
that represents the users of the application. It can be generated using this
command inside the application's root directory:

```bash
$ bin/rails generate model user name:string
```

The `bin/rails db:migrate` command needs to be run here to ensure that our
application has the `users` table for future use.

#### Associating `author_name` from the Engine to a Class in the Host Application

The article form will include a new text field called `author_name`, where users
can enter their name. The engine will use this name to either find an existing
`User` object or create a new one. It will then associate the article with that
`User` (or whatever class the host application uses to represent authors) as the
article's author.

Add the `author_name` text field to the
`app/views/blorgh/articles/_form.html.erb` partial inside the engine. This can
be added above the `title` field with the following code:

```html+erb
<%= form_with(model: article) do |form| %>
  <%# ... %>

  <div class="field">
    <%= form.label :author_name %><br>
    <%= form.text_field :author_name %>
  </div>

  <div>
    <%= form.label :title, style: "display: block" %>
    <%= form.text_field :title %>
  </div>
  <%# ... %>
<% end %>
```

The author's name should also be displayed on the article's page. Add this code
above the "Title" output inside `app/views/blorgh/articles/_article.html.erb`:

```html+erb
<p>
  <strong>Author:</strong>
  <%= article.author.name %>
</p>
```

Next, we need to update the `Blorgh::ArticlesController#article_params` method
to permit the new form parameter:

```ruby
def article_params
  params.expect(article: [:title, :text, :author_name])
end
```

The `Blorgh::Article` model should include logic to convert the `author_name`
field into an actual `User` object (or whatever class the host application uses
for authors) and associate it with the article before it is saved. It should
also define an `attr_accessor` for `author_name` to provide getter and setter
methods for this attribute.

Start by adding the `attr_accessor` for `author_name`, the association for the
author and the `before_validation` call into `app/models/blorgh/article.rb`.

```ruby#7-10
# app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    has_many :comments

    # Add the author association to the model
    attr_accessor :author_name
    belongs_to :author, class_name: "User" # The User class exists in the host application

    before_validation :set_author

    private
      def set_author
        self.author = User.find_or_create_by(name: author_name)
      end
  end
end
```

For now, this setup allows the engine to associate an author name with the
`User` model defined by the host application, even though it introduces a
coupling that will be removed later. It will be made more configurable in the
[next section](#configuring-the-engine-to-use-a-custom-class).

There also needs to be a way of associating the records in the `blorgh_articles`
table with the records in the `users` table. Because the association in the
engine is called `author`, there should be an `author_id` column added to the
`blorgh_articles` table.

To generate this new column, run this command within the engine's root
directory:

```bash
$ bin/rails generate migration add_author_id_to_blorgh_articles author_id:integer
```

#### Copying and Running the Migration in the Host Application

As discussed in the [Copying the Migrations](#copying-the-migrations) section,
this new migration will need to be copied to the host application:

```bash
$ bin/rails blorgh:install:migrations
```

```
Copied migration <timestamp>_add_author_id_to_blorgh_articles.blorgh.rb from blorgh
```

Notice that only _the latest_ migration was copied over. This is because the
first two migrations were copied over the first time this command was run in a
[previous section](#copying-the-migrations).

Run the migration using:

```bash
$ bin/rails db:migrate
```

#### Viewing the Association in the Rails console

Now that you've associated the `author_name` from the engine to the `User` model
in the host application, you can go to the form in the host application at
`http://localhost:3000/blog/articles/new` and create an article with an author
name that will create and link to a `User` record in the host application.

If you open up the rails console in the host application, you can view the
`Blorgh::Article` record that was created, and see that it is associated with
the `User` record from the host application:

```irb
irb> article = Blorgh::Article.last
=> #<Blorgh::Article id: 1, title: "Hello, World!", text: "This is a test article.", created_at: "2025-07-16 19:04:54.552457000 +0000", updated_at: "2025-07-16 19:04:54.552457000 +0000", author_id: 1>

irb> user = article.author
=> #<User id: 1, name: "Fake Author 1", created_at: "2025-07-16 19:04:54.542709000 +0000", updated_at: "2025-07-16 19:04:54.542709000 +0000">
```

#### Using a Controller Provided by the Application

In a typical Rails application, all controllers inherit from
`ApplicationController`, which often contains shared logic like authentication
methods or session helpers.

Rails engines, however, are isolated by default. Each engine has its own
`ApplicationController` (like `Blorgh::ApplicationController`) to avoid
conflicts with the main app. However, sometimes, the engine's controllers need
to access methods defined in the main application's `ApplicationController`.
This is often necessary for features like authentication (`current_user`),
authorization checks, or helper methods that manage things like user
preferences, flash messages, or layout logic. This is shared functionality
that's already defined in the main application and shouldn't be re-implemented
in the engine.

To make this possible, you can update the engine’s `ApplicationController` so
that it inherits from the main app’s `ApplicationController` instead of being
isolated. In the Blorgh engine, you would change the file
`app/controllers/blorgh/application_controller.rb` to:

```ruby
# app/controllers/blorgh/application_controller.rb
module Blorgh
  class ApplicationController < ::ApplicationController
  end
end
```

The `::ApplicationController` here refers to the main application's controller.
With this change, all controllers in the engine (which inherit from
`Blorgh::ApplicationController` by default) will now also have access to methods
from the main app’s controller, like `current_user`, authentication helpers, or
anything else defined there.

Keep in mind that this setup only works when the engine is being used inside a
host application that has its own `ApplicationController`.

### Configuring the Engine to Use a Custom Class

Earlier, we hard-coded the author association to the `User` class. However, this
approach isn't ideal, because the engine shouldn't assume the existence of a
specific class in the host application. For example, some applications might use
a differently named class, such as `Person`, to represent authors.

In this section we'll make the class that represents a `User` in the application
customizable for the engine, allowing the engine to work with any model the host
application chooses to use. This will be followed by general configuration tips
for the engine.

#### Creating the `author_class_name` Configuration Setting in the Engine

To make the class that represents a `User` in the application customizable for
the engine, the engine should have a configuration setting called
`author_class_name` that will be used to specify which class name represents
`authors` within the host application.

To define this configuration setting, you should use a
[`mattr_accessor`](https://api.rubyonrails.org/classes/Module.html#method-i-mattr_accessor)
inside the `Blorgh` module for the engine. Add this line to the `Blorgh` module:

```ruby
# lib/blorgh.rb
module Blorgh
  mattr_accessor :author_class_name
end
```

This method provides a getter and setter method on the module with the specified
name. To use it, it must be referenced using `Blorgh.author_class_name`.

The next step is to switch the `Blorgh::Article` model over to this new setting.
Replace `belongs_to :author, class_name: "User"` with `Blorgh.author_class_name`
in the `Blorgh::Article` model:

```ruby
# app/models/blorgh/article.rb
belongs_to :author, class_name: Blorgh.author_class_name
```

The line `self.author = User.find_or_create_by(name: author_name)` in the
`Blorgh::Article` model should also use this class name instead of `User`:

```ruby
# app/models/blorgh/article.rb

def set_author
  self.author = Blorgh.author_class_name.constantize.find_or_create_by(name: author_name)
end
```

To save having to call `constantize` on the `author_class_name` result all the
time, you could create a convenience helper to `constantize` on demand when you
need the Class.

```ruby
# lib/blorgh.rb
module Blorgh
  mattr_accessor :author_class_name

  def self.author_class
    author_class_name.constantize
  end
end
```

This would then turn the above code for `set_author` into this:

```ruby
# app/models/blorgh/article.rb
self.author = Blorgh.author_class.find_or_create_by(name: author_name)
```

#### Setting the `author_class_name` Configuration Setting in the Host Application

To set this configuration setting within the host application, an initializer
can be used. By using an initializer, the configuration will be set up before
the application starts and before it calls the engine's models. This is
important because the engine's models may depend on this configuration setting
existing.

Create a new initializer at `config/initializers/blorgh.rb` inside the host
application and set the `author_class_name` configuration setting to `User`:

```ruby
Blorgh.author_class_name = "User"
```

In a different host application where the model is called `Person`, you would
set the `author_class_name` configuration setting to `Person`.

WARNING: Be sure to pass the class name as a string (e.g., `"User"`), not as a
constant (`User`). If you use the class directly, Rails may try to load it and
its associated table before the application has fully initialized. This can
cause errors if the table hasn't been created yet. By using a string, the engine
can safely convert it to a class later using `constantize`, after initialization
is complete.

Try creating a new article - everything should work just as before. The key
difference is that the engine now uses the `author_class_name` configuration set
in `config/initializers/blorgh.rb` to determine which model to associate as the
author.

At this point, the engine no longer has a hardcoded dependency on a specific
class name like `User`. Instead, it relies on whatever class name is specified
in the configuration. The only requirement is that the configured class name is
a class that responds to `find_or_create_by` and returns an object that can be
associated with an article. That object should also have an identifiable
attribute (such as an `id`) that can be used for lookup and display.

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
section](configuring.html#initializers) of the Configuring Rails Applications
guide, and works precisely the same way as the `config/initializers` directory
inside an application. The same thing goes if you want to use a standard
initializer.

For locales, simply place the [locale files in the `config/locales` directory](i18n.html#providing-translations-for-internationalized-strings),
just like you would in an application.

Improving the Engine
--------------------

This section explains how to add and/or override engine functionality in the
main Rails application.

### Overriding Models and Controllers

Engine models and controllers can be reopened and extended by the host
application to customize or override their behavior. This is useful when the
host application needs to make changes, such as adding validations to a model or
adjusting controller logic, without modifying the engine’s source code directly.

A common approach is to place override files in a dedicated directory, such as
`app/overrides`, and manually load them during application initialization. This
directory is ignored by the Rails autoloader to prevent naming conflicts and to
prevent unintended constant loading.

Here’s how you can set this up in the host application:

```ruby
# config/application.rb
module HostApplication
  class Application < Rails::Application
    # ...

    overrides = Rails.root.join("app/overrides")
    Rails.autoloaders.main.ignore(overrides)

    config.to_prepare do
      Dir.glob("#{overrides}/**/*_override.rb").sort.each do |override|
        load override
      end
    end
  end
end
```

#### Why Use `to_prepare` and `load`

The `to_prepare` block ensures that overrides are reloaded on each request in
development (and only once in production), which is helpful when working with
engines during development. Using `load` instead of `require` allows the
override files to be reloaded without restarting the server.

#### Why Ignore Autoloading

The `app/overrides` directory is ignored by Zeitwerk (Rails’ autoloader) so that
you can control exactly when the files are loaded. This prevents potential
conflicts with similarly named classes or modules elsewhere in the application.

#### Naming Convention

It’s recommended to suffix override files with `_override.rb` (e.g.,
`article_override.rb`) to clearly distinguish them from standard models and
controllers and to avoid any conflicts with autoloaded files.

#### Reopening Existing Classes Using `class_eval`

In order to override the engine model

```ruby
# blorgh/app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    # ...
  end
end
```

you can create a file that _reopens_ that class. This example reopens the
`Blorgh::Article` model and adds a validation for the `title` attribute.

```ruby
# host_application/app/overrides/models/blorgh/article_override.rb
Blorgh::Article.class_eval do
  validates :title, presence: true, length: { minimum: 10 }
end
```

It is very important that the override _reopens_ the class or module. Using the
`class` or `module` keywords would define them if they were not already in
memory, which would be incorrect because the definition lives in the engine.
Using
[`class_eval`](https://api.rubyonrails.org/classes/Module.html#method-i-class_eval)
as shown above ensures you are reopening an existing module.

#### Reopening Existing Classes Using ActiveSupport::Concern

While
[`Class#class_eval`](https://api.rubyonrails.org/classes/Module.html#method-i-class_eval)
is useful for making simple runtime changes to a class, more complex
modifications—especially those involving multiple modules with dependencies—are
often better handled using
[`ActiveSupport::Concern`](https://api.rubyonrails.org/classes/ActiveSupport/Concern.html).
It provides a structured way to define module behavior and dependencies,
ensuring consistent load order and making it easier to organize and compose
reusable code.

Suppose you want to extend the `Blorgh::Article` model from the host application
by:

- Adding a new instance method: `time_since_created`
- Overriding the existing `summary` method

Here’s how you can do it cleanly using `ActiveSupport::Concern`:

##### Defining a Concern

First, define a concern that contains the shared behavior:

```ruby
# blorgh/lib/concerns/models/article.rb
module Blorgh::Concerns::Models::Article
  extend ActiveSupport::Concern

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

##### Setting Up the Engine’s Base Model

Next, include the concern in the engine’s `Article` model. This ensures that
engine users who don’t override the model still benefit from the concern’s
behavior:

```ruby
# blorgh/app/models/blorgh/article.rb
module Blorgh
  class Article < ApplicationRecord
    include Blorgh::Concerns::Models::Article
  end
end
```

##### Extending in the Host Application

Finally, the host application can override and extend the model by reopening it.
Here we add a new instance method and override the existing `summary` method:

```ruby
# host_application/app/models/blorgh/article.rb
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

### Autoloading and Engines

Please check the [Autoloading and Reloading
Constants](autoloading_and_reloading_constants.html#autoloading-and-engines)
guide for more information about autoloading and engines.

### Overriding Views

When the host application looks for a view to render, it will first look in the
`app/views` directory of the application. If it cannot find the view there, it
will then check in the `app/views` directories of all engines that have this
directory.

For example, when the host application is asked to render the view for
`Blorgh::ArticlesController`'s index action, it will first look for the path
`app/views/blorgh/articles/index.html.erb` within the application. If it cannot
find it, it will then look inside the engine.

You can override this view in the host application by creating a new file at
`app/views/blorgh/articles/index.html.erb`. Then you can completely change what
this view would normally output, like the following:

```html+erb
<h1>Articles</h1>
<%= link_to "New Article", new_article_path %>
<% @articles.each do |article| %>
  <h2><%= article.title %></h2>
  <small>By <%= article.author.name %></small>
  <%= simple_format(article.text) %>
  <hr>
<% end %>
```

The new view at `localhost:3000/blog/articles` will now display the updated view
with the new content.

### Routes

Routes defined inside a Rails engine are isolated from the main application by
default. This isolation is established by the
[`isolate_namespace`](#the-engine-class-definition-lib-blorgh-engine-rb) call in
the engine’s `Engine` class. It allows both the engine and the application to
define routes with the same names—like `articles_path`—without conflict.

#### Defining Engine Routes

You can define routes inside the engine using the engine's route set:

```ruby
# blorgh/config/routes.rb
Blorgh::Engine.routes.draw do
  resources :articles
end
```

When your engine is mounted into a host application (e.g., at `/blog`), this
creates routes like:

* `/blog/articles` → `Blorgh::ArticlesController#index`

#### Linking to Engine Routes from the Application

Because routes are namespaced and isolated, route helpers like `articles_path`
may refer to either the engine's route or the application's route, depending on
where the view is rendered from.

For example:

```html+erb
<%= link_to "Blog articles", articles_path %>
```

If rendered from the application, it will likely resolve to the application's
`articles_path`. If rendered from inside the engine, it may resolve to the
engine's `articles_path`.

To ensure you're linking to the engine's route, use the engine's named routing
proxy. For the `blorgh` engine, that would be:

```html+erb
<%= link_to "Blog articles", blorgh.articles_path %>
```

This explicitly tells Rails to use the `articles_path` defined in the `Blorgh`
engine.

The name of the proxy method (`blorgh`) matches the name of the engine as
declared in `engine.rb` via `isolate_namespace Blorgh`.

#### Linking to Application Routes from the Engine

If you need to reference a route defined in the main application from within the
engine (for example, linking to the homepage), you can use the `main_app`
routing proxy:

```erb
<%= link_to "Home", main_app.root_path %>
```

This ensures the route always points to the host application, even when called
from within engine views.

#### Targeted Routes

If you call a route helper like `root_path` from inside an engine view, and both
the engine and application define a root route, Rails may not know which one to
use. Or worse, it may raise an error if the route doesn't exist in the engine.

To prevent this, use `main_app.root_path` to target the application, and set
`blorgh.root_path` (or your engine's namespace) to target the engine.

Being explicit with routing proxies ensures that your routes behave consistently
and avoids surprising bugs when working across engines and applications.

### Assets

Assets in a Rails engine work just like they do in a full Rails application.
Because your engine inherits from Rails::Engine, Rails will automatically look
for assets in the engine’s `app/assets` and `lib/assets` directories.

To avoid naming conflicts with the host application, all engine assets should be
namespaced under a subdirectory that matches the engine’s name. For example,
instead of placing a stylesheet directly at `app/assets/stylesheets/style.css`,
you should place it at `app/assets/stylesheets/<engine_name>/style.css`, which
would be `app/assets/stylesheets/blorgh/style.css` for the `blorgh` engine.

This prevents collisions with assets in the host application that may have the
same filename.

To include a namespaced engine asset in the host application, reference it using
its full path with the `stylesheet_link_tag` (or similar helpers):

```html+erb
<%= stylesheet_link_tag "blorgh/style.css" %>
```

This will correctly load the stylesheet located at
`app/assets/stylesheets/blorgh/style.css` within the engine.

If you’re using the Asset Pipeline (Sprockets), you can also include engine
assets as dependencies within other stylesheets using a `require` directive:

```css
/*
 *= require blorgh/style
 */
```

This allows engine styles to be bundled into application-wide stylesheets.

INFO: Remember that in order to use languages like Sass or Haml, you should add
the relevant library to your engine's `.gemspec`.

### Separate Assets and Precompiling

In some cases, your engine may include assets that are not required by the host
application. For example, suppose your engine provides an admin interface with
its own layout and styles. These assets, such as `admin.css` or `admin.js`, are
only used within the engine and don't need to be included in the host
application's asset pipeline.

In such situations, it doesn’t make sense for the host app to reference these
assets manually (e.g., via `stylesheet_link_tag "blorgh/admin"`). Instead, you
should explicitly tell Rails to precompile these assets so they’re available
when the engine is used.

To do this, you can add a precompilation hook in your engine's engine.rb file:

```ruby
# lib/blorgh/engine.rb
module Blorgh
  class Engine < ::Rails::Engine
    isolate_namespace Blorgh

    initializer "blorgh.assets.precompile" do |app|
      app.config.assets.precompile += %w( blorgh/admin.js blorgh/admin.css )
    end
  end
end
```

This ensures that these engine-specific assets will be compiled when running:

```bash
bin/rails assets:precompile
```

NOTE: Be sure to include the full namespaced paths (e.g. `blorgh/admin.css`) so
Sprockets can locate the correct files within your engine.

For more information, read the [Asset Pipeline guide](asset_pipeline.html).

### Writing Tests

The `test/` directory works just like it does in a standard Rails application.
You can write unit tests, functional tests, and integration tests to ensure your
engine behaves as expected.

When a Rails engine is generated, it includes a minimal host application inside
the `test/dummy` directory. This "dummy app" is used solely for development and
testing—it simulates how your engine will behave when used in a real
application. You can extend the dummy app by adding controllers, models, or
views as needed to help you test the engine’s functionality in context.

#### Functional and Integration Tests

Since engines are not full applications, they need to be mounted into a host in
order to test things like routing and controllers. That’s where the dummy app
comes in.

When writing controller or integration tests, your tests need to be aware of the
engine’s routing context. Rails doesn’t automatically assume you’re using the
engine’s routes, so if you write a test like this:

```ruby
# test/controllers/blorgh/articles_controller_test.rb
module Blorgh
  class ArticlesControllerTest < ActionDispatch::IntegrationTest
    test "can get index" do
      get articles_path
      assert_response :success
    end
  end
end
```

It might fail because `articles_path` could resolve to the dummy app (or not at
all), rather than your engine. To fix this, you must tell Rails explicitly to
use the engine's routes in your test setup:

```ruby
# test/controllers/blorgh/articles_controller_test.rb
module Blorgh
  class ArticlesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @routes = Engine.routes
    end

    test "can get index" do
      get articles_path
      assert_response :success
    end
  end
end
```

This ensures the test uses the routing context defined in
`Blorgh::Engine.routes`, and that the path helpers like `articles_path` map
correctly to `/blog/articles` (since your engine is mounted at `/blog`).

NOTE: Even though the engine is mounted at `/blog` in the host app, you don't
need to include that prefix in test paths. Setting `@routes = Engine.routes`
scopes everything correctly for you.

The following test checks that the index page for articles loads successfully
and renders the expected heading.

```ruby
# test/controllers/blorgh/articles_controller_test.rb
require "test_helper"

module Blorgh
  class ArticlesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @routes = Engine.routes
    end

    test "can get index" do
      get articles_path
      assert_response :success
      assert_select "h1", "Articles"
    end
  end
end
```

#### Unit and Model Tests

You can test your engine’s models just like in a regular Rails app:

```ruby
# test/models/blorgh/article_test.rb
require "test_helper"

module Blorgh
  class ArticleTest < ActiveSupport::TestCase
    test "title is required" do
      article = Article.new(text: "Some content")
      assert_not article.valid?
      assert_includes article.errors[:title], "can't be blank"
    end
  end
end
```

### Gem Dependencies

Gem dependencies inside an engine should be specified inside the `.gemspec` file
at the root of the engine to allow the engine to be installed as a gem.

NOTE: If the dependencies were to be specified inside the `Gemfile`, instead of
the `.gemspec` file, these would not be recognized by a traditional `gem
install` and so they would not be installed, causing the engine to malfunction.

To specify a dependency that should be installed with the engine during a `gem
install`, specify it inside the `Gem::Specification` block inside the `.gemspec`
file in the engine:

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

If you want to immediately require dependencies when the engine is required, you
should require them before the engine's initialization. For example, in the
`engine.rb` file :

```ruby
require "other_engine/engine"
require "yet_another_engine/engine"

module MyEngine
  class Engine < ::Rails::Engine
  end
end
```
