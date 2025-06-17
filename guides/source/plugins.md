**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

The Basics of Creating Rails Plugins
====================================

This guide is for developers who want to create a Rails plugin, in order to extend or modify the behavior of a Rails application.

After reading this guide, you will know:

* What Rails plugins are.
* When to use a Rails plugin.
* How to create a plugin from scratch.
* How to extend core Ruby classes.
* How to add methods to `ApplicationRecord`.
* How to publish your plugin to RubyGems.

--------------------------------------------------------------------------------

What are Plugins?
-----------------

A Rails plugin is a gem that's designed specifically to work inside a Rails
application, often using `Railtie` or `Engine` to hook into the Rails boot
process and extend the framework's functionality.

Plugins serve several purposes:

* They offer a way for developers to experiment with new ideas without affecting the stability of the core codebase.
* They support a modular architecture, allowing features to be maintained, updated, or released independently.
* They give teams an outlet for introducing powerful features without needing to
  include everything directly into the framework.

Generator Options
------------------

Rails plugins are built as gems, _gemified plugins_. They can be
shared across different Rails applications using RubyGems and Bundler if
desired.

The `rails plugin new` command supports several options that determine what type of plugin structure is generated.

The **Basic Plugin** (default) option creates a minimal plugin structure suitable for simple extensions like core class methods or utility functions.

```bash
$ rails plugin new api_boost
```

This is what we'll use in this guide.

The **Full Plugin** (`--full`) option creates a more complete plugin structure that includes an `app` directory tree (models, views, controllers), a `config/routes.rb` file, and an Engine class at `lib/api_boost/engine.rb`.

```bash
$ rails plugin new api_boost --full
```

Use `--full` when your plugin needs its own models, controllers, or views but doesn't require namespace isolation.

The **Mountable Engine** (`--mountable`) option creates a fully isolated, mountable engine that includes everything from `--full` plus:
- Namespace isolation (`ApiBoost::` prefix for all classes)
- Isolated routing (`ApiBoost::Engine.routes.draw`)
- Asset manifest files
- Namespaced ApplicationController and ApplicationHelper
- Automatic mounting in the dummy app for testing

```bash
$ rails plugin new api_boost --mountable
```

Use `--mountable` when building a self-contained feature that could work as a separate application.

For more information about engines, see the [Getting Started with Engines guide](engines.html).

Below is some guidance on choosing the right option:

- **Basic plugin**: Simple utilities, core class extensions, or small helper methods
- **`--full` plugin**: Complex functionality that needs models/controllers but shares the host app's namespace
- **`--mountable` engine**: Self-contained features like admin panels, blogs, or API modules

See usage and options by asking for help:

```bash
$ rails plugin new --help
```

Setup
------

For the purpose of this guide, imagine you're building APIs and want to create a plugin that adds common API functionality like request throttling, response caching, and automatic API documentation. You'll create a plugin called "ApiBoost" that can enhance any Rails API application.

### Generate the Plugin

Create a basic plugin with the command:

```bash
$ rails plugin new api_boost
```

This will create the ApiBoost plugin in a directory named `api_boost`. Let's examine what was generated:

```
api_boost/
├── api_boost.gemspec
├── Gemfile
├── lib/
│   ├── api_boost/
│   │   └── version.rb
│   ├── api_boost.rb
│   └── tasks/
│       └── api_boost_tasks.rake
├── test/
│   ├── dummy/
│   │   ├── app/
│   │   ├── bin/
│   │   ├── config/
│   │   ├── db/
│   │   ├── public/
│   │   └── ... (full Rails application)
│   ├── integration/
│   └── test_helper.rb
├── MIT-LICENSE
└── README.md
```

**The `lib` directory** contains your plugin's source code:
- `lib/api_boost.rb` is the main entry point for your plugin
- `lib/api_boost/` contains modules and classes for your plugin functionality
- `lib/tasks/` contains any Rake tasks your plugin provides

**The `test/dummy` directory** contains a complete Rails application that's used for testing your plugin. This dummy application:
- Loads your plugin automatically through the Gemfile
- Provides a Rails environment to test your plugin's integration
- Includes generators, models, controllers, and views as needed for testing
- Can be used interactively with `rails console` and `rails server`

**The gemspec file** (`api_boost.gemspec`) defines your gem's metadata, dependencies, and which files to include when packaging.


### Set Up the Plugin

Navigate to the directory that contains the plugin, and edit `api_boost.gemspec` to
replace any lines that have `TODO` values:

```ruby
spec.homepage    = "http://example.com"
spec.summary     = "Enhance your API endpoints"
spec.description = "Adds common API functionality like request throttling, response caching, and automatic API documentation."

...

spec.metadata["source_code_uri"] = "http://example.com"
spec.metadata["changelog_uri"] = "http://example.com"
```

Then run the `bundle install` command.

After that, set up your testing database by navigating to the `test/dummy` directory and running the following command:

```bash
$ cd test/dummy
$ bin/rails db:create
```

The dummy application works just like any Rails application - you can generate models, run migrations, start the server, or open a console. This is where you'll test your plugin's functionality as you develop it.

Once the database is created, return to the plugin's root directory (`cd ../..`).

Now you can run the tests using the `bin/test` command, and you should see:

```bash
$ bin/test
...
1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
```

This will tell you that everything got generated properly, and you are ready to start adding functionality.

Extending Core Classes
----------------------

This section will explain how to add a method to String that will be available anywhere in your Rails application.

WARNING: Before proceeding, it's important to understand that extending core
classes (like String, Array, Hash, etc.) should be used sparingly, if at all.
Core class extensions can be brittle, dangerous, and are often
unnecessary.<br></br> They can:</br>
- Cause naming conflicts when multiple gems extend the same class with the same
  method name</br>
- Break unexpectedly when Ruby or Rails updates change core class behavior</br>
- Make debugging difficult because it's not obvious where methods come from</br>
- Create coupling issues between your plugin and other code<br></br> Better
alternatives to consider:</br>
- Create utility modules or helper classes instead</br>
- Use composition over monkey patching</br>
- Implement functionality as instance methods on your own classes<br></br> For
more details on why core class extensions can be problematic, see [The Case
Against Monkey
Patching](https://shopify.engineering/the-case-against-monkey-patching).
<br></br> That said, understanding how core class extensions work is valuable.
The example below demonstrates the technique, but they should be used sparingly
- consider whether it's the right approach for your specific use case.

In this example you will add a method to Integer named `requests_per_hour`.

In `lib/api_boost.rb`, add `require "api_boost/core_ext"`:

```ruby
# api_boost/lib/api_boost.rb

require "api_boost/version"
require "api_boost/railtie"
require "api_boost/core_ext"

module ApiBoost
  # Your code goes here...
end
```

Create the `core_ext.rb` file and add a method to Integer to define a RateLimit that could define `10.requests_per_hour`, similar to `10.hours` that returns a Time.

```ruby
# api_boost/lib/api_boost/core_ext.rb

ApiBoost::RateLimit = Data.define(:requests, :per)

class Integer
  def requests_per_hour
    ApiBoost::RateLimit.new(self, :hour)
  end
end
```

To see this in action, change to the `test/dummy` directory, start `bin/rails console`, and test the API response formatting:

```bash
$ cd test/dummy
$ bin/rails console
```

```irb
irb> 10.requests_per_hour
=> #<struct ApiBoost::RateLimit requests=10, per=:hour>
```

The dummy application automatically loads your plugin, so any extensions you add are immediately available for testing.

Add an "acts_as" Method to Active Record
----------------------------------------

A common pattern in plugins is to add a method called `acts_as_something` to models. In this case, you
want to write a method called `acts_as_api_resource` that adds API-specific functionality to your Active Record models.

To begin, set up your files so that you have:

```ruby
# api_boost/lib/api_boost.rb

require "api_boost/version"
require "api_boost/railtie"
require "api_boost/core_ext"
require "api_boost/acts_as_api_resource"

module ApiBoost
  # Your code goes here...
end
```

```ruby
# api_boost/lib/api_boost/acts_as_api_resource.rb

module ApiBoost
  module ActsAsApiResource
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_api_resource(api_timestamp_field: :last_request_at)
        # Create a class-level setting that stores which field to use for the API timestamp.
        cattr_accessor :api_timestamp_field, default: api_timestamp_field.to_s
      end
    end
  end
end
```

The code above uses `ActiveSupport::Concern` to simplify including modules with both class and instance methods. Methods in the `class_methods` block become class methods when the module is included. For more details, see the [ActiveSupport::Concern API documentation](https://api.rubyonrails.org/classes/ActiveSupport/Concern.html).

### Add a Class Method

By default, this plugin expects your model to have a column named `last_request_at`. However, since that column name might already be used for something else, the plugin lets you customize it. You can override the default by passing a different column name with the `api_timestamp_field: option`. Internally, this value is stored in a class-level setting called `api_timestamp_field`, which the plugin uses when updating the timestamp.

For example, if you want to use `last_api_call` instead of `last_request_at` as the column name, you can do the following:

First, generate some models in your "dummy" Rails application to test this functionality. Run the following commands from the `test/dummy` directory:

```bash
$ cd test/dummy
$ bin/rails generate model Product last_request_at:datetime last_api_call:datetime
$ bin/rails db:migrate
```

Now update the Product model so that it acts like an API resource:

```ruby
# test/dummy/app/models/product.rb

class Product < ApplicationRecord
  acts_as_api_resource api_timestamp_field: :last_api_call
end
```

To make the plugin available to all models, include the module in `ApplicationRecord` (we'll look at doing this automatically later):

```ruby
# test/dummy/app/models/application_record.rb

class ApplicationRecord < ActiveRecord::Base
  include ApiBoost::ActsAsApiResource

  self.abstract_class = true
end
```

Now you can test this functionality in the Rails console:

```irb
irb> Product.api_timestamp_field
=> "last_api_call"
```

### Add an Instance Method

This plugin adds an instance method called `track_api_request` to any Active Record model that calls `acts_as_api_resource`. This method sets the value of the configured timestamp field to the current time (or a custom time if provided), allowing you to track when an API request was made.

To add this behavior, update `acts_as_api_resource.rb`:

```ruby
# api_boost/lib/api_boost/acts_as_api_resource.rb

module ApiBoost
  module ActsAsApiResource
    extend ActiveSupport::Concern

    included do
      def track_api_request(timestamp = Time.current)
        write_attribute(self.class.api_timestamp_field, timestamp)
      end
    end

    class_methods do
      def acts_as_api_resource(options = {})
        cattr_accessor :api_timestamp_field, default: (options[:api_timestamp_field] || :last_request_at).to_s
      end
    end
  end
end
```

Now you can test the functionality in the Rails console:

```irb
irb> product = Product.new
irb> product.track_api_request
irb> product.last_api_call
=> 2025-06-01 10:31:15 UTC
```

NOTE: The use of `write_attribute` to write to the field in model is just one example of how a plugin can interact with the model, and will not always be the right method to use. For example, you might prefer using `send`, which calls the setter method

```ruby
send("#{self.class.api_timestamp_field}=", timestamp)
```

Advanced Integration: Using Railties
------------------------------------

The plugin we've built so far works great for basic functionality. However, if your plugin needs to integrate more deeply with Rails' framework, you'll want to use a [Railtie](https://api.rubyonrails.org/classes/Rails/Railtie.html).

A Railtie is required when your plugin needs to:

* Add configuration options accessible via `Rails.application.config`
* Automatically include modules in Rails classes without manual setup
* Provide Rake tasks to the host application
* Set up initializers that run during Rails boot
* Add middleware to the application stack
* Configure Rails generators
* Subscribe to `ActiveSupport::Notifications`

For simple plugins like ours that only extend core classes or add modules, a Railtie isn't necessary.

### Configuration Options

Let's say you want to make the default rate limit in your `to_throttled_response` method configurable. First, create a Railtie:

```ruby
# api_boost/lib/api_boost/railtie.rb

module ApiBoost
  class Railtie < Rails::Railtie
    config.api_boost = ActiveSupport::OrderedOptions.new
    config.api_boost.default_rate_limit = "60 requests per hour"

    initializer "api_boost.configure" do |app|
      ApiBoost.configuration = app.config.api_boost
    end
  end
end
```

Add a configuration module to your plugin:

```ruby
# api_boost/lib/api_boost/configuration.rb

module ApiBoost
  mattr_accessor :configuration, default: nil

  def self.configure
    yield(configuration) if block_given?
  end
end
```

Update your core extension to use the configuration:

```ruby
# api_boost/lib/api_boost/core_ext.rb

class String
  def to_throttled_response(limit = nil)
    default_limit = ApiBoost.configuration&.default_rate_limit || "60 requests per hour"
    {
      data: self,
      rate_limit: limit || default_limit
    }
  end
end
```

Require the new files in your main plugin file:

```ruby
# api_boost/lib/api_boost.rb

require "api_boost/version"
require "api_boost/configuration"
require "api_boost/railtie"
require "api_boost/core_ext"
require "api_boost/acts_as_api_resource"

module ApiBoost
  # Your code goes here...
end
```

Now applications using your plugin can configure it:

```ruby
# config/application.rb
config.api_boost.default_rate_limit = "100 requests per hour"
```

### Automatic Module Inclusion

Instead of requiring users to manually include `ActsAsApiResource` in their `ApplicationRecord`, you can use a Railtie to do it automatically:

```ruby
# api_boost/lib/api_boost/railtie.rb

module ApiBoost
  class Railtie < Rails::Railtie
    config.api_boost = ActiveSupport::OrderedOptions.new
    config.api_boost.default_rate_limit = "60 requests per hour"

    initializer "api_boost.configure" do |app|
      ApiBoost.configuration = app.config.api_boost
    end

    initializer "api_boost.active_record" do
      ActiveSupport.on_load(:active_record) do
        include ApiBoost::ActsAsApiResource
      end
    end
  end
end
```

The `ActiveSupport.on_load` hook ensures your module is included at the right time during Rails initialization, after ActiveRecord is fully loaded.

### Rake Tasks

To provide Rake tasks to applications using your plugin:

```ruby
# api_boost/lib/api_boost/railtie.rb

module ApiBoost
  class Railtie < Rails::Railtie
    # ... existing configuration ...

    rake_tasks do
      load "tasks/api_boost_tasks.rake"
    end
  end
end
```

Create the Rake task file:

```ruby
# api_boost/lib/tasks/api_boost_tasks.rake

namespace :api_boost do
  desc "Show API usage statistics"
  task stats: :environment do
    puts "API Boost Statistics:"
    puts "Models using acts_as_api_resource: #{api_resource_models.count}"
  end

  def api_resource_models
    ApplicationRecord.descendants.select do |model|
      model.respond_to?(:api_timestamp_field)
    end
  end
end
```

Applications using your plugin will now have access to `rails api_boost:stats`.

### Testing the Railtie

You can test that your Railtie works correctly in the dummy application:

```ruby
# api_boost/test/railtie_test.rb

require "test_helper"

class RailtieTest < ActiveSupport::TestCase
  def test_configuration_is_available
    assert_not_nil ApiBoost.configuration
    assert_equal "60 requests per hour", ApiBoost.configuration.default_rate_limit
  end

  def test_acts_as_api_resource_is_automatically_included
    # Test that ActsAsApiResource was automatically included
    assert User.respond_to?(:acts_as_api_resource)
    assert Product.respond_to?(:acts_as_api_resource)
  end

  def test_rake_tasks_are_loaded
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("api_boost:stats")
  end
end
```

Railties provide a clean way to integrate your plugin with Rails' initialization process. For more details about how Rails initializes and the complete lifecycle, see the [Rails Initialization Process Guide](initialization.html).

Testing Your Plugin
-------------------

Now that your plugin is working, it's good practice to add tests. The Rails plugin generator created a test framework for you. Let's add tests for the functionality we just built.

### Testing Core Extensions

Create a test file for your core extensions:

```ruby
# api_boost/test/core_ext_test.rb

require "test_helper"

class CoreExtTest < ActiveSupport::TestCase
  def test_to_throttled_response_adds_rate_limit_header
    response_data = "Hello API"
    expected = { data: "Hello API", rate_limit: "60 requests per hour" }
    assert_equal expected, response_data.to_throttled_response
  end

  def test_to_throttled_response_with_custom_limit
    response_data = "User data"
    expected = { data: "User data", rate_limit: "100 requests per hour" }
    assert_equal expected, response_data.to_throttled_response("100 requests per hour")
  end
end
```

### Testing Acts As Methods

Create a test file for your ActsAs functionality:

```ruby
# api_boost/test/acts_as_api_resource_test.rb

require "test_helper"

class ActsAsApiResourceTest < ActiveSupport::TestCase
  def test_a_users_api_timestamp_field_should_be_last_request_at
    assert_equal "last_request_at", User.api_timestamp_field
  end

  def test_a_products_api_timestamp_field_should_be_last_api_call
    assert_equal "last_api_call", Product.api_timestamp_field
  end

  def test_users_track_api_request_should_populate_last_request_at
    user = User.new
    freeze_time = Time.current
    Time.stub(:current, freeze_time) do
      user.track_api_request
      assert_equal freeze_time.to_s, user.last_request_at.to_s
    end
  end

  def test_products_track_api_request_should_populate_last_api_call
    product = Product.new
    freeze_time = Time.current
    Time.stub(:current, freeze_time) do
      product.track_api_request
      assert_equal freeze_time.to_s, product.last_api_call.to_s
    end
  end
end
```

Run your tests to make sure everything is working:

```bash
$ bin/test
...
6 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

Generators
----------

Generators can be included in your gem simply by creating them in a `lib/generators` directory of your plugin. More information about
the creation of generators can be found in the [Generators Guide](generators.html).

Publishing Your Gem
-------------------

Gem plugins currently in development can easily be shared from any Git repository. To share the ApiBoost gem with others, simply
commit the code to a Git repository (like GitHub) and add a line to the `Gemfile` of the application in question:

```ruby
gem "api_boost", git: "https://github.com/rails/api_boost.git"
```

After running `bundle install`, your gem functionality will be available to the application.

When the gem is ready to be shared as a formal release, it can be published to [RubyGems](https://rubygems.org).

Alternatively, you can benefit from Bundler's Rake tasks. You can see a full list with the following:

```bash
$ bundle exec rake -T

$ bundle exec rake build
# Build api_boost-0.1.0.gem into the pkg directory

$ bundle exec rake install
# Build and install api_boost-0.1.0.gem into system gems

$ bundle exec rake release
# Create tag v0.1.0 and build and push api_boost-0.1.0.gem to Rubygems
```

For more information about publishing gems to RubyGems, see: [Publishing your gem](https://guides.rubygems.org/publishing).

RDoc Documentation
------------------

Once your plugin is stable, and you are ready to deploy, do everyone else a favor and document it! Luckily, writing documentation for your plugin is easy.

The first step is to update the README file with detailed information about how to use your plugin. A few key things to include are:

* Your name
* How to install
* How to add the functionality to the app (several examples of common use cases)
* Warnings, gotchas or tips that might help users and save them time

Once your README is solid, go through and add RDoc comments to all the methods that developers will use. It's also customary to add `# :nodoc:` comments to those parts of the code that are not included in the public API.

Once your comments are good to go, navigate to your plugin directory and run:

```bash
$ bundle exec rake rdoc
```

### References

* [Developing a RubyGem using Bundler](https://bundler.io/guides/creating_gem.html)
* [Using .gemspecs as Intended](https://yehudakatz.com/2010/04/02/using-gemspecs-as-intended/)
* [Gemspec Reference](https://guides.rubygems.org/specification-reference/)