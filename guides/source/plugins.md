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
------------------

A Rails plugin is a gem that's designed specifically to work inside a Rails
application, often using `Railtie` or `Engine` to hook into the Rails boot
process and extend the framework's functionality.

Plugins serve several purposes:

* They offer a way for developers to experiment with new ideas without affecting the stability of the core codebase.
* They support a modular architecture, allowing features to be maintained, updated, or released independently.
* They give teams an outlet for introducing powerful features without needing to
  include everything directly into the framework.

Setup
-----

Currently, Rails plugins are built as gems, _gemified plugins_. They can be
shared across different Rails applications using RubyGems and Bundler if
desired.

For the purpose of this guide, imagine you're building APIs and want to create a plugin that adds common API functionality like request throttling, response caching, and automatic API documentation. You'll create a plugin called "ApiBoost" that can enhance any Rails API application.

### Generate a Gemified Plugin

Rails ships with a `rails plugin new` command which creates a
skeleton for developing any kind of Rails extension with the ability
to run integration tests using a dummy Rails application. Create your
plugin with the command:

```bash
$ rails plugin new api_boost
```

See usage and options by asking for help:

```bash
$ rails plugin new --help
```

Setting Up Your Plugin
----------------------

Navigate to the directory that contains the plugin, and edit `api_boost.gemspec` to
replace any lines that have `TODO` values:

```ruby
spec.homepage    = "http://example.com"
spec.summary     = "Summary of ApiBoost."
spec.description = "Description of ApiBoost."

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

In this example you will add a method to String named `to_throttled_response`.

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

Create the `core_ext.rb` file and add the `to_throttled_response` method:

```ruby
# api_boost/lib/api_boost/core_ext.rb

class String
  def to_throttled_response(limit = "60 requests per hour")
    {
      data: self,
      rate_limit: limit
    }
  end
end
```

To see this in action, change to the `test/dummy` directory, start `bin/rails console`, and test the API response formatting:

```irb
irb> "Hello API".to_throttled_response
=> {:data=>"Hello API", :rate_limit=>"60 requests per hour"}

irb> "User data".to_throttled_response("100 requests per hour")
=> {:data=>"User data", :rate_limit=>"100 requests per hour"}
```

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
      def acts_as_api_resource(options = {})
        cattr_accessor :api_timestamp_field, default: (options[:api_timestamp_field] || :last_request_at).to_s
      end
    end
  end
end
```

### Add a Class Method

This plugin will expect that you've added a method to your model named `last_request_at`. However, the
plugin users might have already defined a method on their model named `last_request_at` that they use
for something else. This plugin will allow the name to be changed by adding a class method called `api_timestamp_field`.

We need to generate some models in our "dummy" Rails application to test this functionality. Run the following commands from the `test/dummy` directory:

```bash
$ cd test/dummy
$ bin/rails generate model User last_request_at:datetime
$ bin/rails generate model Product last_request_at:datetime last_api_call:datetime
$ bin/rails db:migrate
```

Now update the User and Product models so that they know that they are supposed to act like API resources:

```ruby
# test/dummy/app/models/user.rb

class User < ApplicationRecord
  acts_as_api_resource
end
```

```ruby
# test/dummy/app/models/product.rb

class Product < ApplicationRecord
  acts_as_api_resource api_timestamp_field: :last_api_call
end
```

We need to include our module in `ApplicationRecord`:

```ruby
# test/dummy/app/models/application_record.rb

class ApplicationRecord < ActiveRecord::Base
  include ApiBoost::ActsAsApiResource

  self.abstract_class = true
end
```

Now you can test this functionality in the Rails console:

```irb
irb> User.api_timestamp_field
=> "last_request_at"

irb> Product.api_timestamp_field
=> "last_api_call"
```

### Add an Instance Method

This plugin will add a method named 'track_api_request' to any Active Record object that calls `acts_as_api_resource`. The 'track_api_request'
method will set the timestamp of when an API request was made to track usage patterns.

Update `acts_as_api_resource.rb` to include the instance method:

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
irb> user = User.new
irb> user.track_api_request
irb> user.last_request_at
=> 2025-06-01 10:30:45 UTC

irb> product = Product.new
irb> product.track_api_request
irb> product.last_api_call
=> 2025-06-01 10:31:15 UTC
```

NOTE: The use of `write_attribute` to write to the field in model is just one example of how a plugin can interact with the model, and will not always be the right method to use. For example, you could also use:

```ruby
send("#{self.class.api_timestamp_field}=", timestamp)
```

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