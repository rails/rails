**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Classic to Zeitwerk HOWTO
=========================

This guide documents how to migrate Rails applications from `classic` to `zeitwerk` mode.

After reading this guide, you will know:

* What are `classic` and `zeitwerk` modes
* Why switch from `classic` to `zeitwerk`
* How to activate `zeitwerk` mode
* How to verify your application runs in `zeitwerk` mode
* How to verify your project loads OK in the command line
* How to verify your project loads OK in the test suite
* How to address possible edge cases
* New features in Zeitwerk you can leverage

--------------------------------------------------------------------------------

What are `classic` and `zeitwerk` Modes?
--------------------------------------------------------

From the very beginning, and up to Rails 5, Rails used an autoloader implemented in Active Support. This autoloader is known as `classic` and is still available in Rails 6.x. Rails 7 does not include this autoloader anymore.

Starting with Rails 6, Rails ships with a new and better way to autoload, which delegates to the [Zeitwerk](https://github.com/fxn/zeitwerk) gem. This is `zeitwerk` mode. By default, applications loading the 6.0 and 6.1 framework defaults run in `zeitwerk` mode, and this is the only mode available in Rails 7.


Why Switch from `classic` to `zeitwerk`?
----------------------------------------

The `classic` autoloader has been extremely useful, but had a number of [issues](https://guides.rubyonrails.org/v6.1/autoloading_and_reloading_constants_classic_mode.html#common-gotchas) that made autoloading a bit tricky and confusing at times. Zeitwerk was developed to address them, among other [motivations](https://github.com/fxn/zeitwerk#motivation).

When upgrading to Rails 6.x, it is highly encouraged to switch to `zeitwerk` mode because `classic` mode is deprecated.

Rails 7 ends the transition period and does not include `classic` mode.

I am Scared
-----------

Don't :).

Zeitwerk was designed to be as compatible with the classic autoloader as possible. If you have a working application autoloading correctly today, chances are the switch will be easy. Many projects, big and small, have reported really smooth switches.

This guide will help you change the autoloader with confidence.

If for whatever reason you find a situation you don't know how to resolve, don't hesitate to [open an issue in `rails/rails`](https://github.com/rails/rails/issues/new) and tag [`@fxn`](https://github.com/fxn).


How to Activate `zeitwerk` Mode
-------------------------------

### Applications running Rails 5.x or Less

In applications running a Rails version previous to 6.0, `zeitwerk` mode is not available. You need to be at least in Rails 6.0.

### Applications running Rails 6.x

In applications running Rails 6.x there are two scenarios.

If the application is loading the framework defaults of Rails 6.0 or 6.1 and it is running in `classic` mode, it must be opting out by hand. You have to have something similar to this:

```ruby
# config/application.rb
config.load_defaults 6.0
config.autoloader = :classic # DELETE THIS LINE
```

As noted, just delete the override, `zeitwerk` mode is the default.

On the other hand, if the application is loading old framework defaults you need to enable `zeitwerk` mode explicitly:

```ruby
# config/application.rb
config.load_defaults 5.2
config.autoloader = :zeitwerk
```

### Applications Running Rails 7

In Rails 7 there is only `zeitwerk` mode, you do not need to do anything to enable it.

Indeed, the setter `config.autoloader=` does not even exist. If `config/application.rb` has it, please just delete the line.


How to Verify The Application Runs in `zeitwerk` Mode?
------------------------------------------------------

To verify the application is running in `zeitwerk` mode, execute

```
bin/rails runner 'p Rails.autoloaders.zeitwerk_enabled?'
```

If that prints `true`, `zeitwerk` mode is enabled.


Does my Application Comply with Zeitwerk Conventions?
-----------------------------------------------------

Once `zeitwerk` mode is enabled, please run:

```
bin/rails zeitwerk:check
```

A successful check looks like this:

```
% bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

There can be additional output depending on the application configuration, but the last "All is good!" is what you are looking for.

If there's any file that does not define the expected constant, the task will tell you. It does so one file at a time, because if it moved on, the failure loading one file could cascade into other failures unrelated to the check we want to run and the error report would be confusing.

If there's one constant reported, fix that particular one and run the task again. Repeat until you get "All is good!".

Take for example:

```
% bin/rails zeitwerk:check
Hold on, I am eager loading the application.
expected file app/models/vat.rb to define constant Vat
```

VAT is an European tax. The file `app/models/vat.rb` defines `VAT` but the autoloader expects `Vat`, why?

### Acronyms

This is the most common kind of discrepancy you may find, it has to do with acronyms. Let's understand why do we get that error message.

The classic autoloader is able to autoload `VAT` because its input is the name of the missing constant, `VAT`, invokes `underscore` on it, which yields `vat`, and looks for a file called `var.rb`. It works.

The input of the new autoloader is the file system. Give the file `vat.rb`, Zeitwerk invokes `camelize` on `vat`, which yields `Vat`, and expects the file to define the constant `Vat`. That is what the error message says.

Fixing this is easy, you only need to tell the inflector about this acronym:

```ruby
# config/initializers/inflections.rb
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "VAT"
end
```

Doing so affects how Active Support inflects globally. That may be fine, but if you prefer you can also pass overrides to the inflector used by the autoloader:

```ruby
# config/initializers/zeitwerk.rb
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect("vat" => "VAT")
end
```

With that in place, the check passes :

```
% bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

### Concerns

You can autoload and eager load from a standard structure with `concerns` subdirectories like

```
app/models
app/models/concerns
```

By default, `app/models/concerns` belongs to the autoload paths and therefore it is assumed to be a root directory. So, by default, `app/models/concerns/foo.rb` should define `Foo`, not `Concerns::Foo`.

If your application uses `Concerns` as namespace, you have two options:

1. Remove the `Concerns` namespace from those classes and modules and update client code.
2. Leave things as they are by removing `app/models/concerns` from the autoload paths:

  ```ruby
  # config/initializers/zeitwerk.rb
  ActiveSupport::Dependencies.
    autoload_paths.
    delete("#{Rails.root}/app/models/concerns")
  ```

### Having `app` in the autoload paths

Some projects want something like `app/api/base.rb` to define `API::Base`, and add `app` to the autoload paths to accomplish that.

Since Rails adds all subdirectories of `app` to the autoload paths automatically (with a few exceptions like directories for assets), we have another situation in which there are nested root directories, similar to what happens with `app/models/concerns`. That setup no longer works as is.

However, you can keep that structure, just delete `app/api` from the autoload paths in an initializer:

```ruby
# config/initializers/zeitwerk.rb
ActiveSupport::Dependencies.
  autoload_paths.
  delete("#{Rails.root}/app/api")
```

### Autoloaded Constants and Explicit Namespaces

If a namespace is defined in a file, as `Hotel` is here:

```
app/models/hotel.rb         # Defines Hotel.
app/models/hotel/pricing.rb # Defines Hotel::Pricing.
```

the `Hotel` constant has to be set using the `class` or `module` keywords. For example:

```ruby
class Hotel
end
```

is good.

Alternatives like

```ruby
Hotel = Class.new
```

or

```ruby
Hotel = Struct.new
```

won't work, child objects like `Hotel::Pricing` won't be found.

This restriction only applies to explicit namespaces. Classes and modules not defining a namespace can be defined using those idioms.

### One file, one constant (at the same top-level)

In `classic` mode you could technically define several constants at the same top-level and have them all reloaded. For example, given

```ruby
# app/models/foo.rb

class Foo
end

class Bar
end
```

while `Bar` could not be autoloaded, autoloading `Foo` would mark `Bar` as autoloaded too.

This is not the case in `zeitwerk` mode, you need to move `Bar` to its own file `bar.rb`. One file, one top-level constant.

This affects only to constants at the same top-level as in the example above. Inner classes and modules are fine. For example, consider

```ruby
# app/models/foo.rb

class Foo
  class InnerClass
  end
end
```

If the application reloads `Foo`, it will reload `Foo::InnerClass` too.

### Globs in `config.autoload_paths`

Beware of configurations that use wildcards like

```ruby
config.autoload_paths += Dir["#{config.root}/extras/**/"]
```

Every element of `config.autoload_paths` should represent the top-level namespace (`Object`). That won't work.

To fix this, just remove the wildcards:

```ruby
config.autoload_paths << "#{config.root}/extras"
```

### Spring and the `test` Environment

Spring reloads the application code if something changes. In the `test` environment you need to enable reloading for that to work:

```ruby
# config/environments/test.rb
config.cache_classes = false
```

Otherwise you'll get this error:

```
reloading is disabled because config.cache_classes is true
```

This has no performance penalty.

### Bootsnap

Please make sure to depend on at least Bootsnap 1.4.4.


Check Zeitwerk Compliance in the Test Suite
-------------------------------------------

The Rake task `zeitwerk:check` just eager loads, because doing so triggers built-in validations in Zeitwerk.

You can add the equivalent of this to your test suite to make sure the application always loads correctly regardless of test coverage:

### minitest

```ruby
require "test_helper"

class ZeitwerkComplianceTest < ActiveSupport::TestCase
  test "eager loads all files without errors" do
    Rails.application.eager_load!
  rescue => e
    flunk(e.message)
  else
    pass
  end
end
```

### RSpec

```ruby
require "rails_helper"

RSpec.describe "Zeitwerk compliance" do
  it "eager loads all files without errors" do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
```

New Features You Can Leverage
-----------------------------

### Delete `require_dependency` calls

All known use cases of `require_dependency` have been eliminated with Zeitwerk. You should grep the project and delete them.

If your application uses Single Table Inheritance, please see the [Single Table Inheritance section](autoloading_and_reloading_constants.html#single-table-inheritance) of the Autoloading and Reloading Constants (Zeitwerk Mode) guide.


### Qualified Names in Class and Module Definitions Are Now Possible

You can now robustly use constant paths in class and module definitions:

```ruby
# Autoloading in this class' body matches Ruby semantics now.
class Admin::UsersController < ApplicationController
  # ...
end
```

A gotcha to be aware of is that, depending on the order of execution, the classic autoloader could sometimes be able to autoload `Foo::Wadus` in

```ruby
class Foo::Bar
  Wadus
end
```

That does not match Ruby semantics because `Foo` is not in the nesting, and won't work at all in `zeitwerk` mode. If you find such corner case you can use the qualified name `Foo::Wadus`:

```ruby
class Foo::Bar
  Foo::Wadus
end
```

or add `Foo` to the nesting:

```ruby
module Foo
  class Bar
    Wadus
  end
end
```

### Thread-safety Everywhere

In classic mode, constant autoloading is not thread-safe, though Rails has locks in place for example to make web requests thread-safe.

Constant autoloading is thread-safe in `zeitwerk` mode. For example, you can now autoload in multi-threaded scripts executed by the `runner` command.

### Eager Loading and Autoloading are Consistent

In `classic` mode, if `app/models/foo.rb` defines `Bar`, you won't be able to autoload that file, but eager loading will work because it loads files recursively blindly. This can be a source of errors if you test things first eager loading, execution may fail later autoloading.

In `zeitwerk` mode both loading modes are consistent, they fail and err in the same files.
