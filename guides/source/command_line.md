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

The Rails model generator command has a very detailed description that is worth perusing. We can see the basic usage like this: 

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

NOTE: For a list of available field types for the `type` parameter, refer to the [API documentation](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_column) for the add_column method for the `SchemaStatements` module.

### Generating Scaffolds

But instead of generating a model directly (which we'll be doing later), let's set up a scaffold. A **scaffold** in Rails is a full set of model, database migration for that model, controller to manipulate it, views to view and manipulate the data, and a test suite for each of the above.

We will set up a simple resource called "HighScore" that will keep track of our highest score on video games we play.

```bash
$ bin/rails generate scaffold HighScore game:string score:integer
    invoke  active_record
    create    db/migrate/20190416145729_create_high_scores.rb
    create    app/models/high_score.rb
    invoke    test_unit
    create      test/models/high_score_test.rb
    create      test/fixtures/high_scores.yml
    invoke  resource_route
     route    resources :high_scores
    invoke  scaffold_controller
    create    app/controllers/high_scores_controller.rb
    invoke    erb
    create      app/views/high_scores
    create      app/views/high_scores/index.html.erb
    create      app/views/high_scores/edit.html.erb
    create      app/views/high_scores/show.html.erb
    create      app/views/high_scores/new.html.erb
    create      app/views/high_scores/_form.html.erb
    invoke    test_unit
    create      test/controllers/high_scores_controller_test.rb
    create      test/system/high_scores_test.rb
    invoke    helper
    create      app/helpers/high_scores_helper.rb
    invoke      test_unit
    invoke    jbuilder
    create      app/views/high_scores/index.json.jbuilder
    create      app/views/high_scores/show.json.jbuilder
    create      app/views/high_scores/_high_score.json.jbuilder
```

The generator creates the model, views, controller, **resource** route, and database migration (which creates the `high_scores` table) for HighScore. And it adds tests for those.

The migration requires that we **migrate**, that is, run some Ruby code (the `20190416145729_create_high_scores.rb` file from the above output) to modify the schema of our database. Which database? The SQLite3 database that Rails will create for you when we run the `bin/rails db:migrate` command. We'll talk more about that command below.

```bash
$ bin/rails db:migrate
==  CreateHighScores: migrating ===============================================
-- create_table(:high_scores)
   -> 0.0017s
==  CreateHighScores: migrated (0.0019s) ======================================
```

INFO: Let's talk about unit tests. Unit tests are code that tests and makes
assertions about code. In unit testing, we take a little part of code, say a
method of a model, and test its inputs and outputs. Unit tests are your friend.
The sooner you make peace with the fact that your quality of life will
drastically increase when you unit test your code, the better. Seriously. Please
visit [the testing guide](testing.html) for an in-depth look at unit testing.

Let's see the interface Rails created for us.

```bash
$ bin/rails server
```

Go to your browser and open [http://localhost:3000/high_scores](http://localhost:3000/high_scores), now we can create new high scores (55,160 on Space Invaders!)

### Undoing Code Generation with `bin/rails destroy`

Think of `destroy` as the opposite of `generate`. It'll figure out what generate did, and undo it.

INFO: You can also use the alias "d" to invoke the destroy command: `bin/rails d`.

```bash
$ bin/rails generate model Oops
      invoke  active_record
      create    db/migrate/20120528062523_create_oops.rb
      create    app/models/oops.rb
      invoke    test_unit
      create      test/models/oops_test.rb
      create      test/fixtures/oops.yml
```

```bash
$ bin/rails destroy model Oops
      invoke  active_record
      remove    db/migrate/20120528062523_create_oops.rb
      remove    app/models/oops.rb
      invoke    test_unit
      remove      test/models/oops_test.rb
      remove      test/fixtures/oops.yml
```

Inspecting and Exploring a Rails Application
--------------------------------------------

### `bin/rails console`

The `console` command lets you interact with your Rails application from the command line. On the underside, `bin/rails console` uses IRB, so if you've ever used it, you'll be right at home. This is useful for testing out quick ideas with code and changing data server-side without touching the website.

INFO: You can also use the alias "c" to invoke the console: `bin/rails c`.

You can specify the environment in which the `console` command should operate.

```bash
$ bin/rails console -e staging
```

If you wish to test out some code without changing any data, you can do that by invoking `bin/rails console --sandbox`.

```bash
$ bin/rails console --sandbox
Loading development environment in sandbox (Rails 8.1.0)
Any modifications you make will be rolled back on exit
irb(main):001:0>
```

#### The `app` and `helper` Objects

Inside the `bin/rails console` you have access to the `app` and `helper` instances.

With the `app` method you can access named route helpers, as well as do requests.

```irb
irb> app.root_path
=> "/"

irb> app.get _
Started GET "/" for 127.0.0.1 at 2014-06-19 10:41:57 -0300
...
```

With the `helper` method it is possible to access Rails and your application's helpers.

```irb
irb> helper.time_ago_in_words 30.days.ago
=> "about 1 month"

irb> helper.my_custom_helper
=> "my custom helper"
```

### `bin/rails dbconsole`

`bin/rails dbconsole` figures out which database you're using and drops you into whichever command line interface you would use with it (and figures out the command line parameters to give to it, too!). It supports MySQL (including MariaDB), PostgreSQL, and SQLite3.

INFO: You can also use the alias "db" to invoke the dbconsole: `bin/rails db`.

If you are using multiple databases, `bin/rails dbconsole` will connect to the primary database by default. You can specify which database to connect to using `--database` or `--db`:

```bash
$ bin/rails dbconsole --database=animals
```

### `bin/rails runner`

`runner` runs Ruby code in the context of the Rails application non-interactively, without having to open Rails `console`. For instance:

```bash
$ bin/rails runner "Model.long_running_method"
```

INFO: You can also use the alias "r" to invoke the runner: `bin/rails r`.

You can specify the environment in which the `runner` command should operate using the `-e` switch.

```bash
$ bin/rails runner -e staging "Model.long_running_method"
```

You can even execute ruby code written in a file with runner.

```bash
$ bin/rails runner lib/code_to_be_run.rb
```

By default, `bin/rails runner` scripts are automatically wrapped with the Rails Executor, which helps report uncaught exceptions for tasks like cron jobs.

Therefore, executing `bin/rails runner lib/long_running_scripts.rb` is functionally equivalent to the following:

```ruby
Rails.application.executor.wrap do
  # executes code inside lib/long_running_scripts.rb
end
```

You can opt out of this behavior by using the `--skip-executor` option.

```bash
$ bin/rails runner --skip-executor lib/long_running_script.rb
```
### `bin/rails about`

`bin/rails about` gives information about version numbers for Ruby, RubyGems, Rails, the Rails subcomponents, your application's folder, the current Rails environment name, your app's database adapter, and schema version. It is useful when you need to ask for help, check if a security patch might affect you, or when you need some stats for an existing Rails installation.

```bash
$ bin/rails about
About your application's environment
Rails version             8.1.0
Ruby version              3.2.0 (x86_64-linux)
RubyGems version          3.3.7
Rack version              3.0.8
JavaScript Runtime        Node.js (V8)
Middleware:               ActionDispatch::HostAuthorization, Rack::Sendfile, ActionDispatch::Static, ActionDispatch::Executor, ActionDispatch::ServerTiming, ActiveSupport::Cache::Strategy::LocalCache::Middleware, Rack::Runtime, Rack::MethodOverride, ActionDispatch::RequestId, ActionDispatch::RemoteIp, Sprockets::Rails::QuietAssets, Rails::Rack::Logger, ActionDispatch::ShowExceptions, WebConsole::Middleware, ActionDispatch::DebugExceptions, ActionDispatch::ActionableExceptions, ActionDispatch::Reloader, ActionDispatch::Callbacks, ActiveRecord::Migration::CheckPending, ActionDispatch::Cookies, ActionDispatch::Session::CookieStore, ActionDispatch::Flash, ActionDispatch::ContentSecurityPolicy::Middleware, ActionDispatch::PermissionsPolicy::Middleware, Rack::Head, Rack::ConditionalGet, Rack::ETag, Rack::TempfileReaper
Application root          /home/foobar/my_app
Environment               development
Database adapter          sqlite3
Database schema version   20180205173523
```

Managing Assets
---------------

### `bin/rails assets:`

You can precompile the assets in `app/assets` using `bin/rails assets:precompile`, and remove older compiled assets using `bin/rails assets:clean`. The `assets:clean` command allows for rolling deploys that may still be linking to an old asset while the new assets are being built.

If you want to clear `public/assets` completely, you can use `bin/rails assets:clobber`.

Managing the Database
---------------------

### `bin/rails db:`

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

Other Useful Commands
---------------------

### `bin/rails notes`

`bin/rails notes` searches through your code for comments beginning with a specific keyword. You can refer to `bin/rails notes --help` for information about usage.

By default, it will search in `app`, `config`, `db`, `lib`, and `test` directories for FIXME, OPTIMIZE, and TODO annotations in files with extension `.builder`, `.rb`, `.rake`, `.yml`, `.yaml`, `.ruby`, `.css`, `.js`, and `.erb`.

```bash
$ bin/rails notes
app/controllers/admin/users_controller.rb:
  * [ 20] [TODO] any other way to do this?
  * [132] [FIXME] high priority for next deploy

lib/school.rb:
  * [ 13] [OPTIMIZE] refactor this code to make it faster
  * [ 17] [FIXME]
```

#### Annotations

You can pass specific annotations by using the `--annotations` argument. By default, it will search for FIXME, OPTIMIZE, and TODO.
Note that annotations are case sensitive.

```bash
$ bin/rails notes --annotations FIXME RELEASE
app/controllers/admin/users_controller.rb:
  * [101] [RELEASE] We need to look at this before next release
  * [132] [FIXME] high priority for next deploy

lib/school.rb:
  * [ 17] [FIXME]
```

#### Tags

You can add more default tags to search for by using `config.annotations.register_tags`. It receives a list of tags.

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

#### Directories

You can add more default directories to search from by using `config.annotations.register_directories`. It receives a list of directory names.

```ruby
config.annotations.register_directories("spec", "vendor")
```

```bash
$ bin/rails notes
app/controllers/admin/users_controller.rb:
  * [ 20] [TODO] any other way to do this?
  * [132] [FIXME] high priority for next deploy

lib/school.rb:
  * [ 13] [OPTIMIZE] Refactor this code to make it faster
  * [ 17] [FIXME]

spec/models/user_spec.rb:
  * [122] [TODO] Verify the user that has a subscription works

vendor/tools.rb:
  * [ 56] [TODO] Get rid of this dependency
```

#### Extensions

You can add more default file extensions to search from by using `config.annotations.register_extensions`. It receives a list of extensions with its corresponding regex to match it up.

```ruby
config.annotations.register_extensions("scss", "sass") { |annotation| /\/\/\s*(#{annotation}):?\s*(.*)$/ }
```

```bash
$ bin/rails notes
app/controllers/admin/users_controller.rb:
  * [ 20] [TODO] any other way to do this?
  * [132] [FIXME] high priority for next deploy

app/assets/stylesheets/application.css.sass:
  * [ 34] [TODO] Use pseudo element for this class

app/assets/stylesheets/application.css.scss:
  * [  1] [TODO] Split into multiple components

lib/school.rb:
  * [ 13] [OPTIMIZE] Refactor this code to make it faster
  * [ 17] [FIXME]

spec/models/user_spec.rb:
  * [122] [TODO] Verify the user that has a subscription works

vendor/tools.rb:
  * [ 56] [TODO] Get rid of this dependency
```

### `bin/rails routes`

`bin/rails routes` will list all of your defined routes, which is useful for tracking down routing problems in your app, or giving you a good overview of the URLs in an app you're trying to get familiar with.

### `bin/rails test`

INFO: A good description of unit testing in Rails is given in [A Guide to Testing Rails Applications](testing.html)

Rails comes with a test framework called minitest. Rails owes its stability to the use of tests. The commands available in the `test:` namespace help in running the different tests you will hopefully write.

### `bin/rails tmp:`

The `Rails.root/tmp` directory is, like the *nix /tmp directory, the holding place for temporary files like process id files and cached actions.

The `tmp:` namespaced commands will help you clear and create the `Rails.root/tmp` directory:

* `bin/rails tmp:cache:clear` clears `tmp/cache`.
* `bin/rails tmp:sockets:clear` clears `tmp/sockets`.
* `bin/rails tmp:screenshots:clear` clears `tmp/screenshots`.
* `bin/rails tmp:clear` clears all cache, sockets, and screenshot files.
* `bin/rails tmp:create` creates tmp directories for cache, sockets, and pids.

### Miscellaneous

* `bin/rails initializers` prints out all defined initializers in the order they are invoked by Rails.
* `bin/rails middleware` lists Rack middleware stack enabled for your app.
* `bin/rails stats` is great for looking at statistics on your code, displaying things like KLOCs (thousands of lines of code) and your code to test ratio.
* `bin/rails secret` will give you a pseudo-random key to use for your session secret.
* `bin/rails time:zones:all` lists all the timezones Rails knows about.
* `bin/rails boot` boots the application and exits.

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
