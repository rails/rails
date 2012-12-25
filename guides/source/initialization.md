The Rails Initialization Process
================================

This guide explains the internals of the initialization process in Rails
as of Rails 4. It is an extremely in-depth guide and recommended for advanced Rails developers.

After reading this guide, you will know:

* How to use `rails server`.

--------------------------------------------------------------------------------

This guide goes through every method call that is
required to boot up the Ruby on Rails stack for a default Rails 4
application, explaining each part in detail along the way. For this
guide, we will be focusing on what happens when you execute +rails
server+ to boot your app.

NOTE: Paths in this guide are relative to Rails or a Rails application unless otherwise specified.

TIP: If you want to follow along while browsing the Rails [source
code](https://github.com/rails/rails), we recommend that you use the `t`
key binding to open the file finder inside GitHub and find files
quickly.

Launch!
-------

A Rails application is usually started with the command `rails server`.

### `bin/rails`

The actual `rails` command is kept in _bin/rails_:

```ruby
#!/usr/bin/env ruby

if File.exists?(File.join(File.expand_path('../../..', __FILE__), '.git'))
  railties_path = File.expand_path('../../lib', __FILE__)
  $:.unshift(railties_path)
end
require "rails/cli"
```

This file will first attempt to push the `railties/lib` directory if
present, and then requires `rails/cli`.

### `railties/lib/rails/cli.rb`

This file looks like this:

```ruby
require 'rbconfig'
require 'rails/script_rails_loader'

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::ScriptRailsLoader.exec_script_rails!

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit(1) }

if ARGV.first == 'plugin'
  ARGV.shift
  require 'rails/commands/plugin_new'
else
  require 'rails/commands/application'
end
```

The `rbconfig` file from the Ruby standard library provides us with the `RbConfig` class which contains detailed information about the Ruby environment, including how Ruby was compiled. We can see this in use in `railties/lib/rails/script_rails_loader`.

```ruby
require 'pathname'

module Rails
  module ScriptRailsLoader
    RUBY = File.join(*RbConfig::CONFIG.values_at("bindir", "ruby_install_name")) + RbConfig::CONFIG["EXEEXT"]
    SCRIPT_RAILS = File.join('script', 'rails')
    ...

  end
end
```

The `rails/script_rails_loader` file uses `RbConfig::Config` to obtain the `bin_dir` and `ruby_install_name` values for the configuration which together form the path to the Ruby interpreter. The `RbConfig::CONFIG["EXEEXT"]` will suffix this path with ".exe" if the script is running on Windows. This constant is used later on in `exec_script_rails!`. As for the `SCRIPT_RAILS` constant, we'll see that when we get to the `in_rails_application?` method.

Back in `rails/cli`, the next line is this:

```ruby
Rails::ScriptRailsLoader.exec_script_rails!
```

This method is defined in `rails/script_rails_loader`:

```ruby
def self.exec_script_rails!
  cwd = Dir.pwd
  return unless in_rails_application? || in_rails_application_subdirectory?
  exec RUBY, SCRIPT_RAILS, *ARGV if in_rails_application?
  Dir.chdir("..") do
    # Recurse in a chdir block: if the search fails we want to be sure
    # the application is generated in the original working directory.
    exec_script_rails! unless cwd == Dir.pwd
  end
rescue SystemCallError
  # could not chdir, no problem just return
end
```

This method will first check if the current working directory (`cwd`) is a Rails application or a subdirectory of one. This is determined by the `in_rails_application?` method:

```ruby
def self.in_rails_application?
  File.exists?(SCRIPT_RAILS)
end
```

The `SCRIPT_RAILS` constant defined earlier is used here, with `File.exists?` checking for its presence in the current directory. If this method returns `false` then `in_rails_application_subdirectory?` will be used:

```ruby
def self.in_rails_application_subdirectory?(path = Pathname.new(Dir.pwd))
  File.exists?(File.join(path, SCRIPT_RAILS)) || !path.root? && in_rails_application_subdirectory?(path.parent)
end
```

This climbs the directory tree until it reaches a path which contains a `script/rails` file. If a directory containing this file is reached then this line will run:

```ruby
exec RUBY, SCRIPT_RAILS, *ARGV if in_rails_application?
```

This is effectively the same as running `ruby script/rails [arguments]`, where `[arguments]` at this point in time is simply "server".

Rails Initialization
--------------------

Only now we finally start the real initialization process, beginning
with `script/rails`.

TIP: If you execute `script/rails` directly from your Rails app you will
skip executing all the code that we've just described.

### `script/rails`

This file is as follows:

```ruby
APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/boot',  __FILE__)
require 'rails/commands'
```

The `APP_PATH` constant will be used later in `rails/commands`. The `config/boot` file referenced here is the `config/boot.rb` file in our application which is responsible for loading Bundler and setting it up.

### `config/boot.rb`

`config/boot.rb` contains:

```ruby
# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
```

In a standard Rails application, there's a `Gemfile` which declares all
dependencies of the application. `config/boot.rb` sets
`ENV['BUNDLE_GEMFILE']` to the location of this file. If the Gemfile
exists, `bundler/setup` is then required.

The gems that a Rails 4 application depends on are as follows:

TODO: change these when the Rails 4 release is near.

* abstract (1.0.0)
* actionmailer (4.0.0.beta)
* actionpack (4.0.0.beta)
* activemodel (4.0.0.beta)
* activerecord (4.0.0.beta)
* activesupport (4.0.0.beta)
* arel (2.0.7)
* builder (3.0.0)
* bundler (1.0.6)
* erubis (2.6.6)
* i18n (0.5.0)
* mail (2.2.12)
* mime-types (1.16)
* polyglot (0.3.1)
* rack (1.2.1)
* rack-cache (0.5.3)
* rack-mount (0.6.13)
* rack-test (0.5.6)
* rails (4.0.0.beta)
* railties (4.0.0.beta)
* rake (0.8.7)
* sqlite3-ruby (1.3.2)
* thor (0.14.6)
* treetop (1.4.9)
* tzinfo (0.3.23)

### `rails/commands.rb`

Once `config/boot.rb` has finished, the next file that is required is `rails/commands` which will execute a command based on the arguments passed in. In this case, the `ARGV` array simply contains `server` which is extracted into the `command` variable using these lines:

```ruby
ARGV << '--help' if ARGV.empty?

aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner"
}

command = ARGV.shift
command = aliases[command] || command
```

TIP: As you can see, an empty ARGV list will make Rails show the help
snippet.

If we used `s` rather than `server`, Rails will use the `aliases` defined in the file and match them to their respective commands. With the `server` command, Rails will run this code:

```ruby
when 'server'
  # Change to the application's path if there is no config.ru file in current dir.
  # This allows us to run script/rails server from other directories, but still get
  # the main config.ru and properly set the tmp directory.
  Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exists?(File.expand_path("config.ru"))

  require 'rails/commands/server'
  Rails::Server.new.tap { |server|
    # We need to require application after the server sets environment,
    # otherwise the --environment option given to the server won't propagate.
    require APP_PATH
    Dir.chdir(Rails.application.root)
    server.start
  }
```

This file will change into the root of the directory (a path two directories back from `APP_PATH` which points at `config/application.rb`), but only if the `config.ru` file isn't found. This then requires `rails/commands/server` which sets up the `Rails::Server` class.

```ruby
require 'fileutils'
require 'optparse'
require 'action_dispatch'

module Rails
  class Server < ::Rack::Server
```

`fileutils` and `optparse` are standard Ruby libraries which provide helper functions for working with files and parsing options.

### `actionpack/lib/action_dispatch.rb`

Action Dispatch is the routing component of the Rails framework.
It adds functionalities like routing, session, and common middlewares.

### `rails/commands/server.rb`

The `Rails::Server` class is defined in this file as inheriting from `Rack::Server`. When `Rails::Server.new` is called, this calls the `initialize` method in `rails/commands/server.rb`:

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
  # http://hoohoo.ncsa.uiuc.edu/cgi/cl.html
  args.clear if ENV.include?("REQUEST_METHOD")

  options.merge! opt_parser.parse! args
  options[:config] = ::File.expand_path(options[:config])
  ENV["RACK_ENV"] = options[:environment]
  options
end
```

With the `default_options` set to this:

```ruby
def default_options
  {
    :environment => ENV['RACK_ENV'] || "development",
    :pid         => nil,
    :Port        => 9292,
    :Host        => "0.0.0.0",
    :AccessLog   => [],
    :config      => "config.ru"
  }
end
```

There is no `REQUEST_METHOD` key in `ENV` so we can skip over that line. The next line merges in the options from `opt_parser` which is defined plainly in `Rack::Server`

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

When `require APP_PATH` is executed, `config/application.rb` is loaded.
This file exists in your app and it's free for you to change based
on your needs.

### `Rails::Server#start`

After `config/application` is loaded, `server.start` is called. This method is defined like this:

```ruby
def start
  url = "#{options[:SSLEnable] ? 'https' : 'http'}://#{options[:Host]}:#{options[:Port]}"
  puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
  puts "=> Rails #{Rails.version} application starting in #{Rails.env} on #{url}"
  puts "=> Call with -d to detach" unless options[:daemonize]
  trap(:INT) { exit }
  puts "=> Ctrl-C to shutdown server" unless options[:daemonize]

  #Create required tmp directories if not found
  %w(cache pids sessions sockets).each do |dir_to_make|
    FileUtils.mkdir_p(Rails.root.join('tmp', dir_to_make))
  end

  unless options[:daemonize]
    wrapped_app # touch the app so the logger is set up

    console = ActiveSupport::Logger.new($stdout)
    console.formatter = Rails.logger.formatter

    Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
  end

  super
ensure
  # The '-h' option calls exit before @options is set.
  # If we call 'options' with it unset, we get double help banners.
  puts 'Exiting' unless @options && options[:daemonize]
end
```

This is where the first output of the Rails initialization happens. This
method creates a trap for `INT` signals, so if you `CTRL-C` the server,
it will exit the process. As we can see from the code here, it will
create the `tmp/cache`, `tmp/pids`, `tmp/sessions` and `tmp/sockets`
directories. It then calls `wrapped_app` which is responsible for
creating the Rack app, before creating and assigning an
instance of `ActiveSupport::Logger`.

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
thus memorized by now).

```ruby
@wrapped_app ||= build_app app
```

The `app` method here is defined like so:

```ruby
def app
  @app ||= begin
    if !::File.exist? options[:config]
      abort "configuration #{options[:config]} not found"
    end

    app, options = Rack::Builder.parse_file(self.options[:config], opt_parser)
    self.options.merge! options
    app
  end
end
```

The `options[:config]` value defaults to `config.ru` which contains this:

```ruby
# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run <%= app_const %>
```


The `Rack::Builder.parse_file` method here takes the content from this `config.ru` file and parses it using this code:

```ruby
app = eval "Rack::Builder.new {( " + cfgfile + "\n )}.to_app",
    TOPLEVEL_BINDING, config
```

The `initialize` method of `Rack::Builder` will take the block here and execute it within an instance of `Rack::Builder`. This is where the majority of the initialization process of Rails happens. The `require` line for `config/environment.rb` in `config.ru` is the first to run:

```ruby
require ::File.expand_path('../config/environment',  __FILE__)
```

### `config/environment.rb`

This file is the common file required by `config.ru` (`rails server`) and Passenger. This is where these two ways to run the server meet; everything before this point has been Rack and Rails setup.

This file begins with requiring `config/application.rb`.

### `config/application.rb`

This file requires `config/boot.rb`, but only if it hasn't been required before, which would be the case in `rails server` but **wouldn't** be the case with Passenger.

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
    active_record
    action_controller
    action_mailer
    rails/test_unit
    sprockets
).each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
  end
end
```

This is where all the Rails frameworks are loaded and thus made
available to the application. We won't go into detail of what happens
inside each of those frameworks, but you're encouraged to try and
explore them on your own.

For now, just keep in mind that common functionality like Rails engines,
I18n and Rails configuration is all being defined here.

### Back to `config/environment.rb`

When `config/application.rb` has finished loading Rails, and defined
your application namespace, you go back to `config/environment.rb`,
where your application is initialized. For example, if you application was called
`Blog`, here you would find `Blog::Application.initialize!`, which is
defined in `rails/application.rb`

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

As you can see, you can only initialize an app once. This is also where the initializers are run.

TODO: review this

The initializers code itself is tricky. What Rails is doing here is it
traverses all the class ancestors looking for an `initializers` method,
sorting them and running them. For example, the `Engine` class will make
all the engines available by providing the `initializers` method.

After this is done we go back to `Rack::Server`

### Rack: lib/rack/server.rb

Last time we left when the `app` method was being defined:

```ruby
def app
  @app ||= begin
    if !::File.exist? options[:config]
      abort "configuration #{options[:config]} not found"
    end

    app, options = Rack::Builder.parse_file(self.options[:config], opt_parser)
    self.options.merge! options
    app
  end
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

Remember, `build_app` was called (by wrapped_app) in the last line of `Server#start`.
Here's how it looked like when we left:

```ruby
server.run wrapped_app, options, &blk
```

At this point, the implementation of `server.run` will depend on the
server you're using. For example, if you were using Mongrel, here's what
the `run` method would look like:

```ruby
def self.run(app, options={})
  server = ::Mongrel::HttpServer.new(
    options[:Host]           || '0.0.0.0',
    options[:Port]           || 8080,
    options[:num_processors] || 950,
    options[:throttle]       || 0,
    options[:timeout]        || 60)
  # Acts like Rack::URLMap, utilizing Mongrel's own path finding methods.
  # Use is similar to #run, replacing the app argument with a hash of
  # { path=>app, ... } or an instance of Rack::URLMap.
  if options[:map]
    if app.is_a? Hash
      app.each do |path, appl|
        path = '/'+path unless path[0] == ?/
        server.register(path, Rack::Handler::Mongrel.new(appl))
      end
    elsif app.is_a? URLMap
      app.instance_variable_get(:@mapping).each do |(host, path, appl)|
       next if !host.nil? && !options[:Host].nil? && options[:Host] != host
       path = '/'+path unless path[0] == ?/
       server.register(path, Rack::Handler::Mongrel.new(appl))
      end
    else
      raise ArgumentError, "first argument should be a Hash or URLMap"
    end
  else
    server.register('/', Rack::Handler::Mongrel.new(app))
  end
  yield server  if block_given?
  server.run.join
end
```

We won't dig into the server configuration itself, but this is
the last piece of our journey in the Rails initialization process.

This high level overview will help you understand when your code is
executed and how, and overall become a better Rails developer. If you
still want to know more, the Rails source code itself is probably the
best place to go next.
