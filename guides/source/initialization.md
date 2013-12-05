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

Now we finally boot and initialize the app. It all starts with your app's
`bin/rails` executable. A Rails application is usually started by running
`rails console` or `rails server`.

### `bin/rails`

This file is as follows:

```ruby
#!/usr/bin/env ruby
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

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
```

In a standard Rails application, there's a `Gemfile` which declares all
dependencies of the application. `config/boot.rb` sets
`ENV['BUNDLE_GEMFILE']` to the location of this file. If the Gemfile
exists, `bundler/setup` is then required.

A standard Rails application depends on several gems, specifically:

* abstract
* actionmailer
* actionpack
* activemodel
* activerecord
* activesupport
* arel
* builder
* bundler
* erubis
* i18n
* mail
* mime-types
* polyglot
* rack
* rack-cache
* rack-mount
* rack-test
* rails
* railties
* rake
* sqlite3-ruby
* thor
* treetop
* tzinfo

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
  # This allows us to run `rails server` from other directories, but still get
  # the main config.ru and properly set the tmp directory.
  Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exist?(File.expand_path("config.ru"))

  require 'rails/commands/server'
  Rails::Server.new.tap do |server|
    # We need to require application after the server sets environment,
    # otherwise the --environment option given to the server won't propagate.
    require APP_PATH
    Dir.chdir(Rails.application.root)
    server.start
  end
```

This file will change into the Rails root directory (a path two directories up from `APP_PATH` which points at `config/application.rb`), but only if the `config.ru` file isn't found. This then requires `rails/commands/server` which sets up the `Rails::Server` class.

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
  puts "=> Run `rails server -h` for more startup options"
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
I18n and Rails configuration are all being defined here.

### Back to `config/environment.rb`

When `config/application.rb` has finished loading Rails, and defined
the application namespace, we go back to `config/environment.rb`,
where the application is initialized. For example, if the application was called
`Blog`, here we would find `Blog::Application.initialize!`, which is
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
