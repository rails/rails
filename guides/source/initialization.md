**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON
<https://guides.rubyonrails.org>.**

The Rails Initialization Process
================================

This guide explains the Rails initialization process. It is an in-depth guide
that walks through some internal method calls. It is recommended for developers
interested in exploring Rails source code.

After reading this guide, you will know:

* How `bin/rails server` command works.
* The timeline of Rails' initialization sequence.
* Where different files are required by the boot sequence.
* How to use Load Hooks and Initialization Hooks.

--------------------------------------------------------------------------------

What happens when you execute the `bin/rails server` command in your Rails
application? How is it that all the components of the Rails framework (e.g.
Active Record, Active Job, etc.) are all configured and available to use in the
context of your Rails application?

This guide walks through what's involved in booting up the entire Ruby
on Rails stack and what's available in what order. It also explains how you can
execute custom code by hooking into the initialization process. Lastly, this
guide briefly covers Railties and Engines as they relate to the initialization
process.

NOTE: Paths in this guide are relative to the root of a Rails application unless
otherwise specified.

Overview
--------

At a high level, the Rails initialization process has two parts: 

* Booting the framework.
* Starting the server.

The booting part happens with majority of the `bin/rails` commands but only
`bin/rails server` also starts the server. For example, `bin/rails console`
boots the application but does *not* start the server. Rake tasks, such as
`bin/rails db:migrate` also boot the application.

The main files involved in Rails initialization are: `config/boot.rb`, `config/environment.rb`, and `config/application.rb`. All three files are generated in a new Rails application. The first two files you usually don't open or modify, the last familiar file is where your application is defined and configured.

Before we get to the `bin/rails server` command, let's talk about the `config/environment.rb`. This file is the public interface for booting a Rails application. For example, if you have this line in a Ruby script, it will boot the Rails application (which is what the `config.ru` file has, as we'll see in a [later section](#loading-configenvironmentrb-from-configru):

```ruby
require "config/environment"
```

For Rake tasks, they can do the same by depending on the `:environment` task provided by Rails.

TODO: when are different things available. Rails.env, Rails.root, Rails.logger, etc.

┌──────────────────────┐
│ Rails.application    │  <-- defines Rails.env, Rails.root
└──────────────────────┘
        ↓
┌──────────────────────┐
│ Framework config     │  <-- Rails.configuration, public_path, autoloaders
└──────────────────────┘
        ↓
┌──────────────────────┐
│ Built-in initializers│  <-- logger, cache, secrets, credentials
└──────────────────────┘
        ↓
┌──────────────────────┐
│ Custom initializers  │  <-- your config/initializers/*.rb
└──────────────────────┘
        ↓
┌──────────────────────┐
│ After initialize     │  <-- routing, encryptors, reloader
└──────────────────────┘

TIP: You can follow along by browsing the Rails [source
code](https://github.com/rails/rails) and use the `t` key binding to open file
finder inside GitHub and find files quickly.

The sections below cover specific lines in the main files involved when running the `bin/rails server` command in this order:

* `bin/rails` script
* `require_relative "boot"` in `bin/rails` script
*  Requiring `application.rb` in `ServerCommand#perform`
* `require "rails/all"` in `config/application.rb`
* `Rails.application.initialize!` back in `config/environment.rb`

These sections will focus on the "booting" part of the initialization process. We cover "starting the server" part in the last section.

The `bin/rails` Script
----------------------

Let's start with what happens first when we run `bin/rails server` command.

The `bin/rails` Ruby script is in the `bin` directory of your Rails application.
This file contains only three lines:

```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require "rails/commands"
```

The `APP_PATH` constant will be used later in `rails/commands`. The second line
requires the `boot.rb` file in the `config` directory.

### Requiring "config/boot" from "bin/rails" Script

The `config/boot.rb` file is responsible for loading Bundler and setting it up.
The `boot.rb` file contains:

```ruby
# config/boot.rb
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
```

In a standard Rails application, there is a `Gemfile` that declares all of the
dependencies for the application. The first line sets the environment
variable, `ENV['BUNDLE_GEMFILE']`, to the location of this `Gemfile`.

The second line, `require "bundler/setup"`, makes all gems in your `Gemfile` available to your app. Behind the scenes, this parses your `Gemfile.lock`, resolves the dependencies, and sets up `$LOAD_PATH` with the correct gem versions.

Once loading `boot.rb` has finished, the next line in the `bin/rails`
script is to require `rails/commands`. Let's look at what that does next.

### Requiring `application.rb` in `ServerCommand#perform`

The line `require "rails/commands"` in `bin/rails` script loads the Rails command dispatcher. It parses your CLI arguments and routes the command to the correct sub-command like `server`, `console`, `generate`, etc. It's the entry point to all command-line interactions with a Rails app.

In the case of `bin/rails server`, it'll be passed over to the `perform` method in the `Rails::Command::ServerCommand` class:

```ruby
# railties/lib/rails/commands/server/server_command.rb

module Rails
  module Command
    class ServerCommand < Base # :nodoc:
     def perform
        set_application_directory!
        prepare_restart

        Rails::Server.new(server_options).tap do |server|
          # Require application after server sets environment to propagate
          # the --environment option.
          require APP_PATH
          Dir.chdir(Rails.application.root)

          if server.serveable?
            print_boot_information(server.server, server.served_url)
            after_stop_callback = -> { say "Exiting" unless options[:daemon] }
            server.start(after_stop_callback)
          else
            say rack_server_suggestion(options[:using])
          end
        end
      end
    end
  end
end
```

The main line of interest in the above `perform` method is `require APP_PATH`. Recall that we initialized this constant in the `bin/rails` Ruby script, and it points to the `application.rb` file in the `config` directory.

NOTE: Zooming out, so far we have been following what happens in the `bin/rails` ruby script. The main line is when `config/boot.rb` is required, which sets up the Gems. Then, the `rails/commands` part figures out which command (e.g. `console`, `server`, `runner`) and takes appropriate action. All of this happens before Rails itself is even loaded.

Now, let's jump out of `bin/rails` and follow the path where `config/application.rb` is required. This is the next important file in the Rails initialization process.

Requiring `config/application`
----------------------------

When `require APP_PATH` is executed, `config/application.rb` is loaded. This
file is included with new Rails applications and it's available for you to
update based on your application needs. The default `config/application.rb` looks like this:

```ruby
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MyAmazingApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
```

This is where **your** application class is defined as a subclass of [`Rails::Application`](https://github.com/rails/rails/blob/36bd50c82b46046c9f352e06fa552221586028d8/railties/lib/rails/application.rb#L60). When the extend statement, `class Application < Rails::Application`, is executed, an `inherited` hook from `Rails::Application` is run. After the `inherited` hook is run, the following is true:

* `Rails.application` is available
* `Rails.root` is available
* `Rails.configuration` is available
* `Rails.autoloaders.*` is configured
* `lib` is prepended to `$LOAD_PATH`
* `:before_configuration` hooks are run

The first line `require_relative "boot"` in `application.rb` does nothing in this sequence, coming from `bin/rails` script. This is because `boot.rb` is already loaded and Ruby's `require` does not reload it.

But we do the important `require "rails/all"` line. Next, let's what that does.

### `require "rails/all"`

This file is responsible for requiring all the individual components of the Rails framework:

```ruby
# railties/lib/rails/all.rb
require "rails"

%w(
  active_record/railtie
  active_storage/engine
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  action_mailbox/engine
  action_text/engine
  rails/test_unit/railtie
).each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end
```

Common Rails functionality, such as X Y and Z is being configured and defined here. Specifically, the `require rails/all` call is loading all the Railties and Engines from various Rails framework components (such as `active_record/railtie` and `action_mailbox/engine`). As a side effect of all those requires, many initializers from those classes are registered. The initializers are not run yet, but loaded and ready. We come back to this in the [`Rails.application.initialize!`](#railsapplicationinitialize) section below.

We also go into what [Railties](#railties) and [Engines](#engines) are and how they facilitate initializing and configuring framework components.

At this point, we're done with loading `config/application.rb` file (that we started from [ServerCommand#perform](#requiring-applicationrb-in-servercommandperform) above). Our Rails application is defined and configured but *not initialized* yet. The initialization happens from `config/environment.rb`. Let's see how we get to that key file next.

Loading `config/environment.rb` from `config.ru`
-----------------------------------------------

After `ServerCommand#perform` in `server_command.rb` file, we come to the [`start`](https://github.com/rails/rails/blob/36bd50c82b46046c9f352e06fa552221586028d8/railties/lib/rails/commands/server/server_command.rb#L32) method in that class. That method calls the `Rackup::Server#start` method (via `super()`), which is what loads the `config.ru` file.

And voila, the `require` line for `config/environment.rb` is the first line in `config.ru`:

```ruby
# config.ru
# This file is used by Rack-based servers to start the application.
require_relative "config/environment"

run Rails.application
Rails.application.load_server
```

The `config/environment.rb` file, generated in all new Rails applications, contains this:

```ruby
# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!
```

This file begins with requiring `config/application.rb`, but coming from the `bin/rails` Ruby script, we have already required `application.rb`. Therefore, this require will have no effect (as `require` in Ruby is idempotent).

Finally, with the second line, we get to the most important method of the initialization process. A number of things have happened by this point in the `bin/rails server` journey but we have barely done any actual initialization. Now we get to the fun part in the next section!

`Rails.application.initialize!`
------------------------------

The main idea behind initialization is to allow components to register code to be executed during the Rails booting process. This is done with Railties and Engines, which allow components to register initializers. Here is an overview of all of the things that happen when you call `initialize!`:

In order to understand the `initialize!` call, we need to take brief detour and cover Railties and Engines, then we'll come back to the `initialize!` method.

Here is a preview of everything that happens during the `initialize!` call:
TODO: update this sketch
```
Rails.application.initialize!
│
├── run_initializers
│   ├── Load railties (ActiveRecord, ActionMailer, etc.)
│   ├── Load app and engine initializers
│   └── Load config/initializers/*.rb
│
├── Build middleware stack
├── Prepare app classes
└── Run after_initialize hooks
```

### Railties

A Railtie is simply a class that extends `Rails::Railtie`. In practice, it allows different parts of the framework (or third-party gems) to integrate with Rails by providing hooks for configuration, initialization, and runtime execution.

For example, Railtie allows a component like ActiveRecord to be responsible for it's own initialization. Active Record is a library that can be used outside of the Rails framework. But by defining a `Railtie` class within the `ActiveRecord` module, the Active Record component is able to hook into Rails.

It does this by registering blocks of code to run during Rails initialization using the `initializer "name" do ... end` method provided by the `Rails::Railtie` class.

Here's an example of an initializer that is registered by the `ActiveRecord::Railtie` class:

```ruby
module ActiveRecord
  class Railtie < Rails::Railtie
    # ...
    initializer "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        self.configurations = Rails.application.config.database_configuration

        establish_connection
      end
    end
  end
end
```

This initializer configures the database and establishes a connection with the database during the boot process.

Here's another example of an initializer from `ActiveJob::Railtie`:

```ruby
module ActiveJob
  class Railtie < Rails::Railtie
    initializer "active_job.custom_serializers" do |app|
      config.after_initialize do
        custom_serializers = app.config.active_job.custom_serializers
        ActiveJob::Serializers.add_serializers custom_serializers
      end
    end
  end
end
```

There are dozens of initializers registered for each sub-component. These initializers are stored in the `@initializers` array and will be executed when `Rails.application.initialize!` is called. During the `initialize!` call, the initializers are executed in the order in which they are registered. That call also includes running custom initializers that are defined in the `config/initializers` directory of your application.

### Engines

A Rails Engine is a subclass of `Rails::Railtie`. Engines can also hook into a
Rails applications (as they are Railties) but they are also a mini Rails
applications. Engines can have models, views, controllers as well as
`config/initializers` and `config/routes.rb` A Rails application ships with a
bunch of Engines, such as `ActiveStorage::Engine`, `SolidCache::Engine`,
`Turbo::Engine`.

Your Rails application is a subclass of Rails Engine.

```ruby
# config/application.rb

class Rails::Application < Rails::Engine

end
```

So a Rails application is an Engine, which is a Railtie. But they are not exactly the same, there are some differences. For example, a Rails application has autoloaders, an Engine does not have autoloaders.

TIP: You can see a list of all initializer registered for an applicaiton with `bin/rails initializers` command.

So now we know what role Railties and Engines play in the Rails initialization process. Back to the the `initialize!` method that is called from `config/environment.rb`.

### The `initialize!` call

The `initialize!` method looks like this:

```ruby
# railties/lib/rails/application.rb

def initialize!(group = :default) # :nodoc:
  raise "Application has been already initialized." if @initialized
  run_initializers(group, self)
  @initialized = true
  self
end
```

The `run_initializers` method looks like this:

```ruby
# railties/lib/rails/initializable.rb

def run_initializers(group = :default, *args)
  return if instance_variable_defined?(:@ran)
  initializers.tsort_each do |initializer|
    initializer.run(*args) if initializer.belongs_to?(group)
  end
  @ran = true
end
```

The `run_initializers` code runs all of the initializers registered by the Engine and Railtie classes, as well as other groups of initializers (as defined in `Boostrap` and `Finisher`):

```ruby
# railties/lib/rails/application.rb

def initializers
	Bootstrap.initializers_for(self) +
	railties_initializers(super) +
	Finisher.initializers_for(self)
end
```

The `bootstrap` initializers prepare the application (like initializing the
logger) while the `finisher` initializers (like building the middleware stack)
are run last. The `railtie` initializers are the initializers which have been
defined on the `Rails::Application` itself and are run between the `bootstrap`
and `finisher`.

TODO remove this and add a note about when/how config/initializers are loaded.
NOTE: Do not confuse Railtie initializers overall with the
[load_config_initializers](configuring.html#using-initializer-files) initializer
instance or its associated config initializers in `config/initializers`.

At the end of the `Rails.application.initialize!` call the Rails framework and application are loaded and initialized! (We're also at the end of the `config/environment.rb` file). Now all that is left to do is start the server.

Before that, let's see how you can add custom code to the initialization process.

Hooking Into the Initialization Process
---------------------------------------

### Lazy Load Hooks

The purpose of [Lazy Load Hooks](https://api.rubyonrails.org/v8.0/classes/ActiveSupport/LazyLoadHooks.html) is to do something when the application loads certain parts of the Rails framework. For example:

```ruby
# config/initializers/my_active_record_extension.rb
ActiveSupport.on_load(:active_record) do
  include MyActiveRecordExtension
end
```

The Rails framework is responsible for loading the components and when a specific component (e.g. Active Record above) is done loading, you can choose to be notified with the `ActiveSupport.on_load` helper.

Registering a hook that has already run results in that hook executing immediately. This allows hooks to be nested for code that relies on multiple lazily loaded components:

```ruby
initializer "action_text.renderer" do
  ActiveSupport.on_load(:action_controller_base) do
    ActiveSupport.on_load(:action_text_content) do
      self.default_renderer = Class.new(ActionController::Base).renderer
    end
  end
end
```

TIP: You can search the Rails source code for `ActiveSupport.run_load_hooks` for all the components that support lazy load hooks.

### Initialization Hooks

Initialization Hooks are things like `after_initialize` and `before_initialize`. You specify them in your application's `configure` block inside your environment specific configuration file (e.g. development.rb):

```ruby
Rails.application.configure do
  config.after_initialize do
    puts "Rails has finished initializing!"
  end
end
```

Some other Initialization Hooks are:

* `config.before_configuration`
* `config.before_initialize`
* `config.to_prepare`
* `config.before_eager_load`
* `config.after_routes_loaded`

Now that we have covered hooks and we have finished booting the application, we're ready to talk about starting the server. After this
is done we go back to `Rackup::Server`.

Starting the Server
-------------------

`Rails::Server#start` calls `super()` which is `Rackup::Server#start`, which loads `config.ru` which requires `config/environment.rb`. And we're back!

```ruby
# server_command.rb
    def start(after_stop_callback = nil)
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super()
    ensure
      after_stop_callback.call if after_stop_callback
    end
```

### Rack: lib/rack/server.rb

Last time we left when the `app` method was being defined:

```ruby
module Rackup
  class Server
    def app
      @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
    end

    # ...

    private
      def build_app_and_options_from_config
        if !::File.exist? options[:config]
          abort "configuration #{options[:config]} not found"
        end

        Rack::Builder.parse_file(self.options[:config])
      end

      def build_app_from_string
        Rack::Builder.new_from_string(self.options[:builder])
      end
  end
end
```

At this point `app` is the Rails app itself (a middleware), and what happens
next is Rack will call all the provided middlewares:

```ruby
module Rackup
  class Server
    private
      def build_app(app)
        middleware[options[:environment]].reverse_each do |middleware|
          middleware = middleware.call(self) if middleware.respond_to?(:call)
          next unless middleware
          klass, *args = middleware
          app = klass.new(app, *args)
        end
        app
      end
  end
end
```

Remember, `build_app` was called (by `wrapped_app`) in the last line of
[`Rackup::Server#start`](https://www.rubydoc.info/gems/rack/1.5.5/Rack/Server#start-instance_method). Here's how it looked like when we left:

```ruby
server.run(wrapped_app, **options, &block)
```

At this point, the implementation of `server.run` will depend on the server
you're using. For example, if you were using Puma, here's what the `run` method
would look like:

```ruby
module Rack
  module Handler
    module Puma
      # ...
      def self.run(app, options = {})
        conf = self.config(app, options)

        log_writer = options.delete(:Silent) ? ::Puma::LogWriter.strings : ::Puma::LogWriter.stdio

        launcher = ::Puma::Launcher.new(conf, log_writer: log_writer, events: @events)

        yield launcher if block_given?
        begin
          launcher.run
        rescue Interrupt
          puts "* Gracefully stopping, waiting for requests to finish"
          launcher.stop
          puts "* Goodbye!"
        end
      end
      # ...
    end
  end
end
```

We won't dig into the server configuration itself, but this is the last piece of
our journey in the Rails initialization process with the `bin/rails server`  command.

This high level overview will help you understand when your code is executed and
how. If you still want to know more, the Rails source code is the best place to
go next.


**********OLD VERSION**********

The Rails Initialization Process
================================

This guide explains the Rails server initialization process. It is an extremely
in-depth guide and walks through internal method calls. It is recommended for
developers interested in exploring Rails source code.

After reading this guide, you will know:

* How to use `bin/rails server`.
* The timeline of Rails' initialization sequence.
* Where different files are required by the boot sequence.
* How the Rails::Server interface is defined and used.

--------------------------------------------------------------------------------

For this guide, we will be focusing on what happens when you execute `bin/rails
server` to boot your app. This guide goes through every method call that is
required to boot up the Ruby on Rails stack for a default Rails application,
explaining each part in detail along the way.

NOTE: Paths in this guide are relative to the root of a Rails application unless
otherwise specified.

TIP: If you want to follow along while browsing the Rails [source
code](https://github.com/rails/rails), we recommend that you use the `t` key
binding to open the file finder inside GitHub and find files quickly.

Launch!
-------

Let's start to boot and initialize the app. A Rails application is usually
started by running `bin/rails server` or `bin/rails console`.

### `bin/rails`

This file is as follows:

```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require "rails/commands"
```

The `APP_PATH` constant will be used later in `rails/commands`. The
`config/boot` file referenced here is the `config/boot.rb` file in our
application which is responsible for loading Bundler and setting it up.

### `config/boot.rb`

`config/boot.rb` contains:

```ruby
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
```

In a standard Rails application, there's a `Gemfile` which declares all
dependencies of the application. The `config/boot.rb` file sets
`ENV['BUNDLE_GEMFILE']` to the location of this `Gemfile`. If the `Gemfile`
exists, then `bundler/setup` is required. The require is used by Bundler to
configure the load path for your Gemfile's dependencies.

### `rails/commands.rb`

Once `config/boot.rb` has finished, the next file that is required is
`rails/commands`, which helps in expanding aliases. In the current case, the
`ARGV` array simply contains `server` which will be passed over:

```ruby
require "rails/command"

aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner",
  "t"  => "test"
}

command = ARGV.shift
command = aliases[command] || command

Rails::Command.invoke command, ARGV
```

If we had used `s` rather than `server`, Rails would have used the `aliases`
defined here to find the matching command.

### `rails/command.rb`

When one types a Rails command, `invoke` tries to lookup a command for the given
namespace and executes the command if found.

If Rails doesn't recognize the command, it hands the reins over to Rake to run a
task of the same name.

As shown, `Rails::Command` displays the help output automatically if the
`namespace` is empty.

```ruby
module Rails
  module Command
    class << self
      def invoke(full_namespace, args = [], **config)
        args = ["--help"] if rails_new_with_no_path?(args)

        full_namespace = full_namespace.to_s
        namespace, command_name = split_namespace(full_namespace)
        command = find_by_namespace(namespace, command_name)

        with_argv(args) do
          if command && command.all_commands[command_name]
            command.perform(command_name, args, config)
          else
            invoke_rake(full_namespace, args, config)
          end
        end
      rescue UnrecognizedCommandError => error
        if error.name == full_namespace && command && command_name == full_namespace
          command.perform("help", [], config)
        else
          puts error.detailed_message
        end
        exit(1)
      end
    end
  end
end
```

With the `server` command, Rails will further run the following code:

```ruby
module Rails
  module Command
    class ServerCommand < Base # :nodoc:
     def perform
        set_application_directory!
        prepare_restart

        Rails::Server.new(server_options).tap do |server|
          # Require application after server sets environment to propagate
          # the --environment option.
          require APP_PATH
          Dir.chdir(Rails.application.root)

          if server.serveable?
            print_boot_information(server.server, server.served_url)
            after_stop_callback = -> { say "Exiting" unless options[:daemon] }
            server.start(after_stop_callback)
          else
            say rack_server_suggestion(options[:using])
          end
        end
      end
    end
  end
end
```

This file will change into the Rails root directory (a path two directories up
from `APP_PATH` which points at `config/application.rb`), but only if the
`config.ru` file isn't found. This then starts up the `Rails::Server` class.

### `actionpack/lib/action_dispatch.rb`

Action Dispatch is the routing component of the Rails framework. It adds
functionality like routing, session, and common middlewares.

### `rails/commands/server/server_command.rb`

The `Rails::Server` class is defined in this file by inheriting from
`Rackup::Server`. When `Rails::Server.new` is called, this calls the
`initialize` method in `rails/commands/server/server_command.rb`:

```ruby
module Rails
  class Server < Rackup::Server
    def initialize(options = nil)
      @default_options = options || {}
      super(@default_options)
      set_environment
    end
  end
end
```

Firstly, `super` is called which calls the `initialize` method on
`Rackup::Server`.

### Rackup: `lib/rackup/server.rb`

`Rackup::Server` is responsible for providing a common server interface for all
Rack-based applications, which Rails is now a part of.

The `initialize` method in `Rackup::Server` simply sets several variables:

```ruby
module Rackup
  class Server
    def initialize(options = nil)
      @ignore_options = []

      if options
        @use_default_options = false
        @options = options
        @app = options[:app] if options[:app]
      else
        @use_default_options = true
        @options = parse_options(ARGV)
      end
    end
  end
end
```

In this case, return value of `Rails::Command::ServerCommand#server_options`
will be assigned to `options`. When lines inside if statement is evaluated, a
couple of instance variables will be set.

`server_options` method in `Rails::Command::ServerCommand` is defined as
follows:

```ruby
module Rails
  module Command
    class ServerCommand < Base # :nodoc:
      no_commands do
        def server_options
          {
            user_supplied_options: user_supplied_options,
            server:                options[:using],
            log_stdout:            log_to_stdout?,
            Port:                  port,
            Host:                  host,
            DoNotReverseLookup:    true,
            config:                options[:config],
            environment:           environment,
            daemonize:             options[:daemon],
            pid:                   pid,
            caching:               options[:dev_caching],
            restart_cmd:           restart_command,
            early_hints:           early_hints
          }
        end
      end
    end
  end
end
```

The value will be assigned to instance variable `@options`.

After `super` has finished in `Rackup::Server`, we jump back to
`rails/commands/server/server_command.rb`. At this point, `set_environment` is
called within the context of the `Rails::Server` object.

```ruby
module Rails
  module Server
    def set_environment
      ENV["RAILS_ENV"] ||= options[:environment]
    end
  end
end
```

After `initialize` has finished, we jump back into the server command where
`APP_PATH` (which was set earlier) is required.

### `config/application`

When `require APP_PATH` is executed, `config/application.rb` is loaded (recall
that `APP_PATH` is defined in `bin/rails`). This file exists in your application
and it's free for you to change based on your needs.

### `Rails::Server#start`

After `config/application` is loaded, `server.start` is called. This method is
defined like this:

```ruby
module Rails
  class Server < ::Rackup::Server
    def start(after_stop_callback = nil)
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super()
      # ...
    end

    private
      def setup_dev_caching
        if options[:environment] == "development"
          Rails::DevCaching.enable_by_argument(options[:caching])
        end
      end

      def create_tmp_directories
        %w(cache pids sockets).each do |dir_to_make|
          FileUtils.mkdir_p(File.join(Rails.root, "tmp", dir_to_make))
        end
      end

      def log_to_stdout
        wrapped_app # touch the app so the logger is set up

        console = ActiveSupport::Logger.new(STDOUT)
        console.formatter = Rails.logger.formatter
        console.level = Rails.logger.level

        unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
          Rails.logger.broadcast_to(console)
        end
      end
  end
end
```

This method creates a trap for `INT` signals, so if you `CTRL-C` the server, it
will exit the process. As we can see from the code here, it will create the
`tmp/cache`, `tmp/pids`, and `tmp/sockets` directories. It then enables caching
in development if `bin/rails server` is called with `--dev-caching`. Finally, it
calls `wrapped_app` which is responsible for creating the Rack app, before
creating and assigning an instance of `ActiveSupport::Logger`.

The `super` method will call `Rackup::Server.start` which begins its definition
as follows:

```ruby
module Rackup
  class Server
    def start(&block)
      if options[:warn]
        $-w = true
      end

      if includes = options[:include]
        $LOAD_PATH.unshift(*includes)
      end

      Array(options[:require]).each do |library|
        require library
      end

      if options[:debug]
        $DEBUG = true
        require "pp"
        p options[:server]
        pp wrapped_app
        pp app
      end

      check_pid! if options[:pid]

      # Touch the wrapped app, so that the config.ru is loaded before
      # daemonization (i.e. before chdir, etc).
      handle_profiling(options[:heapfile], options[:profile_mode], options[:profile_file]) do
        wrapped_app
      end

      daemonize_app if options[:daemonize]

      write_pid if options[:pid]

      trap(:INT) do
        if server.respond_to?(:shutdown)
          server.shutdown
        else
          exit
        end
      end

      server.run(wrapped_app, **options, &block)
    end
  end
end
```

The interesting part for a Rails app is the last line, `server.run`. Here we
encounter the `wrapped_app` method again, which this time we're going to explore
more (even though it was executed before, and thus memoized by now).

```ruby
module Rackup
  class Server
    def wrapped_app
      @wrapped_app ||= build_app app
    end
  end
end
```

The `app` method here is defined like so:

```ruby
module Rackup
  class Server
    def app
      @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
    end

    # ...

    private
      def build_app_and_options_from_config
        if !::File.exist? options[:config]
          abort "configuration #{options[:config]} not found"
        end

        Rack::Builder.parse_file(self.options[:config])
      end

      def build_app_from_string
        Rack::Builder.new_from_string(self.options[:builder])
      end
  end
end
```

The `options[:config]` value defaults to `config.ru` which contains this:

```ruby
# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

run Rails.application
Rails.application.load_server
```


The `Rack::Builder.parse_file` method here takes the content from this
`config.ru` file and parses it using this code:

```ruby
module Rack
  class Builder
    def self.load_file(path, **options)
      # ...
      new_from_string(config, path, **options)
    end

    # ...

    def self.new_from_string(builder_script, path = "(rackup)", **options)
      builder = self.new(**options)

      # We want to build a variant of TOPLEVEL_BINDING with self as a Rack::Builder instance.
      # We cannot use instance_eval(String) as that would resolve constants differently.
      binding = BUILDER_TOPLEVEL_BINDING.call(builder)
      eval(builder_script, binding, path)

      builder.to_app
    end
  end
end
```

The `initialize` method of `Rack::Builder` will take the block here and execute
it within an instance of `Rack::Builder`. This is where the majority of the
initialization process of Rails happens. The `require` line for
`config/environment.rb` in `config.ru` is the first to run:

```ruby
require_relative "config/environment"
```

### `config/environment.rb`

This file is the common file required by `config.ru` (`bin/rails server`) and
Passenger. This is where these two ways to run the server meet; everything
before this point has been Rack and Rails setup.

This file begins with requiring `config/application.rb`:

```ruby
require_relative "application"
```

### `config/application.rb`

This file requires `config/boot.rb`:

```ruby
require_relative "boot"
```

But only if it hasn't been required before, which would be the case in
`bin/rails server` but **wouldn't** be the case with Passenger.

Then the fun begins!

Loading Rails
-------------

The next line in `config/application.rb` is:

```ruby
require "rails/all"
```

### `railties/lib/rails/all.rb`

This file is responsible for requiring all the individual frameworks of Rails:

```ruby
require "rails"

%w(
  active_record/railtie
  active_storage/engine
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  action_mailbox/engine
  action_text/engine
  rails/test_unit/railtie
).each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end
```

This is where all the Rails frameworks are loaded and thus made available to the
application. We won't go into detail of what happens inside each of those
frameworks, but you're encouraged to try and explore them on your own.

For now, just keep in mind that common functionality like Rails engines, I18n
and Rails configuration are all being defined here.

### Back to `config/environment.rb`

The rest of `config/application.rb` defines the configuration for the
`Rails::Application` which will be used once the application is fully
initialized. When `config/application.rb` has finished loading Rails and defined
the application namespace, we go back to `config/environment.rb`. Here, the
application is initialized with `Rails.application.initialize!`, which is
defined in `rails/application.rb`.

### `railties/lib/rails/application.rb`

The `initialize!` method looks like this:

```ruby
def initialize!(group = :default) # :nodoc:
  raise "Application has been already initialized." if @initialized
  run_initializers(group, self)
  @initialized = true
  self
end
```

You can only initialize an app once. The Railtie
[initializers](configuring.html#initializers) are run through the
`run_initializers` method which is defined in
`railties/lib/rails/initializable.rb`:

```ruby
def run_initializers(group = :default, *args)
  return if instance_variable_defined?(:@ran)
  initializers.tsort_each do |initializer|
    initializer.run(*args) if initializer.belongs_to?(group)
  end
  @ran = true
end
```

The `run_initializers` code itself is tricky. What Rails is doing here is
traversing all the class ancestors looking for those that respond to an
`initializers` method. It then sorts the ancestors by name, and runs them. For
example, the `Engine` class will make all the engines available by providing an
`initializers` method on them.

The `Rails::Application` class, as defined in
`railties/lib/rails/application.rb` defines `bootstrap`, `railtie`, and
`finisher` initializers. The `bootstrap` initializers prepare the application
(like initializing the logger) while the `finisher` initializers (like building
the middleware stack) are run last. The `railtie` initializers are the
initializers which have been defined on the `Rails::Application` itself and are
run between the `bootstrap` and `finisher`.

NOTE: Do not confuse Railtie initializers overall with the
[load_config_initializers](configuring.html#using-initializer-files) initializer
instance or its associated config initializers in `config/initializers`.

After this is done we go back to `Rackup::Server`.

### Rack: lib/rack/server.rb

Last time we left when the `app` method was being defined:

```ruby
module Rackup
  class Server
    def app
      @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
    end

    # ...

    private
      def build_app_and_options_from_config
        if !::File.exist? options[:config]
          abort "configuration #{options[:config]} not found"
        end

        Rack::Builder.parse_file(self.options[:config])
      end

      def build_app_from_string
        Rack::Builder.new_from_string(self.options[:builder])
      end
  end
end
```

At this point `app` is the Rails app itself (a middleware), and what happens
next is Rack will call all the provided middlewares:

```ruby
module Rackup
  class Server
    private
      def build_app(app)
        middleware[options[:environment]].reverse_each do |middleware|
          middleware = middleware.call(self) if middleware.respond_to?(:call)
          next unless middleware
          klass, *args = middleware
          app = klass.new(app, *args)
        end
        app
      end
  end
end
```

Remember, `build_app` was called (by `wrapped_app`) in the last line of
`Rackup::Server#start`. Here's how it looked like when we left:

```ruby
server.run(wrapped_app, **options, &block)
```

At this point, the implementation of `server.run` will depend on the server
you're using. For example, if you were using Puma, here's what the `run` method
would look like:

```ruby
module Rack
  module Handler
    module Puma
      # ...
      def self.run(app, options = {})
        conf = self.config(app, options)

        log_writer = options.delete(:Silent) ? ::Puma::LogWriter.strings : ::Puma::LogWriter.stdio

        launcher = ::Puma::Launcher.new(conf, log_writer: log_writer, events: @events)

        yield launcher if block_given?
        begin
          launcher.run
        rescue Interrupt
          puts "* Gracefully stopping, waiting for requests to finish"
          launcher.stop
          puts "* Goodbye!"
        end
      end
      # ...
    end
  end
end
```

We won't dig into the server configuration itself, but this is the last piece of
our journey in the Rails initialization process.

This high level overview will help you understand when your code is executed and
how, and overall become a better Rails developer. If you still want to know
more, the Rails source code itself is probably the best place to go next.
