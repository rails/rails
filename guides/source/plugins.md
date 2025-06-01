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

Testing Your Newly Generated Plugin
-----------------------------------

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

In this example you will add a method to String named `to_throttled_response`. To begin, create a new test file with a few assertions:

```ruby
# api_boost/test/core_ext_test.rb

require "test_helper"

class CoreExtTest < ActiveSupport::TestCase
  def test_to_throttled_response_adds_rate_limit_header
    response_data = "Hello API"
    expected = { data: "Hello API", rate_limit: "60 requests per hour" }
    assert_equal expected, response_data.to_throttled_response
  end
end
```

Run `bin/test` to run the test. This test should fail because we haven't implemented the `to_throttled_response` method:

```bash
$ bin/test
E

Error:
CoreExtTest#test_to_throttled_response_adds_rate_limit_header:
NoMethodError: undefined method `to_throttled_response' for "Hello API":String


bin/test /path/to/api_boost/test/core_ext_test.rb:4

.

Finished in 0.003358s, 595.6483 runs/s, 297.8242 assertions/s.
2 runs, 1 assertions, 0 failures, 1 errors, 0 skips
```

Great - now you are ready to start development.

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

Finally, create the `core_ext.rb` file and add the `to_throttled_response` method:

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

To test that your method does what it says it does, run the unit tests with `bin/test` from your plugin directory.

```bash
$ bin/test
...
2 runs, 2 assertions, 0 failures, 0 errors, 0 skips
```

To see this in action, change to the `test/dummy` directory, start `bin/rails console`, and test the API response formatting:

```irb
irb> "Hello API".to_throttled_response
=> {:data=>"Hello API", :rate_limit=>"60 requests per hour"}
```

Add an "acts_as" Method to Active Record
----------------------------------------

A common pattern in plugins is to add a method called `acts_as_something` to models. In this case, you
want to write a method called `acts_as_api_resource` that adds API-specific functionality to your Active Record models.

To begin, set up your files so that you have:

```ruby
# api_boost/test/acts_as_api_resource_test.rb

require "test_helper"

class ActsAsApiResourceTest < ActiveSupport::TestCase
end
```

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
  end
end
```

### Add a Class Method

This plugin will expect that you've added a method to your model named `last_request_at`. However, the
plugin users might have already defined a method on their model named `last_request_at` that they use
for something else. This plugin will allow the name to be changed by adding a class method called `api_timestamp_field`.

To start out, write a failing test that shows the behavior you'd like:

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
end
```

When you run `bin/test`, you should see the following:

```bash
$ bin/test
# Running:

..E

Error:
ActsAsApiResourceTest#test_a_products_api_timestamp_field_should_be_last_api_call:
NameError: uninitialized constant ActsAsApiResourceTest::Product


bin/test /path/to/api_boost/test/acts_as_api_resource_test.rb:8

E

Error:
ActsAsApiResourceTest#test_a_users_api_timestamp_field_should_be_last_request_at:
NameError: uninitialized constant ActsAsApiResourceTest::User


bin/test /path/to/api_boost/test/acts_as_api_resource_test.rb:4



Finished in 0.004812s, 831.2949 runs/s, 415.6475 assertions/s.
4 runs, 2 assertions, 0 failures, 2 errors, 0 skips
```

This tells us that we don't have the necessary models (User and Product) that we are trying to test.
We can easily generate these models in our "dummy" Rails application by running the following commands from the
`test/dummy` directory:

```bash
$ cd test/dummy
$ bin/rails generate model User last_request_at:datetime
$ bin/rails generate model Product last_request_at:datetime last_api_call:datetime
```

Now you can create the necessary database tables in your testing database by navigating to your dummy app
and migrating the database. First, run:

```bash
$ cd test/dummy
$ bin/rails db:migrate
```

While you are here, change the User and Product models so that they know that they are supposed to act
like API resources.

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

We will also add code to define the `acts_as_api_resource` method.

```ruby
# api_boost/lib/api_boost/acts_as_api_resource.rb

module ApiBoost
  module ActsAsApiResource
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_api_resource(options = {})
      end
    end
  end
end
```

```ruby
# test/dummy/app/models/application_record.rb

class ApplicationRecord < ActiveRecord::Base
  include ApiBoost::ActsAsApiResource

  self.abstract_class = true
end
```

You can then return to the root directory (`cd ../..`) of your plugin and rerun the tests using `bin/test`.

```bash
$ bin/test
# Running:

.E

Error:
ActsAsApiResourceTest#test_a_users_api_timestamp_field_should_be_last_request_at:
NoMethodError: undefined method `api_timestamp_field' for #<Class:0x0055974ebbe9d8>


bin/test /path/to/api_boost/test/acts_as_api_resource_test.rb:4

E

Error:
ActsAsApiResourceTest#test_a_products_api_timestamp_field_should_be_last_api_call:
NoMethodError: undefined method `api_timestamp_field' for #<Class:0x0055974eb8cfc8>


bin/test /path/to/api_boost/test/acts_as_api_resource_test.rb:8

.

Finished in 0.008263s, 484.0999 runs/s, 242.0500 assertions/s.
4 runs, 2 assertions, 0 failures, 2 errors, 0 skips
```

Getting closer... Now we will implement the code of the `acts_as_api_resource` method to make the tests pass.

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

```ruby
# test/dummy/app/models/application_record.rb

class ApplicationRecord < ActiveRecord::Base
  include ApiBoost::ActsAsApiResource

  self.abstract_class = true
end
```

When you run `bin/test`, you should see the tests all pass:

```bash
$ bin/test
...
4 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

### Add an Instance Method

This plugin will add a method named 'track_api_request' to any Active Record object that calls `acts_as_api_resource`. The 'track_api_request'
method will simply set the timestamp of when an API request was made to track usage patterns.

To start out, write a failing test that shows the behavior you'd like:

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

Run the test to make sure the last two tests fail with an error that contains "NoMethodError: undefined method \`track_api_request'",
then update `acts_as_api_resource.rb` to look like this:

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

```ruby
# test/dummy/app/models/application_record.rb

class ApplicationRecord < ActiveRecord::Base
  include ApiBoost::ActsAsApiResource

  self.abstract_class = true
end
```

Run `bin/test` one final time, and you should see:

```bash
$ bin/test
...
6 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

NOTE: The use of `write_attribute` to write to the field in model is just one example of how a plugin can interact with the model, and will not always be the right method to use. For example, you could also use:

```ruby
send("#{self.class.api_timestamp_field}=", timestamp)
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