Creating Plugin Basics
====================

Pretend for a moment that you are an avid bird watcher.  Your favorite bird is the Yaffle, and you want to create a plugin that allows other developers to share in the Yaffle goodness.

In this tutorial you will learn how to create a plugin that includes:

Core Extensions - extending String:

    # Anywhere
    "hello".squawk # => "squawk! hello! squawk!"

An `acts_as_yaffle` method for Active Record models that adds a "squawk" method:

    class Hickwall < ActiveRecord::Base
      acts_as_yaffle :yaffle_text_field => :last_sang_at
    end

    Hickwall.new.squawk("Hello World")

A view helper that will print out squawking info:

    squawk_info_for(@hickwall)

A generator that creates a migration to add squawk columns to a model:

    script/generate yaffle hickwall

A custom generator command:

    class YaffleGenerator < Rails::Generator::NamedBase
      def manifest
          m.yaffle_definition
        end
      end
    end

A custom route method:

    ActionController::Routing::Routes.draw do |map|
      map.yaffles
    end

In addition you'll learn how to:

* test your plugins
* work with init.rb, how to store model, views, controllers, helpers and even other plugins in your plugins
* create documentation for your plugin.
* write custom rake tasks in your plugin

Create the basic app
---------------------

In this tutorial we will create a basic rails application with 1 resource: bird.  Start out by building the basic rails app:

> The following instructions will work for sqlite3.  For more detailed instructions on how to create a rails app for other databases see the API docs.

    rails plugin_demo
    cd plugin_demo
    script/generate scaffold bird name:string
    rake db:migrate
    script/server

Then navigate to [http://localhost:3000/birds](http://localhost:3000/birds).  Make sure you have a functioning rails app before continuing.

Create the plugin
-----------------------

The built-in Rails plugin generator stubs out a new plugin. Pass the plugin name, either CamelCased or under_scored, as an argument. Pass --with-generator to add an example generator also.

This creates a plugin in vendor/plugins including an init.rb and README as well as standard lib, task, and test directories.

Examples:

    ./script/generate plugin BrowserFilters
    ./script/generate plugin BrowserFilters --with-generator

Later in the plugin we will create a generator, so go ahead and add the --with-generator option now:

    script/generate plugin yaffle --with-generator

You should see the following output:

    create  vendor/plugins/yaffle/lib
    create  vendor/plugins/yaffle/tasks
    create  vendor/plugins/yaffle/test
    create  vendor/plugins/yaffle/README
    create  vendor/plugins/yaffle/MIT-LICENSE
    create  vendor/plugins/yaffle/Rakefile
    create  vendor/plugins/yaffle/init.rb
    create  vendor/plugins/yaffle/install.rb
    create  vendor/plugins/yaffle/uninstall.rb
    create  vendor/plugins/yaffle/lib/yaffle.rb
    create  vendor/plugins/yaffle/tasks/yaffle_tasks.rake
    create  vendor/plugins/yaffle/test/core_ext_test.rb
    create  vendor/plugins/yaffle/generators
    create  vendor/plugins/yaffle/generators/yaffle
    create  vendor/plugins/yaffle/generators/yaffle/templates
    create  vendor/plugins/yaffle/generators/yaffle/yaffle_generator.rb
    create  vendor/plugins/yaffle/generators/yaffle/USAGE

For this plugin you won't need the file vendor/plugins/yaffle/lib/yaffle.rb so you can delete that.

    rm vendor/plugins/yaffle/lib/yaffle.rb

> Editor's note:  many plugin authors prefer to keep this file, and add all of the require statements in it.  That way, they only line in init.rb would be `require "yaffle"`
> If you are developing a plugin that has a lot of files in the lib directory, you may want to create a subdirectory like lib/yaffle and store your files in there.  That way your init.rb file stays clean

Setup the plugin for testing
------------------------

Testing plugins that use the entire Rails stack can be complex, and the generator doesn't offer any help.  In this tutorial you will learn how to test your plugin against multiple different adapters using ActiveRecord.  This tutorial will not cover how to use fixtures in plugin tests.

To setup your plugin to allow for easy testing you'll need to add 3 files:

* A database.yml file with all of your connection strings
* A schema.rb file with your table definitions
* A test helper that sets up the database before your tests

For this plugin you'll need 2 tables/models, Hickwalls and Wickwalls, so add the following files:

    # File: vendor/plugins/yaffle/test/database.yml

    sqlite:
      :adapter: sqlite
      :dbfile: yaffle_plugin.sqlite.db
    sqlite3:
      :adapter: sqlite3
      :dbfile: yaffle_plugin.sqlite3.db
    postgresql:
      :adapter: postgresql
      :username: postgres
      :password: postgres
      :database: yaffle_plugin_test
      :min_messages: ERROR
    mysql:
      :adapter: mysql
      :host: localhost
      :username: rails
      :password:
      :database: yaffle_plugin_test

    # File: vendor/plugins/yaffle/test/test_helper.rb

    ActiveRecord::Schema.define(:version => 0) do
      create_table :hickwalls, :force => true do |t|
        t.string :name
        t.string :last_squawk
        t.datetime :last_squawked_at
      end
      create_table :wickwalls, :force => true do |t|
        t.string :name
        t.string :last_tweet
        t.datetime :last_tweeted_at
      end
    end

    # File: vendor/plugins/yaffle/test/test_helper.rb

    ENV['RAILS_ENV'] = 'test'
    ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

    require 'test/unit'
    require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

    config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
    ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")

    db_adapter = ENV['DB']

    # no db passed, try one of these fine config-free DBs before bombing.
    db_adapter ||=
      begin
        require 'rubygems'
        require 'sqlite'
        'sqlite'
      rescue MissingSourceFile
        begin
          require 'sqlite3'
          'sqlite3'
        rescue MissingSourceFile
        end
      end

    if db_adapter.nil?
      raise "No DB Adapter selected. Pass the DB= option to pick one, or install Sqlite or Sqlite3."
    end

    ActiveRecord::Base.establish_connection(config[db_adapter])

    load(File.dirname(__FILE__) + "/schema.rb")

    require File.dirname(__FILE__) + '/../init.rb'

    class Hickwall < ActiveRecord::Base
      acts_as_yaffle
    end

    class Wickwall < ActiveRecord::Base
      acts_as_yaffle :yaffle_text_field => :last_tweet, :yaffle_date_field => :last_tweeted_at
    end

Add a `to_squawk` method to String
-----------------------

To update a core class you will have to:

* Write tests for the desired functionality
* Create a file for the code you wish to use
* Require that file from your init.rb

Most plugins store their code classes in the plugin's lib directory.  When you add a file to the lib directory, you must also require that file from init.rb.  The file you are going to add for this tutorial is `lib/core_ext.rb`

First, you need to write the tests.  Testing plugins is very similar to testing rails apps.  The generated test file should look something like this:

    # File: vendor/plugins/yaffle/test/core_ext_test.rb

    require 'test/unit'

    class CoreExtTest < Test::Unit::TestCase
      # Replace this with your real tests.
      def test_this_plugin
        flunk
      end
    end

Start off by removing the default test, and adding a require statement for your test helper.

    # File: vendor/plugins/yaffle/test/core_ext_test.rb

    require 'test/unit'
    require File.dirname(__FILE__) + '/test_helper.rb'

    class CoreExtTest < Test::Unit::TestCase
    end

Navigate to your plugin directory and run `rake test`

    cd vendor/plugins/yaffle
    rake test

Your test should fail with `no such file to load -- ./test/../lib/core_ext.rb (LoadError)` because we haven't created any file yet.  Create the file `lib/core_ext.rb` and re-run the tests.  You should see a different error message:

    1.) Failure ...
    No tests were specified

Great - now you are ready to start development.  The first thing we'll do is to add a method to String called `to_squawk` which will prefix the string with the word "squawk! ".  The test will look something like this:

    # File: vendor/plugins/yaffle/init.rb

    class CoreExtTest < Test::Unit::TestCase
      def test_string_should_respond_to_squawk
        assert_equal true, "".respond_to?(:to_squawk)
      end
      def test_string_prepend_empty_strings_with_the_word_squawk
        assert_equal "squawk!", "".to_squawk
      end
      def test_string_prepend_non_empty_strings_with_the_word_squawk
        assert_equal "squawk! Hello World", "Hello World".to_squawk
      end
    end

    # File: vendor/plugins/yaffle/init.rb

    require "core_ext"

    # File: vendor/plugins/yaffle/lib/core_ext.rb

    String.class_eval do
      def to_squawk
        "squawk! #{self}".strip
      end
    end

When monkey-patching existing classes it's often better to use `class_eval` instead of opening the class directly.

To test that your method does what it says it does, run the unit tests.  To test this manually, fire up a console and start squawking:

    script/console
    >> "Hello World".to_squawk
    => "squawk! Hello World"

If that worked, congratulations!  You just created your first test-driven plugin that extends a core ruby class.

Add an `acts_as_yaffle` method to ActiveRecord
-----------------------

A common pattern in plugins is to add a method called `acts_as_something` to models.  In this case, you want to write a method called `acts_as_yaffle` that adds a squawk method to your models.

To keep things clean, create a new test file called `acts_as_yaffle_test.rb` in your plugin's test directory and require your test helper.

    # File: vendor/plugins/yaffle/test/acts_as_yaffle_test.rb

    require File.dirname(__FILE__) + '/test_helper.rb'

    class Hickwall < ActiveRecord::Base
      acts_as_yaffle
    end

    class ActsAsYaffleTest < Test::Unit::TestCase
    end

    # File: vendor/plugins/lib/acts_as_yaffle.rb

    module Yaffle
    end

One of the most common plugin patterns for `acts_as_yaffle` plugins is to structure your file like so:

    module Yaffle
      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        # any method placed here will apply to classes, like Hickwall
        def acts_as_something
          send :include, InstanceMethods
        end
      end

      module InstanceMethods
        # any method placed here will apply to instaces, like @hickwall
      end
    end

With structure you can easily separate the methods that will be used for the class (like `Hickwall.some_method`) and the instance (like `@hickwell.some_method`).

Let's add class method named `acts_as_yaffle` - testing it out first.  You already defined the ActiveRecord models in your test helper, so if you run tests now they will fail.

Back in your `acts_as_yaffle` file, update ClassMethods like so:

    module ClassMethods
      def acts_as_yaffle(options = {})
        send :include, InstanceMethods
      end
    end

Now that test should pass.  Since your plugin is going to work with field names, you need to allow people to define the field names, in case there is a naming conflict.  You can write a few simple tests for this:

    # File: vendor/plugins/yaffle/test/acts_as_yaffle_test.rb

    require File.dirname(__FILE__) + '/test_helper.rb'

    class ActsAsYaffleTest < Test::Unit::TestCase
      def test_a_hickwalls_yaffle_text_field_should_be_last_squawk
        assert_equal "last_squawk", Hickwall.yaffle_text_field
      end
      def test_a_hickwalls_yaffle_date_field_should_be_last_squawked_at
        assert_equal "last_squawked_at", Hickwall.yaffle_date_field
      end
      def test_a_wickwalls_yaffle_text_field_should_be_last_tweet
        assert_equal "last_tweet", Wickwall.yaffle_text_field
      end
      def test_a_wickwalls_yaffle_date_field_should_be_last_tweeted_at
        assert_equal "last_tweeted_at", Wickwall.yaffle_date_field
      end
    end

To make these tests pass, you could modify your `acts_as_yaffle` file like so:

    # File: vendor/plugins/yaffle/lib/acts_as_yaffle.rb

    module Yaffle
      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def acts_as_yaffle(options = {})
          cattr_accessor :yaffle_text_field, :yaffle_date_field
          self.yaffle_text_field = (options[:yaffle_text_field] || :last_squawk).to_s
          self.yaffle_date_field = (options[:yaffle_date_field] || :last_squawked_at).to_s
          send :include, InstanceMethods
        end
      end

      module InstanceMethods
      end
    end

Now you can add tests for the instance methods, and the instance method itself:

    # File: vendor/plugins/yaffle/test/acts_as_yaffle_test.rb

    require File.dirname(__FILE__) + '/test_helper.rb'

    class ActsAsYaffleTest < Test::Unit::TestCase

      def test_a_hickwalls_yaffle_text_field_should_be_last_squawk
        assert_equal "last_squawk", Hickwall.yaffle_text_field
      end
      def test_a_hickwalls_yaffle_date_field_should_be_last_squawked_at
        assert_equal "last_squawked_at", Hickwall.yaffle_date_field
      end

      def test_a_wickwalls_yaffle_text_field_should_be_last_squawk
        assert_equal "last_tweet", Wickwall.yaffle_text_field
      end
      def test_a_wickwalls_yaffle_date_field_should_be_last_squawked_at
        assert_equal "last_tweeted_at", Wickwall.yaffle_date_field
      end

      def test_hickwalls_squawk_should_populate_last_squawk
        hickwall = Hickwall.new
        hickwall.squawk("Hello World")
        assert_equal "squawk! Hello World", hickwall.last_squawk
      end
      def test_hickwalls_squawk_should_populate_last_squawked_at
        hickwall = Hickwall.new
        hickwall.squawk("Hello World")
        assert_equal Date.today, hickwall.last_squawked_at
      end

      def test_wickwalls_squawk_should_populate_last_tweet
        wickwall = Wickwall.new
        wickwall.squawk("Hello World")
        assert_equal "squawk! Hello World", wickwall.last_tweet
      end
      def test_wickwalls_squawk_should_populate_last_tweeted_at
        wickwall = Wickwall.new
        wickwall.squawk("Hello World")
        assert_equal Date.today, wickwall.last_tweeted_at
      end
    end

    # File: vendor/plugins/yaffle/lib/acts_as_yaffle.rb

    module Yaffle
      def self.included(base)
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def acts_as_yaffle(options = {})
          cattr_accessor :yaffle_text_field, :yaffle_date_field
          self.yaffle_text_field = (options[:yaffle_text_field] || :last_squawk).to_s
          self.yaffle_date_field = (options[:yaffle_date_field] || :last_squawked_at).to_s
          send :include, InstanceMethods
        end
      end

      module InstanceMethods
        def squawk(string)
          write_attribute(self.class.yaffle_text_field, string.to_squawk)
          write_attribute(self.class.yaffle_date_field, Date.today)
        end
      end
    end

Note the use of write_attribute to write to the field in model.

Create a view helper
-----------------------

Creating a view helper is a 3-step process:

* Add an appropriately named file to the lib directory
* Require the file and hooks in init.rb
* Write the tests

First, create the test to define the functionality you want:

    # File: vendor/plugins/yaffle/test/view_helpers_test.rb

    require File.dirname(__FILE__) + '/test_helper.rb'
    include YaffleViewHelper

    class ViewHelpersTest < Test::Unit::TestCase
      def test_squawk_info_for_should_return_the_text_and_date
        time = Time.now
        hickwall = Hickwall.new
        hickwall.last_squawk = "Hello World"
        hickwall.last_squawked_at = time
        assert_equal "Hello World, #{time.to_s}", squawk_info_for(hickwall)
      end
    end

Then add the following statements to init.rb:

    # File: vendor/plugins/yaffle/init.rb

    require "view_helpers"
    ActionView::Base.send :include, YaffleViewHelper

Then add the view helpers file and

    # File: vendor/plugins/yaffle/lib/view_helpers.rb

    module YaffleViewHelper
      def squawk_info_for(yaffle)
        returning "" do |result|
          result << yaffle.read_attribute(yaffle.class.yaffle_text_field)
          result << ", "
          result << yaffle.read_attribute(yaffle.class.yaffle_date_field).to_s
        end
      end
    end

You can also test this in script/console by using the "helper" method:

    script/console
    >> helper.squawk_info_for(@some_yaffle_instance)

Create a migration generator
-----------------------

When you created the plugin above, you specified the --with-generator option, so you already have the generator stubs in your plugin.

We'll be relying on the built-in rails generate template for this tutorial.  Going into the details of generators is beyond the scope of this tutorial.

Type:

    script/generate

You should see the line:

    Plugins (vendor/plugins): yaffle

When you run `script/generate yaffle` you should see the contents of your USAGE file.  For this plugin, the USAGE file looks like this:

    Description:
        Creates a migration that adds yaffle squawk fields to the given model

    Example:
        ./script/generate yaffle hickwall

        This will create:
            db/migrate/TIMESTAMP_add_yaffle_fields_to_hickwall

Now you can add code to your generator:

    # File: vendor/plugins/yaffle/generators/yaffle/yaffle_generator.rb

    class YaffleGenerator < Rails::Generator::NamedBase
      def manifest
        record do |m|
          m.migration_template 'migration:migration.rb', "db/migrate", {:assigns => yaffle_local_assigns,
            :migration_file_name => "add_yaffle_fields_to_#{custom_file_name}"
          }
        end
      end

      private
        def custom_file_name
          custom_name = class_name.underscore.downcase
          custom_name = custom_name.pluralize if ActiveRecord::Base.pluralize_table_names
        end

        def yaffle_local_assigns
          returning(assigns = {}) do
            assigns[:migration_action] = "add"
            assigns[:class_name] = "add_yaffle_fields_to_#{custom_file_name}"
            assigns[:table_name] = custom_file_name
            assigns[:attributes] = [Rails::Generator::GeneratedAttribute.new("last_squawk", "string")]
            assigns[:attributes] << Rails::Generator::GeneratedAttribute.new("last_squawked_at", "datetime")
          end
        end
    end

Note that you need to be aware of whether or not table names are pluralized.

This does a few things:

* Reuses the built in rails migration_template method
* Reuses the built-in rails migration template

When you run the generator like

    script/generate yaffle bird

You will see a new file:

    # File: db/migrate/20080529225649_add_yaffle_fields_to_birds.rb

    class AddYaffleFieldsToBirds < ActiveRecord::Migration
      def self.up
        add_column :birds, :last_squawk, :string
        add_column :birds, :last_squawked_at, :datetime
      end

      def self.down
        remove_column :birds, :last_squawked_at
        remove_column :birds, :last_squawk
      end
    end

Add a custom generator command
------------------------

You may have noticed above that you can used one of the built-in rails migration commands `m.migration_template`.  You can create your own commands for these, using the following steps:

1. Add the require and hook statements to init.rb
2. Create the commands - creating 3 sets, Create, Destroy, List
3. Add the method to your generator

Working with the internals of generators is beyond the scope of this tutorial, but here is a basic example:

    # File: vendor/plugins/yaffle/init.rb

    require "commands"
    Rails::Generator::Commands::Create.send   :include,  Yaffle::Generator::Commands::Create
    Rails::Generator::Commands::Destroy.send  :include,  Yaffle::Generator::Commands::Destroy
    Rails::Generator::Commands::List.send     :include,  Yaffle::Generator::Commands::List

    # File: vendor/plugins/yaffle/lib/commands.rb

    require 'rails_generator'
    require 'rails_generator/commands'

    module Yaffle #:nodoc:
      module Generator #:nodoc:
        module Commands #:nodoc:
          module Create
            def yaffle_definition
              file("definition.txt", "definition.txt")
            end
          end

          module Destroy
            def yaffle_definition
              file("definition.txt", "definition.txt")
            end
          end

          module List
            def yaffle_definition
              file("definition.txt", "definition.txt")
            end
          end
        end
      end
    end

    # File: vendor/plugins/yaffle/generators/yaffle/templates/definition.txt

    Yaffle is a bird

    # File: vendor/plugins/yaffle/generators/yaffle/yaffle_generator.rb

    class YaffleGenerator < Rails::Generator::NamedBase
      def manifest
          m.yaffle_definition
        end
      end
    end

This example just uses the built-in "file" method, but you could do anything that ruby allows.

Add a Custom Route
------------------------

Testing routes in plugins can be complex, especially if the controllers are also in the plugin itself.  Jamis Buck showed a great example of this in [http://weblog.jamisbuck.org/2006/10/26/monkey-patching-rails-extending-routes-2](http://weblog.jamisbuck.org/2006/10/26/monkey-patching-rails-extending-routes-2)

    # File: vendor/plugins/yaffle/test/routing_test.rb

    require "#{File.dirname(__FILE__)}/test_helper"

    class RoutingTest < Test::Unit::TestCase

      def setup
        ActionController::Routing::Routes.draw do |map|
          map.yaffles
        end
      end

      def test_yaffles_route
        assert_recognition :get, "/yaffles", :controller => "yaffles_controller", :action => "index"
      end

      private

        # yes, I know about assert_recognizes, but it has proven problematic to
        # use in these tests, since it uses RouteSet#recognize (which actually
        # tries to instantiate the controller) and because it uses an awkward
        # parameter order.
        def assert_recognition(method, path, options)
          result = ActionController::Routing::Routes.recognize_path(path, :method => method)
          assert_equal options, result
        end
    end

    # File: vendor/plugins/yaffle/init.rb

    require "routing"
    ActionController::Routing::RouteSet::Mapper.send :include, Yaffle::Routing::MapperExtensions

    # File: vendor/plugins/yaffle/lib/routing.rb

    module Yaffle #:nodoc:
      module Routing #:nodoc:
        module MapperExtensions
          def yaffles
            @set.add_route("/yaffles", {:controller => "yaffles_controller", :action => "index"})
          end
        end
      end
    end

    # File: config/routes.rb

    ActionController::Routing::Routes.draw do |map|
      ...
      map.yaffles
    end

You can also see if your routes work by running `rake routes` from your app directory.

Generate RDoc Documentation
-----------------------

Once your plugin is stable, the tests pass on all database and you are ready to deploy do everyone else a favor and document it!  Luckily, writing documentation for your plugin is easy.

The first step is to update the README file with detailed information about how to use your plugin.  A few key things to include are:

* Your name
* How to install
* How to add the functionality to the app (several examples of common use cases)
* Warning, gotchas or tips that might help save users time

Once your README is solid, go through and add rdoc comments to all of the methods that developers will use.

Before you generate your documentation, be sure to go through and add nodoc comments to those modules and methods that are not important to your users.

Once your comments are good to go, navigate to your plugin directory and run

    rake rdoc

Work with init.rb
------------------------

The plugin initializer script init.rb is invoked via `eval` (not require) so it has slightly different behavior.

If you reopen any classes in init.rb itself your changes will potentially be made to the wrong module.  There are 2 ways around this:

The first way is to explicitly define the top-level module space for all modules and classes, like ::Hash

    # File: vendor/plugins/yaffle/init.rb

    class ::Hash
      def is_a_special_hash?
        true
      end
    end

OR you can use `module_eval` or `class_eval`

    # File: vendor/plugins/yaffle/init.rb

    Hash.class_eval do
      def is_a_special_hash?
        true
      end
    end

Store models, views, helpers, and controllers in your plugins
------------------------

You can easily store models, views, helpers and controllers in plugins.  Just create a folder for each in the lib folder, add them to the load path and remove them from the load once path:

    # File: vendor/plugins/yaffle/init.rb

    %w{ models controllers helpers }.each do |dir|
      path = File.join(directory, 'lib', dir)
      $LOAD_PATH << path
      Dependencies.load_paths << path
      Dependencies.load_once_paths.delete(path)
    end

Adding directories to the load path makes them appear just like files in the the main app directory - except that they are only loaded once, so you have to restart the web server to see the changes in the browser.

Adding directories to the load once paths allow those changes to picked up as soon as you save the file - without having to restart the web server.

Write custom rake tasks in your plugin
-------------------------

When you created the plugin with the built-in rails generator, it generated a rake file for you in `vendor/plugins/yaffle/tasks/yaffle.rake`.  Any rake task you add here will be available to the app.

Many plugin authors put all of their rake tasks into a common namespace that is the same as the plugin, like so:

    # File: vendor/plugins/yaffle/tasks/yaffle.rake

    namespace :yaffle do
      desc "Prints out the word 'Yaffle'"
      task :squawk => :environment do
        puts "squawk!"
      end
    end

When you run `rake -T` from your plugin you will see

  yaffle:squawk "Prints out..."

You can add as many files as you want in the tasks directory, and if they end in .rake Rails will pick them up.

Store plugins in alternate locations
-------------------------

You can store plugins wherever you want - you just have to add those plugins to the plugins path in environment.rb

Since the plugin is only loaded after the plugin paths are defined, you can't redefine this in your plugins - but it may be good to now.

You can even store plugins inside of other plugins for complete plugin madness!

    config.plugin_paths << File.join(RAILS_ROOT,"vendor","plugins","yaffle","lib","plugins")

Create your own Plugin Loaders and Plugin Locators
------------------------

If the built-in plugin behavior is inadequate, you can change almost every aspect of the location and loading process.  You can write your own plugin locators and plugin loaders, but that's beyond the scope of this tutorial.

Use Custom Plugin Generators
------------------------

If you are an RSpec fan, you can install the `rspec_plugin_generator`, which will generate the spec folder and database for you.

[http://github.com/pat-maddox/rspec-plugin-generator/tree/master](http://github.com/pat-maddox/rspec-plugin-generator/tree/master)

References
------------------------

* [http://nubyonrails.com/articles/the-complete-guide-to-rails-plugins-part-i](http://nubyonrails.com/articles/the-complete-guide-to-rails-plugins-part-i)
* [http://nubyonrails.com/articles/2006/05/09/the-complete-guide-to-rails-plugins-part-ii](http://nubyonrails.com/articles/2006/05/09/the-complete-guide-to-rails-plugins-part-ii)
* [http://github.com/technoweenie/attachment_fu/tree/master](http://github.com/technoweenie/attachment_fu/tree/master)
* [http://daddy.platte.name/2007/05/rails-plugins-keep-initrb-thin.html](http://daddy.platte.name/2007/05/rails-plugins-keep-initrb-thin.html)

Appendices
------------------------

The final plugin should have a directory structure that looks something like this:

    |-- MIT-LICENSE
    |-- README
    |-- Rakefile
    |-- generators
    |   `-- yaffle
    |       |-- USAGE
    |       |-- templates
    |       |   `-- definition.txt
    |       `-- yaffle_generator.rb
    |-- init.rb
    |-- install.rb
    |-- lib
    |   |-- acts_as_yaffle.rb
    |   |-- commands.rb
    |   |-- core_ext.rb
    |   |-- routing.rb
    |   `-- view_helpers.rb
    |-- tasks
    |   `-- yaffle_tasks.rake
    |-- test
    |   |-- acts_as_yaffle_test.rb
    |   |-- core_ext_test.rb
    |   |-- database.yml
    |   |-- debug.log
    |   |-- routing_test.rb
    |   |-- schema.rb
    |   |-- test_helper.rb
    |   `-- view_helpers_test.rb
    |-- uninstall.rb
    `-- yaffle_plugin.sqlite3.db
