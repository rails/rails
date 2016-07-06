**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

The Rails Initialization Process
================================

This guide explains the internals of the initialization process in Rails.
It is an extremely in-depth guide and recommended for advanced Rails developers.

After reading this guide, you will know:

* How to use `rails server`.
* The timeline of Rails' initialization sequence.
* Where different files are required by the boot sequence.
* How the Rails::Server interface is defined and used.

--------------------------------------------------------------------------------

This guide goes through every method call that is
required to boot up the Ruby on Rails stack for a default Rails
application, explaining each part in detail along the way. For this
guide, we will be focusing on what happens when you execute `rails server`
to boot your app.

NOTE: Paths in this guide are relative to Rails or a Rails application unless otherwise specified.

TIP: If you want to follow along while browsing the Rails [source
code](https://github.com/rails/rails), we recommend that you use the `t`
key binding to open the file finder inside GitHub and find files
quickly.

Launch!
-------

Let's start to boot and initialize the app. A Rails application is usually
started by running `rails console` or `rails server`.

### `railties/exe/rails`

The `rails` in the command `rails server` is a ruby executable in your load
path. This executable contains the following lines:

```ruby
version = ">= 0"
load Gem.bin_path('railties', 'rails', version)
```

If you try out this command in a Rails console, you would see that this loads
`railties/exe/rails`. A part of the file `railties/exe/rails.rb` has the
following code:

```ruby
require "rails/cli"
```

The file `railties/lib/rails/cli` in turn calls
`Rails::AppLoader.exec_app`.

### `railties/lib/rails/app_loader.rb`

The primary goal of the function `exec_app` is to execute your app's
`bin/rails`. If the current directory does not have a `bin/rails`, it will
navigate upwards until it finds a `bin/rails` executable. Thus one can invoke a
`rails` command from anywhere inside a rails application.

For `rails server` the equivalent of the following command is executed:

```bash
$ exec ruby bin/rails server
```

### `bin/rails`

This file is as follows:

```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path('../../config/application', __FILE__)
require_relative '../config/boot'
require 'rails/commands'
```

The `APP_PATH` constant will be used later in `rails/commands`. The `config/boot` file referenced here is the `config/boot.rb` file in our application which is responsible for loading Bundler and setting it up.

### `config/boot.rb`

`config/boot.rb` contains:

```ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
```

In a standard Rails application, there's a `Gemfile` which declares all
dependencies of the application. `config/boot.rb` sets
`ENV['BUNDLE_GEMFILE']` to the location of this file. If the Gemfile
exists, then `bundler/setup` is required. The require is used by Bundler to
configure the load path for your Gemfile's dependencies.

A standard Rails application depends on several gems, specifically:

* actionmailer
* actionpack
* actionview
* activemodel
* activerecord
* activesupport
* activejob
* arel
* builder
* bundler
* erubis
* i18n
* mail
* mime-types
* rack
* rack-cache
* rack-mount
* rack-test
* rails
* railties
* rake
* sqlite3
* thor
* tzinfo

### `rails/commands.rb`

Once `config/boot.rb` has finished, the next file that is required is
`rails/commands`, which helps in expanding aliases. In the current case, the
`ARGV` array simply contains `server` which will be passed over:

```ruby
ARGV << '--help' if ARGV.empty?

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

require 'rails/commands/commands_tasks'

Rails::CommandsTasks.new(ARGV).run_command!(command)
```

TIP: As you can see, an empty ARGV list will make Rails show the help
snippet.

If we had used `s` rather than `server`, Rails would have used the `aliases`
defined here to find the matching command.

### `rails/commands/commands_tasks.rb`

When one types a valid Rails command, `run_command!` a method of the same name
is called. If Rails doesn't recognize the command, it tries to run a Rake task
of the same name.

```ruby
COMMAND_WHITELIST = %w(plugin generate destroy console server dbconsole application runner new version help)

def run_command!(command)
  command = parse_command(command)

  if COMMAND_WHITELIST.include?(command)
    send(command)
  else
    run_rake_task(command)
  end
end
```

With the `server` command, Rails will further run the following code:

```ruby
def set_application_directory!
  Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
end

def server
  set_application_directory!
  require_command!("server")

  Rails::Server.new.tap do |server|
    # We need to require application after the server sets environment,
    # otherwise the --environment option given to the server won't propagate.
    require APP_PATH
    Dir.chdir(Rails.application.root)
    server.start
  end
end

def require_command!(command)
  require "rails/commands/#{command}"
end
```

This file will change into the Rails root directory (a path two directories up
from `APP_PATH` which points at `config/application.rb`), but only if the
`config.ru` file isn't found. This then requires `rails/commands/server` which
sets up the `Rails::Server` class.

```ruby
require 'fileutils'
require 'optparse'
require 'action_dispatch'
require 'rails'

module Rails
  class Server < ::Rack::Server
```

`fileutils` and `optparse` are standard Ruby libraries which provide helper functions for working with files and parsing options.

### `actionpack/lib/action_dispatch.rb`

Action Dispatch is the routing component of the Rails framework.
It adds functionality like routing, session, and common middlewares.

### `rails/commands/server.rb`

The `Rails::Server` class is defined in this file by inheriting from `Rack::Server`. When `Rails::Server.new` is called, this calls the `initialize` method in `rails/commands/server.rb`:

```ruby
def initialize(*)
  super
  set_environment
end
```

Firstly, `super` is called which calls the `initialize` method on `Rack::Server`.

### Rack: `lib/rack/server.rb`

`Rack::Server` is responsible for providing a common server interface for all Rack-based applications, which Rails is now a part of.

The `initialize` method in `Rack::Server` simply sets a couple of variables:

```ruby
def initialize(options = nil)
  @options = options
  @app = options[:app] if options && options[:app]
end
```

In this case, `options` will be `nil` so nothing happens in this method.

After `super` has finished in `Rack::Server`, we jump back to `rails/commands/server.rb`. At this point, `set_environment` is called within the context of the `Rails::Server` object and this method doesn't appear to do much at first glance:

```ruby
def set_environment
  ENV["RAILS_ENV"] ||= options[:environment]
end
```

In fact, the `options` method here does quite a lot. This method is defined in `Rack::Server` like this:

```ruby
def options
  @options ||= parse_options(ARGV)
end
```

Then `parse_options` is defined like this:

```ruby
def parse_options(args)
  options = default_options

  # Don't evaluate CGI ISINDEX parameters.
  # http://www.meb.uni-bonn.de/docs/cgi/cl.html
  args.clear if ENV.include?("REQUEST_METHOD")

  options.merge! opt_parser.parse!(args)
  options[:config] = ::File.expand_path(options[:config])
  ENV["RACK_ENV"] = options[:environment]
  options
end
```

With the `default_options` set to this:

```ruby
def default_options
  environment  = ENV['RACK_ENV'] || 'development'
  default_host = environment == 'development' ? 'localhost' : '0.0.0.0'

  {
    :environment => environment,
    :pid         => nil,
    :Port        => 9292,
    :Host        => default_host,
    :AccessLog   => [],
    :config      => "config.ru"
  }
end
```

There is no `REQUEST_METHOD` key in `ENV` so we can skip over that line. The next line merges in the options from `opt_parser` which is defined plainly in `Rack::Server`:

```ruby
def opt_parser
  Options.new
end
```

The class **is** defined in `Rack::Server`, but is overwritten in `Rails::Server` to take different arguments. Its `parse!` method begins like this:

```ruby
def parse!(args)
  args, options = args.dup, {}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: rails server [mongrel, thin, etc] [options]"
    opts.on("-p", "--port=port", Integer,
            "Runs Rails on the specified port.", "Default: 3000") { |v| options[:Port] = v }
  ...
```

This method will set up keys for the `options` which Rails will then be
able to use to determine how its server should run. After `initialize`
has finished, we jump back into `rails/server` where `APP_PATH` (which was
set earlier) is required.

### `config/application`

When `require APP_PATH` is executed, `config/application.rb` is loaded (recall
that `APP_PATH` is defined in `bin/rails`). This file exists in your application
and it's free for you to change based on your needs.

### `Rails::Server#start`

After `config/application` is loaded, `server.start` is called. This method is
defined like this:

```ruby
def start
  print_boot_information
  trap(:INT) { exit }
  create_tmp_directories
  log_to_stdout if options[:log_stdout]

  super
  ...
end

private

  def print_boot_information
    ...
    puts "=> Run `rails server -h` for more startup options"
  end

  def create_tmp_directories
    %w(cache pids sockets).each do |dir_to_make|
      FileUtils.mkdir_p(File.join(Rails.root, 'tmp', dir_to_make))
    end
  end

  def log_to_stdout
    wrapped_app # touch the app so the logger is set up

    console = ActiveSupport::Logger.new($stdout)
    console.formatter = Rails.logger.formatter
    console.level = Rails.logger.level

    Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
  end
```

This is where the first output of the Rails initialization happens. This method
creates a trap for `INT` signals, so if you `CTRL-C` the server, it will exit the
process. As we can see from the code here, it will create the `tmp/cache`,
`tmp/pids`, and `tmp/sockets` directories. It then calls `wrapped_app` which is
responsible for creating the Rack app, before creating and assigning an instance
of `ActiveSupport::Logger`.

The `super` method will call `Rack::Server.start` which begins its definition like this:

```ruby
def start &blk
  if options[:warn]
    $-w = true
  end

  if includes = options[:include]
    $LOAD_PATH.unshift(*includes)
  end

  if library = options[:require]
    require library
  end

  if options[:debug]
    $DEBUG = true
    require 'pp'
    p options[:server]
    pp wrapped_app
    pp app
  end

  check_pid! if options[:pid]

  # Touch the wrapped app, so that the config.ru is loaded before
  # daemonization (i.e. before chdir, etc).
  wrapped_app

  daemonize_app if options[:daemonize]

  write_pid if options[:pid]

  trap(:INT) do
    if server.respond_to?(:shutdown)
      server.shutdown
    else
      exit
    end
  end

  server.run wrapped_app, options, &blk
end
```

The interesting part for a Rails app is the last line, `server.run`. Here we encounter the `wrapped_app` method again, which this time
we're going to explore more (even though it was executed before, and
thus memoized by now).

```ruby
@wrapped_app ||= build_app app
```

The `app` method here is defined like so:

```ruby
def app
  @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
end
...
private
  def build_app_and_options_from_config
    if !::File.exist? options[:config]
      abort "configuration #{options[:config]} not found"
    end

    app, options = Rack::Builder.parse_file(self.options[:config], opt_parser)
    self.options.merge! options
    app
  end

  def build_app_from_string
    Rack::Builder.new_from_string(self.options[:builder])
  end
```

The `options[:config]` value defaults to `config.ru` which contains this:

```ruby
# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
run <%= app_const %>
```


The `Rack::Builder.parse_file` method here takes the content from this `config.ru` file and parses it using this code:

```ruby
app = new_from_string cfgfile, config

...

def self.new_from_string(builder_script, file="(rackup)")
  eval "Rack::Builder.new {\n" + builder_script + "\n}.to_app",
    TOPLEVEL_BINDING, file, 0
end
```

The `initialize` method of `Rack::Builder` will take the block here and execute it within an instance of `Rack::Builder`. This is where the majority of the initialization process of Rails happens. The `require` line for `config/environment.rb` in `config.ru` is the first to run:

```ruby
require_relative 'config/environment'
```

### `config/environment.rb`

This file is the common file required by `config.ru` (`rails server`) and Passenger. This is where these two ways to run the server meet; everything before this point has been Rack and Rails setup.

This file begins with requiring `config/application.rb`:

```ruby
require_relative 'application'
```

### `config/application.rb`

This file requires `config/boot.rb`:

```ruby
require_relative 'boot'
```

But only if it hasn't been required before, which would be the case in `rails server`
but **wouldn't** be the case with Passenger.

Then the fun begins!

Loading Rails
-------------

The next line in `config/application.rb` is:

```ruby
require 'rails/all'
```

### `railties/lib/rails/all.rb`

This file is responsible for requiring all the individual frameworks of Rails:

```ruby
require "rails"

%w(
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  rails/test_unit/railtie
  sprockets/railtie
).each do |railtie|
  begin
    require "#{railtie}"
  rescue LoadError
  end
end
```

This is where all the Rails frameworks are loaded and thus made
available to the application. We won't go into detail of what happens
inside each of those frameworks, but you're encouraged to try and
explore them on your own.

For now, just keep in mind that common functionality like Rails engines,
I18n and Rails configuration are all being defined here.

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
def initialize!(group=:default) #:nodoc:
  raise "Application has been already initialized." if @initialized
  run_initializers(group, self)
  @initialized = true
  self
end
```

As you can see, you can only initialize an app once. The initializers are run through
the `run_initializers` method which is defined in `railties/lib/rails/initializable.rb`:

```ruby
def run_initializers(group=:default, *args)
  return if instance_variable_defined?(:@ran)
  initializers.tsort_each do |initializer|
    initializer.run(*args) if initializer.belongs_to?(group)
  end
  @ran = true
end
```

The `run_initializers` code itself is tricky. What Rails is doing here is
traversing all the class ancestors looking for those that respond to an
`initializers` method. It then sorts the ancestors by name, and runs them.
For example, the `Engine` class will make all the engines available by
providing an `initializers` method on them.

The `Rails::Application` class, as defined in `railties/lib/rails/application.rb`
defines `bootstrap`, `railtie`, and `finisher` initializers. The `bootstrap` initializers
prepare the application (like initializing the logger) while the `finisher`
initializers (like building the middleware stack) are run last. The `railtie`
initializers are the initializers which have been defined on the `Rails::Application`
itself and are run between the `bootstrap` and `finishers`.

After this is done we go back to `Rack::Server`.

### Rack: lib/rack/server.rb

Last time we left when the `app` method was being defined:

```ruby
def app
  @app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
end
...
private
  def build_app_and_options_from_config
    if !::File.exist? options[:config]
      abort "configuration #{options[:config]} not found"
    end

    app, options = Rack::Builder.parse_file(self.options[:config], opt_parser)
    self.options.merge! options
    app
  end

  def build_app_from_string
    Rack::Builder.new_from_string(self.options[:builder])
  end
```

At this point `app` is the Rails app itself (a middleware), and what
happens next is Rack will call all the provided middlewares:

```ruby
def build_app(app)
  middleware[options[:environment]].reverse_each do |middleware|
    middleware = middleware.call(self) if middleware.respond_to?(:call)
    next unless middleware
    klass = middleware.shift
    app = klass.new(app, *middleware)
  end
  app
end
```

Remember, `build_app` was called (by `wrapped_app`) in the last line of `Server#start`.
Here's how it looked like when we left:

```ruby
server.run wrapped_app, options, &blk
```

At this point, the implementation of `server.run` will depend on the
server you're using. For example, if you were using Puma, here's what
the `run` method would look like:

```ruby
...
DEFAULT_OPTIONS = {
  :Host => '0.0.0.0',
  :Port => 8080,
  :Threads => '0:16',
  :Verbose => false
}

def self.run(app, options = {})
  options  = DEFAULT_OPTIONS.merge(options)

  if options[:Verbose]
    app = Rack::CommonLogger.new(app, STDOUT)
  end

  if options[:environment]
    ENV['RACK_ENV'] = options[:environment].to_s
  end

  server   = ::Puma::Server.new(app)
  min, max = options[:Threads].split(':', 2)

  puts "Puma #{::Puma::Const::PUMA_VERSION} starting..."
  puts "* Min threads: #{min}, max threads: #{max}"
  puts "* Environment: #{ENV['RACK_ENV']}"
  puts "* Listening on tcp://#{options[:Host]}:#{options[:Port]}"

  server.add_tcp_listener options[:Host], options[:Port]
  server.min_threads = min
  server.max_threads = max
  yield server if block_given?

  begin
    server.run.join
  rescue Interrupt
    puts "* Gracefully stopping, waiting for requests to finish"
    server.stop(true)
    puts "* Goodbye!"
  end

end
```

We won't dig into the server configuration itself, but this is
the last piece of our journey in the Rails initialization process.

This high level overview will help you understand when your code is
executed and how, and overall become a better Rails developer. If you
still want to know more, the Rails source code itself is probably the
best place to go next.
