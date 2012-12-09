The Basics of Creating Rails Plugins
====================================

A Rails plugin is either an extension or a modification of the core framework. Plugins provide:

* a way for developers to share bleeding-edge ideas without hurting the stable code base
* a segmented architecture so that units of code can be fixed or updated on their own release schedule
* an outlet for the core developers so that they don’t have to include every cool new feature under the sun

After reading this guide, you will know:

* How to create a plugin from scratch.
* How to write and run tests for the plugin.

This guide describes how to build a test-driven plugin that will:

* Extend core Ruby classes like Hash and String.
* Add methods to ActiveRecord::Base in the tradition of the 'acts_as' plugins.
* Give you information about where to put generators in your plugin.

For the purpose of this guide pretend for a moment that you are an avid bird watcher.
Your favorite bird is the Yaffle, and you want to create a plugin that allows other developers to share in the Yaffle
goodness.

--------------------------------------------------------------------------------

Setup
-----

Currently, Rails plugins are built as gems, _gemified plugins_. They can be shared across
different rails applications using RubyGems and Bundler if desired.

### Generate a gemified plugin.


Rails ships with a `rails plugin new` command which creates a
 skeleton for developing any kind of Rails extension with the ability
 to run integration tests using a dummy Rails application. See usage
 and options by asking for help:

```bash
$ rails plugin --help
```

Testing your newly generated plugin
-----------------------------------

You can navigate to the directory that contains the plugin, run the `bundle install` command
 and run the one generated test using the `rake` command.

You should see:

```bash
  2 tests, 2 assertions, 0 failures, 0 errors, 0 skips
```

This will tell you that everything got generated properly and you are ready to start adding functionality.

Extending Core Classes
----------------------

This section will explain how to add a method to String that will be available anywhere in your rails application.

In this example you will add a method to String named `to_squawk`. To begin, create a new test file with a few assertions:

```ruby
# yaffle/test/core_ext_test.rb

require 'test_helper'

class CoreExtTest < Test::Unit::TestCase
  def test_to_squawk_prepends_the_word_squawk
    assert_equal "squawk! Hello World", "Hello World".to_squawk
  end
end
```

Run `rake` to run the test. This test should fail because we haven't implemented the `to_squawk` method:

```bash
    1) Error:
  test_to_squawk_prepends_the_word_squawk(CoreExtTest):
  NoMethodError: undefined method `to_squawk' for [Hello World](String)
      test/core_ext_test.rb:5:in `test_to_squawk_prepends_the_word_squawk'
```

Great - now you are ready to start development.

Then in `lib/yaffle.rb` require `lib/core_ext`:

```ruby
# yaffle/lib/yaffle.rb

require "yaffle/core_ext"

module Yaffle
end
```

Finally, create the `core_ext.rb` file and add the `to_squawk` method:

```ruby
# yaffle/lib/yaffle/core_ext.rb

String.class_eval do
  def to_squawk
    "squawk! #{self}".strip
  end
end
```

To test that your method does what it says it does, run the unit tests with `rake` from your plugin directory.

```bash
  3 tests, 3 assertions, 0 failures, 0 errors, 0 skips
```

To see this in action, change to the test/dummy directory, fire up a console and start squawking:

```bash
$ rails console
>> "Hello World".to_squawk
=> "squawk! Hello World"
```

Add an "acts_as" Method to Active Record
----------------------------------------

A common pattern in plugins is to add a method called 'acts_as_something' to models. In this case, you
want to write a method called 'acts_as_yaffle' that adds a 'squawk' method to your Active Record models.

To begin, set up your files so that you have:

```ruby
# yaffle/test/acts_as_yaffle_test.rb

require 'test_helper'

class ActsAsYaffleTest < Test::Unit::TestCase
end
```

```ruby
# yaffle/lib/yaffle.rb

require "yaffle/core_ext"
require 'yaffle/acts_as_yaffle'

module Yaffle
end
```

```ruby
# yaffle/lib/yaffle/acts_as_yaffle.rb

module Yaffle
  module ActsAsYaffle
    # your code will go here
  end
end
```

### Add a Class Method

This plugin will expect that you've added a method to your model named 'last_squawk'. However, the
plugin users might have already defined a method on their model named 'last_squawk' that they use
for something else. This plugin will allow the name to be changed by adding a class method called 'yaffle_text_field'.

To start out, write a failing test that shows the behavior you'd like:

```ruby
# yaffle/test/acts_as_yaffle_test.rb

require 'test_helper'

class ActsAsYaffleTest < Test::Unit::TestCase

  def test_a_hickwalls_yaffle_text_field_should_be_last_squawk
    assert_equal "last_squawk", Hickwall.yaffle_text_field
  end

  def test_a_wickwalls_yaffle_text_field_should_be_last_tweet
    assert_equal "last_tweet", Wickwall.yaffle_text_field
  end

end
```

When you run `rake`, you should see the following:

```
    1) Error:
  test_a_hickwalls_yaffle_text_field_should_be_last_squawk(ActsAsYaffleTest):
  NameError: uninitialized constant ActsAsYaffleTest::Hickwall
      test/acts_as_yaffle_test.rb:6:in `test_a_hickwalls_yaffle_text_field_should_be_last_squawk'

    2) Error:
  test_a_wickwalls_yaffle_text_field_should_be_last_tweet(ActsAsYaffleTest):
  NameError: uninitialized constant ActsAsYaffleTest::Wickwall
      test/acts_as_yaffle_test.rb:10:in `test_a_wickwalls_yaffle_text_field_should_be_last_tweet'

  5 tests, 3 assertions, 0 failures, 2 errors, 0 skips
```

This tells us that we don't have the necessary models (Hickwall and Wickwall) that we are trying to test.
We can easily generate these models in our "dummy" Rails application by running the following commands from the
test/dummy directory:

```bash
$ cd test/dummy
$ rails generate model Hickwall last_squawk:string
$ rails generate model Wickwall last_squawk:string last_tweet:string
```

Now you can create the necessary database tables in your testing database by navigating to your dummy app
and migrating the database. First

```bash
$ cd test/dummy
$ rake db:migrate
$ rake db:test:prepare
```

While you are here, change the Hickwall and Wickwall models so that they know that they are supposed to act
like yaffles.

```ruby
# test/dummy/app/models/hickwall.rb

class Hickwall < ActiveRecord::Base
  acts_as_yaffle
end

# test/dummy/app/models/wickwall.rb

class Wickwall < ActiveRecord::Base
  acts_as_yaffle yaffle_text_field: :last_tweet
end

```

We will also add code to define the acts_as_yaffle method.

```ruby
# yaffle/lib/yaffle/acts_as_yaffle.rb
module Yaffle
  module ActsAsYaffle
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_yaffle(options = {})
        # your code will go here
      end
    end
  end
end

ActiveRecord::Base.send :include, Yaffle::ActsAsYaffle
```

You can then return to the root directory (`cd ../..`) of your plugin and rerun the tests using `rake`.

```
    1) Error:
  test_a_hickwalls_yaffle_text_field_should_be_last_squawk(ActsAsYaffleTest):
  NoMethodError: undefined method `yaffle_text_field' for #<Class:0x000001016661b8>
      /Users/xxx/.rvm/gems/ruby-1.9.2-p136@xxx/gems/activerecord-3.0.3/lib/active_record/base.rb:1008:in `method_missing'
      test/acts_as_yaffle_test.rb:5:in `test_a_hickwalls_yaffle_text_field_should_be_last_squawk'

    2) Error:
  test_a_wickwalls_yaffle_text_field_should_be_last_tweet(ActsAsYaffleTest):
  NoMethodError: undefined method `yaffle_text_field' for #<Class:0x00000101653748>
      Users/xxx/.rvm/gems/ruby-1.9.2-p136@xxx/gems/activerecord-3.0.3/lib/active_record/base.rb:1008:in `method_missing'
      test/acts_as_yaffle_test.rb:9:in `test_a_wickwalls_yaffle_text_field_should_be_last_tweet'

  5 tests, 3 assertions, 0 failures, 2 errors, 0 skips

```

Getting closer... Now we will implement the code of the acts_as_yaffle method to make the tests pass.

```ruby
# yaffle/lib/yaffle/acts_as_yaffle.rb

module Yaffle
  module ActsAsYaffle
   extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_yaffle(options = {})
        cattr_accessor :yaffle_text_field
        self.yaffle_text_field = (options[:yaffle_text_field] || :last_squawk).to_s
      end
    end
  end
end

ActiveRecord::Base.send :include, Yaffle::ActsAsYaffle
```

When you run `rake` you should see the tests all pass:

```bash
  5 tests, 5 assertions, 0 failures, 0 errors, 0 skips
```

### Add an Instance Method

This plugin will add a method named 'squawk' to any Active Record object that calls 'acts_as_yaffle'. The 'squawk'
method will simply set the value of one of the fields in the database.

To start out, write a failing test that shows the behavior you'd like:

```ruby
# yaffle/test/acts_as_yaffle_test.rb
require 'test_helper'

class ActsAsYaffleTest < Test::Unit::TestCase

  def test_a_hickwalls_yaffle_text_field_should_be_last_squawk
    assert_equal "last_squawk", Hickwall.yaffle_text_field
  end

  def test_a_wickwalls_yaffle_text_field_should_be_last_tweet
    assert_equal "last_tweet", Wickwall.yaffle_text_field
  end

  def test_hickwalls_squawk_should_populate_last_squawk
    hickwall = Hickwall.new
    hickwall.squawk("Hello World")
    assert_equal "squawk! Hello World", hickwall.last_squawk
  end

  def test_wickwalls_squawk_should_populate_last_tweet
    wickwall = Wickwall.new
    wickwall.squawk("Hello World")
    assert_equal "squawk! Hello World", wickwall.last_tweet
  end
end
```

Run the test to make sure the last two tests fail with an error that contains "NoMethodError: undefined method `squawk'",
then update 'acts_as_yaffle.rb' to look like this:

```ruby
# yaffle/lib/yaffle/acts_as_yaffle.rb

module Yaffle
  module ActsAsYaffle
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_yaffle(options = {})
        cattr_accessor :yaffle_text_field
        self.yaffle_text_field = (options[:yaffle_text_field] || :last_squawk).to_s

        include Yaffle::ActsAsYaffle::LocalInstanceMethods
      end
    end

    module LocalInstanceMethods
      def squawk(string)
        write_attribute(self.class.yaffle_text_field, string.to_squawk)
      end
    end
  end
end

ActiveRecord::Base.send :include, Yaffle::ActsAsYaffle
```

Run `rake` one final time and you should see:

```
  7 tests, 7 assertions, 0 failures, 0 errors, 0 skips
```

NOTE: The use of `write_attribute` to write to the field in model is just one example of how a plugin can interact with the model, and will not always be the right method to use. For example, you could also use `send("#{self.class.yaffle_text_field}=", string.to_squawk)`.

Generators
----------

Generators can be included in your gem simply by creating them in a lib/generators directory of your plugin. More information about
the creation of generators can be found in the [Generators Guide](generators.html)

Publishing your Gem
-------------------

Gem plugins currently in development can easily be shared from any Git repository. To share the Yaffle gem with others, simply
commit the code to a Git repository (like GitHub) and add a line to the Gemfile of the application in question:

```ruby
gem 'yaffle', git: 'git://github.com/yaffle_watcher/yaffle.git'
```

After running `bundle install`, your gem functionality will be available to the application.

When the gem is ready to be shared as a formal release, it can be published to [RubyGems](http://www.rubygems.org).
For more information about publishing gems to RubyGems, see: [Creating and Publishing Your First Ruby Gem](http://blog.thepete.net/2010/11/creating-and-publishing-your-first-ruby.html)

RDoc Documentation
------------------

Once your plugin is stable and you are ready to deploy do everyone else a favor and document it! Luckily, writing documentation for your plugin is easy.

The first step is to update the README file with detailed information about how to use your plugin. A few key things to include are:

* Your name
* How to install
* How to add the functionality to the app (several examples of common use cases)
* Warnings, gotchas or tips that might help users and save them time

Once your README is solid, go through and add rdoc comments to all of the methods that developers will use. It's also customary to add '#:nodoc:' comments to those parts of the code that are not included in the public API.

Once your comments are good to go, navigate to your plugin directory and run:

```bash
$ rake rdoc
```

### References

* [Developing a RubyGem using Bundler](https://github.com/radar/guides/blob/master/gem-development.md)
* [Using .gemspecs as Intended](http://yehudakatz.com/2010/04/02/using-gemspecs-as-intended/)
* [Gemspec Reference](http://docs.rubygems.org/read/chapter/20)
* [GemPlugins: A Brief Introduction to the Future of Rails Plugins](http://www.intridea.com/blog/2008/6/11/gemplugins-a-brief-introduction-to-the-future-of-rails-plugins)
