**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

The Rails Command Line
======================

After reading this guide, you will know how to use the Rails command:

* To create a Rails application.
* To generate models, controllers, tests, and database migrations.
* To start a development server.
* To inspect a Rails application through an interactive shell.
* To add and edit credentials to an application. 

--------------------------------------------------------------------------------

Overview
--------

The Rails command line is a powerful part of the Ruby on Rails framework. It is what allows you to quickly start a new application by generating boiler plate code (that follows convention over configuration). This guide includes an overview of Rails commands that allow you to manage all aspects of your web application, including the database.

You can get a list of rails commands available to you, which will often depend on your current directory, by typing `bin/rails --help`. Each command has a description, and should help you find the thing you need.

```bash
$ bin/rails --help
Usage:
  bin/rails COMMAND [options]

You must specify a command. The most common commands are:

  generate     Generate new code (short-cut alias: "g")
  console      Start the Rails console (short-cut alias: "c")
  server       Start the Rails server (short-cut alias: "s")
  test         Run tests except system tests (short-cut alias: "t")
  test:system  Run system tests
  dbconsole    Start a console for the database specified in config/database.yml
               (short-cut alias: "db")
  plugin new   Create a new Rails railtie or engine

All commands can be run with -h (or --help) for more information.

In addition to those commands, there are:
```

The output of `bin/rails --help` then proceeds to list all commands in alphabetical order, with a short description of each. Something like this:

```bash
In addition to those commands, there are:
about                              List versions of all Rails frameworks ...
action_mailbox:ingress:exim        Relay an inbound email from Exim to ...
action_mailbox:ingress:postfix     Relay an inbound email from Postfix ...
action_mailbox:ingress:qmail       Relay an inbound email from Qmail to ...
action_mailbox:install             Install Action Mailbox and its ...
...
db:fixtures:load                    Load fixtures into the ...
db:migrate                          Migrate the database ...
db:migrate:status                   Display status of migrations
db:rollback                         Roll the schema back to ...
...
turbo:install                      Install Turbo into the app
turbo:install:bun                  Install Turbo into the app with bun
turbo:install:importmap            Install Turbo into the app with asset ...
turbo:install:node                 Install Turbo into the app with webpacker
turbo:install:redis                Switch on Redis and use it in development
version                            Show the Rails version
yarn:install                       Install all JavaScript dependencies as ...
zeitwerk:check                     Check project structure for Zeitwerk ...
```

In addition to `rails --help`, running a particular command from the list above with `--help` can be also be useful. For example, you can learn about the options that can be used with `rails routes`:

```bash
$ bin/rails routes --help
Usage:
  bin/rails routes

Options:
  -c, [--controller=CONTROLLER]      # Filter by a specific controller, e.g. PostsController or Admin::PostsController.
  -g, [--grep=GREP]                  # Grep routes by a specific pattern.
  -E, [--expanded], [--no-expanded]  # Print routes expanded vertically with parts explained.
  -u, [--unused], [--no-unused]      # Print unused routes.

List all the defined routes
```

Most Rails command line subcommands can all be run with `--help` (or `-h`) and the output can be very informative. For example `bin/rails generate model --help` prints two pages of description, in addition to usage and options:

```bash
$ rails generate model --help
Usage:
  bin/rails generate model NAME [field[:type][:index] field[:type][:index]] [options]
Options:
... 
Description:
    Generates a new model. Pass the model name, either CamelCased or
    under_scored, and an optional list of attribute pairs as arguments.

    Attribute pairs are field:type arguments specifying the
    model's attributes. Timestamps are added by default, so you don't have to
    specify them by hand as 'created_at:datetime updated_at:datetime'.

    As a special case, specifying 'password:digest' will generate a
    password_digest field of string type, and configure your generated model and
    tests for use with Active Model has_secure_password (assuming the default ORM and test framework are being used).
    ...
    ...
```

Some of the most commonly used command are:

* `bin/rails console`
* `bin/rails server`
* `bin/rails test`
* `bin/rails generate`
* `bin/rails db:migrate`
* `bin/rails db:create`
* `bin/rails routes`
* `bin/rails dbconsole`
* `rails new app_name`

We'll cover the above commands (and more) in details in this guide, starting with the command for creating a new application.

Creating a New Rails Application
--------------------------------

We can create a brand new Rails application using the `rails new` command. The first argument to `rails new` is the application name.

INFO: You can install the rails gem by typing `gem install rails`, if you don't have it already. For more step-by-step instructions, see [Installing Ruby on Rails](install_ruby_on_rails.html) guide.

With the `new` command, Rails will set up the entire default directory structure along with all the code needed to run the simple application right out of the box:

```bash
$ rails new my_app
     create
     create  README.md
     create  Rakefile
     create  config.ru
     create  .gitignore
     create  Gemfile
     create  app
     ...
     create  tmp/cache
     ...
        run  bundle install
```

You can also pass options to the `new` command to modify its default behavior.

### Configure a Different Database

When creating a new Rails application, you can specify a preferred database for your application by using the `--database` option. The default database for `rails new` is SQLite. For example, you can set up a PostgreSQL database like this:

```bash
$ rails new booknotes --database=postgresql
      create
      create  app/controllers
      create  app/helpers
...
```

The main difference is the content of the `config/database.yml` file, with PostgreSQL option, it looks like this:

```yaml
# PostgreSQL. Versions 9.3 and up are supported.
#
# Install the pg driver:
#   gem install pg
# On macOS with Homebrew:
#   gem install pg -- --with-pg-config=/usr/local/bin/pg_config
# On Windows:
#   gem install pg
#       Choose the win32 build.
#       Install PostgreSQL and put its /bin directory on your path.
#
# Configure Using Gemfile
# gem "pg"
#
default: &default
  adapter: postgresql
  encoding: unicode
  # For details on connection pooling, see Rails configuration guide
  # https://guides.rubyonrails.org/configuring.html#database-pooling
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>


development:
  <<: *default
  database: booknotes_development
  ...
```

The `--database=postgresql` option will also modify other files generated for a new Rails app appropriately, such as adding the `pg` gem to the `Gemfile`, etc. 

### Skipping Defaults

The `rails new` command by default creates dozens of files. By using the `--skip` option, you can skip some files from being generated if you don't need them. For example,

```bash
$ rails new no_storage --skip-active-storage
Based on the specified options, the following options will also be activated:

  --skip-action-mailbox [due to --skip-active-storage]
  --skip-action-text [due to --skip-active-storage]

      create
      create  README.md
      ...
```

In the above example, Action Mailbox and Action Text are skipped in addition to
Active Storage because they depend on Active Storage functionality.

TIP: You can get a full list of what can be skipped in the options section of `rails new --help` command.

Starting a Rails Application
----------------------------

We can start a newly created Rails application using the `bin/rails server` command, which launches the [Puma](https://github.com/puma/puma) web server that comes bundled with Rails. You'll use this any time you want to access your application through a web browser.

```bash
$ cd my_app
$ bin/rails server
=> Booting Puma
=> Rails 8.1.0 application starting in development
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 6.4.0 (ruby 3.1.3-p185) ("The Eagle of Durango")
*  Min threads: 5
*  Max threads: 5
*  Environment: development
*          PID: 5295
* Listening on http://127.0.0.1:3000
* Listening on http://[::1]:3000
Use Ctrl-C to stop
```

With just two commands we have a Rails application up and running. The `server` command starts the application listening on port 3000 by default. You can open your browser to [http://localhost:3000](http://localhost:3000) to see a basic Rails application running.

INFO: You can also use the alias "s" to start the server: `bin/rails s`.

You can run the application on a different port using the `-p` option. You can also change the environment using `-e` (default is `development`).

```bash
$ bin/rails server -e production -p 4000
```

The `-b` option binds Rails to the specified IP, by default it is localhost. You can run a server as a daemon by passing a `-d` option.

Generating Code
---------------

You can use the `bin/rails generate` command to generate a number of different files and add functionality to your application, such as models, controllers, and full scaffolds. 

To see a list of built-in generators, you can run `bin/rails generate` (or `bin/rails g` for short) without any arguments. It lists all available generators after the usage. You can also learn more about what a specific generator will do by using the `--pretend` option. 

```bash
$ bin/rails generate
Usage:
  bin/rails generate GENERATOR [args] [options]

General options:
  -h, [--help]     # Print generator's options and usage
  -p, [--pretend]  # Run but do not make any changes
  -f, [--force]    # Overwrite files that already exist
  -s, [--skip]     # Skip files that already exist
  -q, [--quiet]    # Suppress status output

Please choose a generator below.
Rails:
  application_record
  benchmark
  channel
  controller
  generator
  helper
...
```

NOTE: When you add certain gems to your application, they may install more generators. You can also create your own generators, see [Generators guide](generators.html) for more.

The purpose of Rails' built-in generators is to save you time by freeing you from having to write repetitive boilerplate code that is necessary for the application to work.

Let's add a controller with the `controller` generator.

### Generating Controllers

We can find out exactly how to use the `controller` generator with the `bin/rails generate controller` command (which is the same as using it with `--help`). There is a "Usage" section and even an example:

```bash
$ bin/rails generate controller
Usage:
  bin/rails generate controller NAME [action action] [options]
...
Examples:
    `bin/rails generate controller credit_cards open debit credit close`

    This generates a `CreditCardsController` with routes like /credit_cards/debit.
        Controller: app/controllers/credit_cards_controller.rb
        Test:       test/controllers/credit_cards_controller_test.rb
        Views:      app/views/credit_cards/debit.html.erb [...]
        Helper:     app/helpers/credit_cards_helper.rb

    `bin/rails generate controller users index --skip-routes`

    This generates a `UsersController` with an index action and no routes.

    `bin/rails generate controller admin/dashboard --parent=admin_controller`

    This generates a `Admin::DashboardController` with an `AdminController` parent class.
```

The controller generator is expecting parameters in the form of `generate controller ControllerName action1 action2`. Let's make a `Greetings` controller with an action of `hello`, which will say something nice to us.

```bash
$ bin/rails generate controller Greetings hello
     create  app/controllers/greetings_controller.rb
      route  get 'greetings/hello'
     invoke  erb
     create    app/views/greetings
     create    app/views/greetings/hello.html.erb
     invoke  test_unit
     create    test/controllers/greetings_controller_test.rb
     invoke  helper
     create    app/helpers/greetings_helper.rb
     invoke    test_unit
```

The above command created various files at specific directories. It created a controller file, a view file, a functional test file, a helper for the view, and added a route.

To test out the new controller, we can modify the `hello` action and the view to display a message:

```ruby
class GreetingsController < ApplicationController
  def hello
    @message = "Hello, how are you today?"
  end
end
```

```html+erb
<h1>A Greeting for You!</h1>
<p><%= @message %></p>
```

Then, we can start the Rails server, with `bin/rails server`, and go to the added route [http://localhost:3000/greetings/hello](http://localhost:3000/greetings/hello) to see the message.

Now let's use the generator to add models to our application.

### Generating Models

The Rails model generator command has a very detailed "Description" section that is worth perusing. Here is the basic usage: 

```bash
$ bin/rails generate model
Usage:
  bin/rails generate model NAME [field[:type][:index] field[:type][:index]] [options]
...
```

As an example, we can generate a `post` model like this:

```bash
$ bin/rails generate model post title:string body:text
    invoke  active_record
    create    db/migrate/20250807202154_create_posts.rb
    create    app/models/post.rb
    invoke    test_unit
    create      test/models/post_test.rb
    create      test/fixtures/posts.yml
```

The model generator adds test files as well as a migration, which you'll need to run with `bin/rails db:migrate`.

NOTE: For a list of available field types for the `type` parameter, refer to the [API documentation](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_column).

### Generating Scaffolds

In addition to generating controllers and models separately, Rails also provides a generator that adds all of the code necessary to create a resource in your application. This is called a *scaffold*. 

A Rails scaffold generates a full set of files for a resource, including a model, controller, views, routes, migration, tests, and helper files. It should be used for quickly prototyping CRUD interfaces or when you want to generate the basic structure of a resource as a starting point that you can customize manually.

If we scaffold the `post` resource you can see all of the files mentioned above being generated:

```bash
$ bin/rails generate scaffold model post title:string body:text
      invoke  active_record
      create    db/migrate/20250808131823_create_models.rb
      create    app/models/model.rb
      invoke    test_unit
      create      test/models/model_test.rb
      create      test/fixtures/models.yml
      invoke  resource_route
       route    resources :models
      invoke  scaffold_controller
      create    app/controllers/models_controller.rb
      invoke    tailwindcss
      create      app/views/models
      create      app/views/models/index.html.erb
      create      app/views/models/edit.html.erb
      create      app/views/models/show.html.erb
      create      app/views/models/new.html.erb
      create      app/views/models/_form.html.erb
      create      app/views/models/_model.html.erb
      invoke    resource_route
      invoke    test_unit
      create      test/controllers/models_controller_test.rb
      create      test/system/models_test.rb
      invoke    helper
      create      app/helpers/models_helper.rb
      invoke      test_unit
      invoke    jbuilder
      create      app/views/models/index.json.jbuilder
      create      app/views/models/show.json.jbuilder
      create      app/views/models/_model.json.jbuilder
```

At this point, you can run `bin/rails db:migrate` to create the `post` table (see [Managing the Database](#managing-the-databse) for more on that command). Then, if you start the Rails server with `bin/rails server` and navigate to [http://localhost:3000/posts](http://localhost:3000/posts), you will be able to interact with the `post` resource - see a list of posts, create new posts, as well as edit and delete them.

INFO: The scaffold generate test files, though you will need to modify them and actually add test cases for your code. See the [Testing guide](testing.html) for an in-depth look at creating and running tests.

### Undoing Code Generation with `bin/rails destroy`

Imagine you had a typo when using the `generate` command for a model (or controller or scaffold or anything), it would be tedious to manually delete each file that was created by the generator. Rails provides a `destroy` command for that reason. You can think of `destroy` as the opposite of `generate`. It'll figure out what generate did, and undo it.

INFO: You can also use the alias "d" to invoke the destroy command: `bin/rails d`.

For example, if you meant to generate an `article` model but instead typed `artcle`: 

```bash
$ rails generate model Artcle title:string body:text
      invoke  active_record
      create    db/migrate/20250808142940_create_artcles.rb
      create    app/models/artcle.rb
      invoke    test_unit
      create      test/models/artcle_test.rb
      create      test/fixtures/artcles.yml
```

You can undo the `generate` command with `destroy` like this:

```bash
$ rails destroy model Artcle title:string body:text
      invoke  active_record
      remove    db/migrate/20250808142940_create_artcles.rb
      remove    app/models/artcle.rb
      invoke    test_unit
      remove      test/models/artcle_test.rb
      remove      test/fixtures/artcles.yml
```

Debugging and Interacting with a Rails Application
--------------------------------------------------

### The Rails Console

The `bin/rails console` command loads a full Rails environment (including models, database, etc.) into an interactive IRB style shell. It is a powerful feature of the Ruby on Rails framework as it allows you to interact with, debug and explore your entire application at the command line.

The Rails Console can be useful for testing out ideas by prototyping with code and for creating and updating records in the database without needing to use a browser.

The Rails Console has several useful features. For example, if you wish to test out some code without changing any data, you can do use `sandbox` mode with `bin/rails console --sandbox`. The `sandbox` mode wraps all database operations in a transaction that rolls back when you exit:

```bash
$ bin/rails console --sandbox
Loading development environment in sandbox (Rails 8.1.0)
Any modifications you make will be rolled back on exit
irb(main):001:0>
```
The `sandbox` option is great for safely testing destructive changes without affecting your database.

You can also specify the Rails environment for the `console` command with the `-e` option:

```bash
$ bin/rails console -e test
Loading test environment (Rails 8.1.0)
```

#### The `app` Object

Inside the Rails Console you have access to the `app` and `helper` instances.

With the `app` method you can access named route helpers:

```irb
> app.root_path
=> "/"
> app.edit_user_path
=> "profile/edit"
```

You can also use the `app` object to make requests of your application without starting a real server:

```irb
>> app.get "/", headers: { "Host" => "localhost" }
Started GET "/" for 127.0.0.1 at 2025-08-11 11:11:34 -0500
...

> app.response.status
=> 200
```

NOTE: You have to pass the "Host" header with the `app.get` request above, because the Rack client used under-the-hood defaults to "www.example.com" if not "Host" is specified. You can modify your application to always use `localhost` using a configuration or an initializer.

The reason you can "make requests" like above is because the `app` object is the same one that Rails uses for integration tests: 

```irb
> app.class
=> ActionDispatch::Integration::Session
```

The `app` object exposes methods like `app.cookies`, `app.session`, `app.post`, and `app.response`. This way you can simulate and debug integration tests in the Rails Console.

#### The `helper` Object

The `helper` object in the Rails console is your direct portal into Rails’ view layer. The `helper` object lets you use view-related formatting and utility methods right in the console, without having to render a view. As well custom helpers defined in your application (i.e. in `app/helpers`).

```irb
> helper.time_ago_in_words 3.days.ago
=> "3 days"

> helper.l(Date.today)
=> "2025-08-11"

> helper.pluralize(3, "child")
=> "3 children"

> helper.truncate("This is a very long sentence", length: 22)
=> "This is a very long..."

> helper.link_to("Home", "/")
=> "<a href=\"/\">Home</a>"

# Assuming a custom_helper method defined in a app/helpers/*_helper.rb file.
> helper.custom_helper
"testing custom_helper"
```

### `bin/rails dbconsole`

The `bin/rails dbconsole` command figures out which database you're using and drops you into the command line interface appropriate for that database. It also figures out the command line parameters to start a session based on your `config/database.yml` file and current Rails environment. 

Once you're in a `dbconsole` session, you can interact with your database directly as you normally would. For example, if you're using PostgreSQL, running `bin/rails dbconsole` may look like this:

```bash
$ bin/rails dbconsole
psql (17.5 (Homebrew))
Type "help" for help.

booknotes_development=# help
You are using psql, the command-line interface to PostgreSQL.
Type:  \copyright for distribution terms
       \h for help with SQL commands
       \? for help with psql commands
       \g or terminate with semicolon to execute query
       \q to quit
booknotes_development=# \dt
                    List of relations
 Schema |              Name              | Type  | Owner 
--------+--------------------------------+-------+-------
 public | action_text_rich_texts         | table | bhumi
 ...
```

The `dbconsole` command is a very convenient shorthand, it's equivalent to running the `psql` command (or `myslq` or `sqlite`) with the appropriate arguments from your `database.yml`:

```bash
psql -h <host> -p <port> -U <username> <database_name>
```

So if your `database.yml` file looks like this:

```yml
development:
  adapter: postgresql
  database: myapp_development
  username: myuser
  password:
  host: localhost
```

Running the `bin/rails dbconsole` command is the same as:

```bash
psql -h localhost -U myuser myapp_development
```

NOTE: The `dbconsole` command supports MySQL (including MariaDB), PostgreSQL, and SQLite3. You can also use the alias "db" to invoke the dbconsole: `bin/rails db`.

If you are using multiple databases, `bin/rails dbconsole` will connect to the primary database by default. You can specify which database to connect to using `--database` or `--db`:

```bash
$ bin/rails dbconsole --database=animals
```

### `bin/rails runner`

The `runner` command executes Ruby code in the context of the Rails application without having to open a Rails Console. This can be useful for one-off tasks that do not need the interactivity of the Rails Console. For instance:

```bash
$ bin/rails runner "puts User.count"
42

$ bin/rails runner 'MyJob.perform_now'
```

You can specify the environment in which the `runner` command should operate using the `-e` switch.

```bash
$ bin/rails runner -e production "puts User.count"
```

You can also execute code in a Ruby file with the `runner` command, in the context of your Rails application:

```bash
$ bin/rails runner lib/path_to_ruby_script.rb
```

By default, `bin/rails runner` scripts are automatically wrapped with the Rails Executor (which is an instance of [ActiveSupport::Executor](https://api.rubyonrails.org/classes/ActiveSupport/Executor.html) associated with your Rails application. The Executor creates a “safe zone” to run arbitrary Ruby inside a Rails app so that the autoloader, middleware stack, and Active Support hooks all behave consistently.

Therefore, executing `bin/rails runner lib/path_to_ruby_script.rb` is functionally equivalent to the following:

```ruby
Rails.application.executor.wrap do
  # executes code inside lib/path_to_ruby_script.rb
end
```

If you have a reason to opt of this behavior, there is a `--skip-executor` option.

```bash
$ bin/rails runner --skip-executor lib/long_running_script.rb
```

### `bin/rails boot`

The `bin/rails boot` command is a low-level Rails command whose entire job is to boot your Rails application. Specifically it loads `config/boot.rb` and `config/application.rb` files so that the application environment is ready to run.

The `boot` command boots the application and exits, does nothing else. So what is it useful for then? 

It can be useful for debugging boot problems. If your app fails to start and you want to isolate the boot phase (without running migrations, starting the server, etc.), `bin/rails boot` can be a simple test.

It can also be useful for timing application initialization. You can profile how long your application takes to boot by wrapping `bin/rails boot` in a profiler.

The `boot` command is also run internally by all commands that need the Rails application loaded (e.g. `server`, `console`, `runner`, etc.).

Inspecting an Application
-------------------------

### `bin/rails routes`

The `bin/rails routes` commands lists all defined routes in your application, including the URI Pattern and HTTP verb, as well as the Controller Action it maps to.

```bash
$ bin/rails routes
  Prefix  Verb  URI Pattern  Controller#Action
  books GET    /books(:format) books#index
  books POST   /books(:format) books#create
  ...
  ...
```

This can be useful for tracking down a routing issue, or simply getting an overview of the resources and routes that are part of a Rails application. You can also narrow down the output of the `routes` command like this:

```bash
# Only shows routes handled by the UsersController
bin/rails routes -c users

# Show routes handled by namespace Admin::UsersController
bin/rails routes -c admin/users

# Search by name, path, or controller/action with -g (or --grep)
bin/rails routes -g users
```

There is also an option, `bin/rails routes --expanded`, that displays even more information about each route, including the line number in your `config/routes.rb` where that route is defined.

TIP: In development mode, you can also access the same routes info by going to `http://localhost:3000/rails/info/routes`

### `bin/rails about`

The `bin/rails about` command displays information about your Rails application, such as Ruby, RubyGems, and Rails versions, database adapter, schema version, etc. It is useful when you need to ask for help or check if a security patch might affect you.

```bash
$ bin/rails about
About your application's environment
Rails version             8.1.0
Ruby version              3.2.0 (x86_64-linux)
RubyGems version          3.3.7
Rack version              3.0.8
JavaScript Runtime        Node.js (V8)
Middleware:               ActionDispatch::HostAuthorization, Rack::Sendfile, ...
Application root          /home/code/my_app
Environment               development
Database adapter          sqlite3
Database schema version   20250205173523
```

### `bin/rails initializers`

The `bin/rails initializers` command prints out all defined initializers in the order they are invoked by Rails:

```bash
$ bin/rails initializers
ActiveSupport::Railtie.active_support.deprecator
ActionDispatch::Railtie.action_dispatch.deprecator
ActiveModel::Railtie.active_model.deprecator
...
Booknotes::Application.set_routes_reloader_hook
Booknotes::Application.set_clear_dependencies_hook
Booknotes::Application.enable_yjit
```

This command can be useful when initializers depend on each other and the order in which they are run matter. Using this command, you can see what's run before/after and discover the relationship between initializers. Rails runs framework initializers first and then application ones defined in `config/initializers`.

### `bin/rails middleware`

The `bin/rails middleware` shows you the entire Rack middleware stack for your Rails application, in the exact order the middlewares are run for each request.

```bash
$ bin/rails middleware
use ActionDispatch::HostAuthorization
use Rack::Sendfile
use ActionDispatch::Static
use ActionDispatch::Executor
use ActionDispatch::ServerTiming
...
```

This can be useful to see which middleware Rails includes and which ones are added by gems (Warden::Manager from Devise) as well as for debugging and profiling.

### `bin/rails stats`

The `bin/rails stats` command is show you things like lines of code (LOC) and number of classes and methods for various compents in your applicaiton.

```bash
$ bin/rails stats
+----------------------+--------+--------+---------+---------+-----+-------+
| Name                 |  Lines |    LOC | Classes | Methods | M/C | LOC/M |
+----------------------+--------+--------+---------+---------+-----+-------+
| Controllers          |    309 |    247 |       7 |      37 |   5 |     4 |
| Helpers              |     10 |     10 |       0 |       0 |   0 |     0 |
| Jobs                 |      7 |      2 |       1 |       0 |   0 |     0 |
| Models               |     89 |     70 |       6 |       3 |   0 |    21 |
| Mailers              |     10 |     10 |       2 |       1 |   0 |     8 |
| Channels             |     16 |     14 |       1 |       2 |   2 |     5 |
| Views                |    622 |    501 |       0 |       1 |   0 |   499 |
| Stylesheets          |    584 |    495 |       0 |       0 |   0 |     0 |
| JavaScript           |     81 |     62 |       0 |       0 |   0 |     0 |
| Libraries            |      0 |      0 |       0 |       0 |   0 |     0 |
| Controller tests     |    117 |     75 |       4 |       9 |   2 |     6 |
| Helper tests         |      0 |      0 |       0 |       0 |   0 |     0 |
| Model tests          |     21 |      9 |       3 |       0 |   0 |     0 |
| Mailer tests         |      7 |      5 |       1 |       1 |   1 |     3 |
| Integration tests    |      0 |      0 |       0 |       0 |   0 |     0 |
| System tests         |     51 |     41 |       1 |       4 |   4 |     8 |
+----------------------+--------+--------+---------+---------+-----+-------+
| Total                |   1924 |   1541 |      26 |      58 |   2 |    24 |
+----------------------+--------+--------+---------+---------+-----+-------+
  Code LOC: 1411     Test LOC: 130     Code to Test Ratio: 1:0.1
```

### `bin/rails time:zones:all`

The`bin/rails time:zones:all` command is a Rake task that prints the complete list of time zones that Active Support knows about, along with their UTC offsets followed by the Rails timezone identifiers.

As an example, you can use `bin/rails time:zones:local` to see your system's timezone:

```bash
$ bin/rails time:zones:local

* UTC -06:00 *
Central America
Central Time (US & Canada)
Chihuahua
Guadalajara
Mexico City
Monterrey
Saskatchewan
```

This can be useful when setting `config.time_zone` in `config/application.rb`, you need an exact Rails time zone name and spelling(e.g., "Pacific Time (US & Canada)") or validating user input or debugging.

Managing Assets
---------------

The `bin/rails assets:` commands allow you to manage assets in the `app/assets` directory.

You can precompile the assets in `app/assets` using `bin/rails assets:precompile`, and remove older compiled assets using `bin/rails assets:clean`. The `assets:clean` command allows for rolling deploys that may still be linking to an old asset while the new assets are being built.

If you want to clear `public/assets` completely, you can use `bin/rails assets:clobber`.

Managing the Database
---------------------

The commands in this section, `bin/rails db:*`, are all under the `db:` namespace. They are about setting up databases, managing migrations, etc.

You can get a list of all commands (which are rake tasks) like this:

```bash
$ bin/rails -T db
bin/rails db:create              # Create the database from DATABASE_URL or
bin/rails db:drop                # Drop the database from DATABASE_URL or
bin/rails db:encryption:init     # Generate a set of keys for configuring
bin/rails db:environment:set     # Set the environment value for the database
bin/rails db:fixtures:load       # Load fixtures into the current environment's
bin/rails db:migrate             # Migrate the database (options: VERSION=x,
bin/rails db:migrate:down        # Run the "down" for a given migration VERSION
bin/rails db:migrate:redo        # Roll back the database one migration and
bin/rails db:migrate:status      # Display status of migrations
bin/rails db:migrate:up          # Run the "up" for a given migration VERSION
bin/rails db:prepare             # Run setup if database does not exist, or run
bin/rails db:reset               # Drop and recreate all databases from their
bin/rails db:rollback            # Roll the schema back to the previous version
bin/rails db:schema:cache:clear  # Clear a db/schema_cache.yml file
bin/rails db:schema:cache:dump   # Create a db/schema_cache.yml file
bin/rails db:schema:dump         # Create a database schema file (either db/
bin/rails db:schema:load         # Load a database schema file (either db/
bin/rails db:seed                # Load the seed data from db/seeds.rb
bin/rails db:seed:replant        # Truncate tables of each database for current
bin/rails db:setup               # Create all databases, load all schemas, and
bin/rails db:version             # Retrieve the current schema version number
bin/rails test:db                # Reset the database and run `bin/rails test`
```

TIP: You can also see the `db:` commands in the Rails [source code](activerecord/lib/active_record/railties/databases.rake).

### Database Setup

The `db:create` and `db:drop` commands create or delete the database for the current environment (or all environments with the `db:create:all`, `db:drop:all`)

The `db:seed` commands loads sample data from `db/seeds.rb` and the `db:seed:replant` command truncates tables of each database for current environment and then load the seed data.

The `db:setup` command create all databases, load all schemas, and initialize with the seed data (does not drop databases first, like the `db:reset` command below).

The `db:reset` command drops and recreates all databases from their schema for the current environment and loads the seed data. (so it's a combination of the above command).

### Migrations

The `bin/rails db:migrate` is a very commonly run commands and it migrates the database by running all new (not yet run) migrations.

The `db:migrate:up` command runs the "up" method and the `db:migrate:down` command run the "down" method for a given migration VERSION argument.

```bash
$ bin/rails db:migrate:down VERSION=VERSION=20250812120000
```

The `db:rollback` command rolls the schema back to the previous version (or you can specify steps with the `STEP=n` argument).

The `db:migrate:redo` command rolls back the database one migration and re-migrate up. It is a combination of the above two commands.

There is also a `db:migrate:status` command, which shows which migrations have been run and which are still pending:

```bash
$ bin/rails db:migrate:status
database: db/development.sqlite3

 Status   Migration ID    Migration Name
--------------------------------------------------
   up     20250101010101  Create users
   up     20250102020202  Add email to users
  down    20250812120000  Add age to users
```

NOTE: Please see the [Migration Guide](active_record_migrations.html) for explanation of concepts related database migrations.

### Schema Management

### Other Utility Commands

`bin/rails db:`

The most common commands of the `db:` rails namespace are `migrate` and `create`, and it will pay off to try out all of the migration rails commands (`up`, `down`, `redo`, `reset`). `bin/rails db:version` is useful when troubleshooting, telling you the current version of the database.

More information about migrations can be found in the [Migrations](active_record_migrations.html) guide.

### Switching to a Different Database Later

After creating a new Rails application, you have the option to switch to any
other supported database. For example, you might work with SQLite for a while and
then decide to switch to PostgreSQL. In this case, you only need to run:

```bash
$ rails db:system:change --to=postgresql
    conflict  config/database.yml
Overwrite config/database.yml? (enter "h" for help) [Ynaqdhm] Y
       force  config/database.yml
        gsub  Gemfile
        gsub  Gemfile
...
```

And then install the missing gems:

```bash
$ bundle install
...
```

Running Tests
-------------

### `bin/rails test`

INFO: A good description of unit testing in Rails is given in [A Guide to Testing Rails Applications](testing.html)

Rails comes with a test framework called minitest. Rails owes its stability to the use of tests. The commands available in the `test:` namespace help in running the different tests you will hopefully write.


Other Useful Commands
---------------------

### `bin/rails notes`

The `bin/rails notes` command searches through your code for comments beginning with a specific keyword. You can refer to `bin/rails notes --help` for information about usage.

By default, it will search in `app`, `config`, `db`, `lib`, and `test` directories for FIXME, OPTIMIZE, and TODO annotations in files with extension `.builder`, `.rb`, `.rake`, `.yml`, `.yaml`, `.ruby`, `.css`, `.js`, and `.erb`.

```bash
$ bin/rails notes
app/controllers/admin/users_controller.rb:
  * [ 20] [TODO] any other way to do this?
  * [132] [FIXME] high priority for next deploy

lib/school.rb:
  * [ 13] [OPTIMIZE] refactor this code to make it faster
```

#### Annotations

You can pass specific annotations by using the `-a` (or `--annotations`) option.
Note that annotations are case sensitive.

```bash
$ bin/rails notes --annotations FIXME RELEASE
app/controllers/admin/users_controller.rb:
  * [101] [RELEASE] We need to look at this before next release
  * [132] [FIXME] high priority for next deploy

lib/school.rb:
  * [ 17] [FIXME]
```

#### Add Tags

You can add more default tags to search for by using `config.annotations.register_tags`:

```ruby
config.annotations.register_tags("DEPRECATEME", "TESTME")
```

```bash
$ bin/rails notes
app/controllers/admin/users_controller.rb:
  * [ 20] [TODO] do A/B testing on this
  * [ 42] [TESTME] this needs more functional tests
  * [132] [DEPRECATEME] ensure this method is deprecated in next release
```

#### Add Directories

You can add more default directories to search from by using `config.annotations.register_directories`:

```ruby
config.annotations.register_directories("spec", "vendor")
```

#### Add File Extensions

You can add more default file extensions by using `config.annotations.register_extensions`:

```ruby
config.annotations.register_extensions("scss", "sass") { |annotation| /\/\/\s*(#{annotation}):?\s*(.*)$/ }
```

### `bin/rails tmp:`

The `Rails.root/tmp` directory is, like the *nix /tmp directory, the holding place for temporary files like process id files and cached actions.

The `tmp:` namespaced commands will help you clear and create the `Rails.root/tmp` directory:

* `bin/rails tmp:cache:clear` clears `tmp/cache`.
* `bin/rails tmp:sockets:clear` clears `tmp/sockets`.
* `bin/rails tmp:screenshots:clear` clears `tmp/screenshots`.
* `bin/rails tmp:clear` clears all cache, sockets, and screenshot files.
* `bin/rails tmp:create` creates tmp directories for cache, sockets, and pids.

###  `bin/rails secret` 

The `bin/rails secret` command generates a cryptographically secure random string for use as a secret key in your Rails application.

```bash
$ bin/rails secret
4d39f92a661b5afea8c201b0b5d797cdd3dcf8ae41a875add6ca51489b1fbbf2852a666660d32c0a09f8df863b71073ccbf7f6534162b0a690c45fd278620a63
```

It can be useful for setting the secret key in your application's `config/credentials.yml.enc` file.

Custom Rake Tasks
-----------------

Custom rake tasks have a `.rake` extension and are placed in
`Rails.root/lib/tasks`. You can create these custom rake tasks with the
`bin/rails generate task` command.

```ruby
desc "I am short, but comprehensive description for my cool task"
task task_name: [:prerequisite_task, :another_task_we_depend_on] do
  # All your magic here
  # Any valid Ruby code is allowed
end
```

To pass arguments to your custom rake task:

```ruby
task :task_name, [:arg_1] => [:prerequisite_1, :prerequisite_2] do |task, args|
  argument_1 = args.arg_1
end
```

You can group tasks by placing them in namespaces:

```ruby
namespace :db do
  desc "This task does nothing"
  task :nothing do
    # Seriously, nothing
  end
end
```

Invocation of the tasks will look like:

```bash
$ bin/rails task_name
$ bin/rails "task_name[value 1]" # entire argument string should be quoted
$ bin/rails "task_name[value 1,value2,value3]" # separate multiple args with a comma
$ bin/rails db:nothing
```

If you need to interact with your application models, perform database queries, and so on, your task should depend on the `environment` task, which will load your application code.

```ruby
task task_that_requires_app_code: [:environment] do
  User.create!
end
```
