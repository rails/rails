**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Autoloading and Reloading Constants (Zeitwerk Mode)
======================================================

This guide documents how autoloading and reloading works in `zeitwerk` mode.

After reading this guide, you will know:

* Autoloading modes
* Related Rails configuration
* Project structure
* Autoloading, reloading, and eager loading
* Single Table Inheritance
* And more

--------------------------------------------------------------------------------


Introduction
------------

INFO. This guide documents autoloading in `zeitwerk` mode, which is new in Rails 6. If you'd like to read about `classic` mode instead, please check [Autoloading and Reloading Constants (Classic Mode)](autoloading_and_reloading_constants_classic_mode.html).

In a normal Ruby program, dependencies need to be loaded by hand. For example, the following controller uses classes `ApplicationController` and `Post`, and normally you'd need to put `require` calls for them:

```ruby
# DO NOT DO THIS.
require "application_controller"
require "post"
# DO NOT DO THIS.

class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

This is not the case in Rails applications, where application classes and modules are just available everywhere:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

Idiomatic Rails applications only issue `require` calls to load stuff from their `lib` directory, the Ruby standard library, Ruby gems, etc. That is, anything that does not belong to their autoload paths, explained below.


Enabling Zeitwerk Mode
----------------------

The autoloading `zeitwerk` mode is enabled by default in Rails 6 applications running on CRuby:

```ruby
# config/application.rb
config.load_defaults 6.0 # enables zeitwerk mode in CRuby
```

In `zeitwerk` mode, Rails uses [Zeitwerk](https://github.com/fxn/zeitwerk) internally to autoload, reload, and eager load. Rails instantiates and configures a dedicated Zeitwerk instance that manages the project.

INFO. You do not configure Zeitwerk manually in a Rails application. Rather, you configure the application using the portable configuration points explained in this guide, and Rails translates that to Zeitwerk on your behalf.

Project Structure
-----------------

In a Rails application file names have to match the constants they define, with directories acting as namespaces.

For example, the file `app/helpers/users_helper.rb` should define `UsersHelper` and the file `app/controllers/admin/payments_controller.rb` should define `Admin::PaymentsController`.

By default, Rails configures Zeitwerk to inflect file names with `String#camelize`. For example, it expects that `app/controllers/users_controller.rb` defines the constant `UsersController` because

```ruby
"users_controller".camelize # => UsersController
```

The section _Customizing Inflections_ below documents ways to override this default.

Please, check the [Zeitwerk documentation](https://github.com/fxn/zeitwerk#file-structure) for further details.

Autoload Paths
--------------

We refer to the list of application directories whose contents are to be autoloaded as _autoload paths_. For example, `app/models`. Such directories represent the root namespace: `Object`.

INFO. Autoload paths are called _root directories_ in Zeitwerk documentation, but we'll stay with "autoload path" in this guide.

Within an autoload path, file names must match the constants they define as documented [here](https://github.com/fxn/zeitwerk#file-structure).

By default, the autoload paths of an application consist of all the subdirectories of `app` that exist when the application boots ---except for `assets`, `javascript`, `views`,--- plus the autoload paths of engines it might depend on.

For example, if `UsersHelper` is implemented in `app/helpers/users_helper.rb`, the module is autoloadable, you do not need (and should not write) a `require` call for it:

```bash
$ bin/rails runner 'p UsersHelper'
UsersHelper
```

Autoload paths automatically pick any custom directories under `app`. For example, if your application has `app/presenters`, or `app/services`, etc., they are added to autoload paths.

The array of autoload paths can be extended by mutating `config.autoload_paths`, in `config/application.rb`, but nowadays this is discouraged.

WARNING. Please, do not mutate `ActiveSupport::Dependencies.autoload_paths`, the public interface to change autoload paths is `config.autoload_paths`.


$LOAD_PATH
----------

Autoload paths are added to `$LOAD_PATH` by default. However, Zeitwerk uses absolute file names internally, and your application should not issue `require` calls for autoloadable files, so those directories are actually not needed there. You can opt-out with this flag:

```ruby
config.add_autoload_paths_to_load_path = false
```

That may speed legit `require` calls a bit, since there are less lookups. Also, if your application uses [Bootsnap](https://github.com/Shopify/bootsnap), that saves the library from building unnecessary indexes, and saves the RAM they would need.


Reloading
---------

Rails automatically reloads classes and modules if application files change.

More precisely, if the web server is running and application files have been modified, Rails unloads all autoloaded constants just before the next request is processed. That way, application classes or modules used during that request are going to be autoloaded, thus picking up their current implementation in the file system.

Reloading can be enabled or disabled. The setting that controls this behavior is `config.cache_classes`, which is false by default in `development` mode (reloading enabled), and true by default in `production` mode (reloading disabled).

Rails detects files have changed using an evented file monitor (default), or walking the autoload paths, depending on `config.file_watcher`.

In a Rails console there is no file watcher active regardless of the value of `config.cache_classes`. This is so because, normally, it would be confusing to have code reloaded in the middle of a console session, the same way you generally want an individual request to be served by a consistent, non-changing set of application classes and modules.

However, you can force a reload in the console by executing `reload!`:

```irb
irb(main):001:0> User.object_id
=> 70136277390120
irb(main):002:0> reload!
Reloading...
=> true
irb(main):003:0> User.object_id
=> 70136284426020
```

as you can see, the class object stored in the `User` constant is different after reloading.

### Reloading and Stale Objects

It is very important to understand that Ruby does not have a way to truly reload classes and modules in memory, and have that reflected everywhere they are already used. Technically, "unloading" the `User` class means removing the `User` constant via `Object.send(:remove_const, "User")`.

Therefore, code that references a reloadable class or module, but that is not executed again on reload, becomes stale. Let's see an example next.

Let's consider this initializer:

```ruby
# config/initializers/configure_payment_gateway.rb
# DO NOT DO THIS.
$PAYMENT_GATEWAY = Rails.env.production? ? RealGateway : MockedGateway
# DO NOT DO THIS.
```

The idea would be to use `$PAYMENT_GATEWAY` in the code, and let the initializer set that to the actual implementation dependending on the environment.

On reload, `MockedGateway` is reloaded, but `$PAYMENT_GATEWAY` is not updated because initializers only run on boot. Therefore, it won't reflect the changes.

There are several ways to do this safely. For instance, the application could define a class method `PaymentGateway.impl` whose definition depends on the environment; or could define `PaymentGateway` to have a parent class or mixin that depends on the environment; or use the same global variable trick, but in a reloader callback, as explained below.

Let's see other situations that involve stale class or module objects.

Check this Rails console session:

```irb
irb> joe = User.new
irb> reload!
irb> alice = User.new
irb> joe.class == alice.class
=> false
```

`joe` is an instance of the original `User` class. When there is a reload, the `User` constant evaluates to a different, reloaded class. `alice` is an instance of the current one, but `joe` is not, his class is stale. You may define `joe` again, start an IRB subsession, or just launch a new console instead of calling `reload!`.

Another situation in which you may find this gotcha is subclassing reloadable classes in a place that is not reloaded:

```ruby
# lib/vip_user.rb
class VipUser < User
end
```

if `User` is reloaded, since `VipUser` is not, the superclass of `VipUser` is the original stale class object.

Bottom line: **do not cache reloadable classes or modules**.

### Autoloading when the application boots

Applications can safely autoload constants during boot using a reloader callback:

```ruby
Rails.application.reloader.to_prepare do
  $PAYMENT_GATEWAY = Rails.env.production? ? RealGateway : MockedGateway
end
```

That block runs when the application boots, and every time code is reloaded.

NOTE: For historical reasons, this callback may run twice. The code it executes must be idempotent.


Eager Loading
-------------

In production-like environments it is generally better to load all the application code when the application boots. Eager loading puts everything in memory ready to serve requests right away, and it is also [CoW](https://en.wikipedia.org/wiki/Copy-on-write)-friendly.

Eager loading is controlled by the flag `config.eager_load`, which is enabled by default in `production` mode.

The order in which files are eager loaded is undefined.

if the `Zeitwerk` constant is defined, Rails invokes `Zeitwerk::Loader.eager_load_all` regardless of the application autoloading mode. That ensures dependencies managed by Zeitwerk are eager loaded.


Single Table Inheritance
------------------------

Single Table Inheritance is a feature that doesn't play well with lazy loading. Reason is, its API generally needs to be able to enumerate the STI hierarchy to work correctly, whereas lazy loading defers loading classes until they are referenced. You can't enumerate what you haven't referenced yet.

In a sense, applications need to eager load STI hierarchies regardless of the loading mode.

Of course, if the application eager loads on boot, that is already accomplished. When it does not, it is in practice enough to instantiate the existing types in the database, which in development or test modes is usually fine. One way to do that is to throw this module into the `lib` directory:

```ruby
module StiPreload
  unless Rails.application.config.eager_load
    extend ActiveSupport::Concern

    included do
      cattr_accessor :preloaded, instance_accessor: false
    end

    class_methods do
      def descendants
        preload_sti unless preloaded
        super
      end

      # Constantizes all types present in the database. There might be more on
      # disk, but that does not matter in practice as far as the STI API is
      # concerned.
      #
      # Assumes store_full_sti_class is true, the default.
      def preload_sti
        types_in_db = \
          base_class.
            unscoped.
            select(inheritance_column).
            distinct.
            pluck(inheritance_column).
            compact

        types_in_db.each do |type|
          logger.debug("Preloading STI type #{type}")
          type.constantize
        end

        self.preloaded = true
      end
    end
  end
end
```

and then include it in the STI root classes of your project:

```ruby
# app/models/shape.rb
require "sti_preload"

class Shape < ApplicationRecord
  include StiPreload # Only in the root class.
end

# app/models/polygon.rb
class Polygon < Shape
end

# app/models/triangle.rb
class Triangle < Polygon
end
```

Customizing Inflections
-----------------------

By default, Rails uses `String#camelize` to know which constant should a given file or directory name define. For example, `posts_controller.rb` should define `PostsController` because that is what `"posts_controller".camelize` returns.

It could be the case that some particular file or directory name does not get inflected as you want. For instance, `html_parser.rb` is expected to define `HtmlParser` by default. What if you prefer the class to be `HTMLParser`? There are a few ways to customize this.

The easiest way is to define acronyms in `config/initializers/inflections.rb`:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "HTML"
  inflect.acronym "SSL"
end
```

Doing so affects how Active Support inflects globally. That may be fine in some applications, but you can also customize how to camelize individual basenames independently from Active Support by passing a collection of overrides to the default inflectors:

```ruby
# config/initializers/zeitwerk.rb
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    "html_parser" => "HTMLParser",
    "ssl_error"   => "SSLError"
  )
end
```

That technique still depends on `String#camelize`, though, because that is what the default inflectors use as fallback. If you instead prefer not to depend on Active Support inflections at all and have absolute control over inflections, configure the inflectors to be instances of `Zeitwerk::Inflector`:

```ruby
# config/initializers/zeitwerk.rb
Rails.autoloaders.each do |autoloader|
  autoloader.inflector = Zeitwerk::Inflector.new
  autoloader.inflector.inflect(
    "html_parser" => "HTMLParser",
    "ssl_error"   => "SSLError"
  )
end
```

There is no global configuration that can affect said instances, they are deterministic.

You can even define a custom inflector for full flexibility. Please, check the [Zeitwerk documentation](https://github.com/fxn/zeitwerk#custom-inflector) for further details.

Troubleshooting
---------------

The best way to follow what the loaders are doing is to inspect their activity.

The easiest way to do that is to throw

```ruby
Rails.autoloaders.log!
```

to `config/application.rb` after loading the framework defaults. That will print traces to standard output.

If you prefer logging to a file, configure this instead:

```ruby
Rails.autoloaders.logger = Logger.new("#{Rails.root}/log/autoloading.log")
```

The Rails logger is still not ready in `config/application.rb`, but it is in initializers:

```ruby
# config/initializers/log_autoloaders.rb
Rails.autoloaders.logger = Rails.logger
```

Rails.autoloaders
-----------------

The Zeitwerk instances managing your application are available at

```ruby
Rails.autoloaders.main
Rails.autoloaders.once
```

The former is the main one. The latter is there mostly for backwards compatibility reasons, in case the application has something in `config.autoload_once_paths` (this is discouraged nowadays).

You can check if `zeitwerk` mode is enabled with

```ruby
Rails.autoloaders.zeitwerk_enabled?
```

Differences with Classic Mode
-----------------------------

### Ruby Constant Lookup Compliance

`classic` mode cannot match constant lookup semantics due to fundamental limitations of the technique it is based on, whereas `zeitwerk` mode works like Ruby.

For example, in `classic` mode defining classes or modules in namespaces with qualified constants this way

```ruby
class Admin::UsersController < ApplicationController
end
```

was not recommended because the resolution of constants inside their body was britle. You'd better write them in this style:

```ruby
module Admin
  class UsersController < ApplicationController
  end
end
```

In `zeitwerk` mode that does not matter anymore, you can pick either style.

The resolution of a constant could depend on load order, the definition of a class or module object could depend on load order, there was edge cases with singleton classes, oftentimes you had to use `require_dependency` as a workaround, .... The guide for `classic` mode documents [these issues](autoloading_and_reloading_constants_classic_mode.html#common-gotchas).

All these problems are solved in `zeitwerk` mode, it just works as expected, and `require_dependency` should not be used anymore, it is no longer needed.

### Less File Lookups

In `classic` mode, every single missing constant triggers a file lookup that walks the autoload paths.

In `zeitwerk` mode there is only one pass. That pass is done once, not per missing constant, and so it is generally more performant. Subdirectories are visited only if their namespace is used.

### Underscore vs Camelize

Inflections go the other way around.

In `classic` mode, given a missing constant Rails _underscores_ its name and performs a file lookup. On the other hand, `zeitwerk` mode checks first the file system, and _camelizes_ file names to know the constant those files are expected to define.

While in common names these operations match, if acronyms or custom inflection rules are configured, they may not. For example, by default `"HTMLParser".underscore` is `"html_parser"`, and `"html_parser".camelize` is `"HtmlParser"`.

### More Differences

There are some other subtle differences, please check [this section of _Upgrading Ruby on Rails_](upgrading_ruby_on_rails.html#autoloading) guide for details.

Classic Mode is Deprecated
--------------------------

By now, it is still possible to use `classic` mode. However, `classic` is deprecated and will be eventually removed.

New applications should use `zeitwerk` mode (which is the default), and applications being upgrade are strongly encouraged to migrate to `zeitwerk` mode. Please check the [_Upgrading Ruby on Rails_](upgrading_ruby_on_rails.html#autoloading) guide for details.

Opting Out
----------

Applications can load Rails 6 defaults and still use the classic autoloader this way:

```ruby
# config/application.rb
config.load_defaults 6.0
config.autoloader = :classic
```

That may be handy if upgrading to Rails 6 in different phases, but classic mode is discouraged for new applications.

`zeitwerk` mode is not available in versions of Rails previous to 6.0.
