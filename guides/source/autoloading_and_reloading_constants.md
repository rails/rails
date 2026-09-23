**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Autoloading and Reloading Constants
===================================

This guide documents how autoloading, reloading, and eager loading work.

After reading this guide, you will know:

* The difference between autoloading, reloading, and eager loading
* Configuration options and directory structure for autoloading
* The difference between the *main* and *once* autoloaders
* Considerations for engines and Single Table Inheritance
* How to customize inflection rules for file names and namespaces
* How to troubleshoot autoloading

--------------------------------------------------------------------------------

Introduction
------------

In order to understand how autoloading works and why autoloading exists in Rails, it is useful to understand the following about Ruby.

In Ruby, the name of a class or module is a constant. Furthermore, there is no
inherent relationship between a file's name and the constants it defines.
Nothing connects the file `user.rb` to the constant `User`.

That means an ordinary Ruby program has to load files explicitly before using
the constants they define. When Ruby executes a `require` call, the classes
and modules defined in that file come into existence. 

For example, the `PostsController` class below refers to 
`ApplicationController` and `Post`. If this was an ordinary Ruby program,
you would need to call `require` at the top of the file to ensure they're available for use:

```ruby
# -----------------------
# Do not do this in Rails
require "application_controller"
require "post"
# -----------------------

class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

However, as you've likely seen, there are no explicit `require` calls in a Rails controller. Classes and modules are automatically loaded and available in a Rails application without a `require`:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end
end
```

This is possible thanks to the [Zeitwerk](https://github.com/fxn/zeitwerk)
library, which sets up loaders in your Rails application that provide
autoloading (as well as reloading and eager loading).

NOTE: Zeitwerk is present in every Rails application and automatically set up
and initialized during the boot process.

### What is Autoloading?

The idea behind autoloading is to load constants the first time they are referenced, and do so automatically in the "background" (without an explicit require statement). These constants typically are your application classes and modules, though they could also store any other Ruby object like integers or strings.

One question to consider is: _when_ should constants be loaded? Autoloading,
reloading, and eager loading are three different answers to that question: on
first reference (autoloading), all at once during boot (eager loading), or again
after a file changes (reloading). See [Eager Loading](#eager-loading) and
[Reloading](#reloading) for more detail on those. We focus on how autoloading
works here.

There are two autoloaders: `main` and `once`. The `main` autoloader manages
reloadable code, which is nearly everything you write, including everything in
the `app` directory. The `once` autoloader's purpose is to manage code that is
autoloaded but never reloaded. Both load code the same way, reloading vs. not is
the only difference between them.

Another question is: _which_ files are autoloaded? The Zeitwerk loaders manage
the code in your application's autoload paths, which by default are all
subdirectories of the `app` directory. Zeitwerk also manages the `lib` directory
when `config.autoload_lib` is configured (as explained
[later](#autoloading-lib)). Zeitwerk loaders do _not_ manage the Ruby standard
library, gem dependencies, or the Rails components themselves. That code has to
be loaded as usual, with a `require`.

### How Autoloading Works

Autoloading relies on the directory structure and file naming convention.
In a Rails application (unlike ordinary Ruby programs), file names have to match the constants they define, with directories acting as namespaces. For example:

- file `app/helpers/users_helper.rb` should define `UsersHelper`
- file `app/controllers/admin/payments_controller.rb` should define `Admin::PaymentsController`.

NOTE: Rails configures Zeitwerk to infer file names using the [`String#camelize`](https://api.rubyonrails.org/classes/String.html#method-i-camelize) method. For example, it expects that `app/controllers/users_controller.rb` defines the constant `UsersController` because that is what `"users_controller".camelize` returns. The section [Customizing Inflections](#customizing-file-names-and-defined-constants) below documents ways to override this default.

Because file names carry that information, Rails can determine which file
defines which constant by its directory and file name alone.

Rails sets up loaders that build this map from the autoload paths during the
application's boot process. For each constant, the loaders register a lazy-load
hook with Ruby's built-in
[`Module#autoload`](https://www.rubydoc.info/stdlib/core/Module:autoload), that
lists the file defining that constant:

```ruby
Object.autoload(:User, "#{Rails.root}/app/models/user.rb")
```

The first time your application references `User` and finds no such constant
defined, Ruby consults the loader's registered entries, and loads the file
(using `require`). This is how autoloading works and is why you do not have to
write explicit `require` calls for the application classes and modules that
Zeitwerk manages.

Adding Autoload Paths
---------------------

We refer to the list of application directories whose contents are autoloaded and (optionally) reloaded as _autoload paths_. For example, `app/models/concerns` is an authoload path by default since it's inside `app`.

Files directly inside the authload path define top-level constants, so
`app/models/user.rb` defines `User`, not `Models::User`. In Ruby, top-level
constants belong to `Object`, so Zeitwerk describes autoload paths as
representing the root namespace. Directories _inside_ an autoload path act as
namespaces, so `app/models/billing/invoice.rb` defines `Billing::Invoice`.

INFO: Autoload paths are called _root directories_ in Zeitwerk documentation, but we'll stay with "autoload path" in this guide.

By default, the autoload paths of an application consist of all the subdirectories of `app` that exist when the application boots, except for `assets`, `javascript`, and `views`, plus the autoload paths of engines it might depend on.

For example, if `UsersHelper` is implemented in `app/helpers/users_helper.rb`, the module is autoloadable, you do not need (and should not write) a `require` call for it:

```bash
$ bin/rails runner 'p UsersHelper'
UsersHelper
```

Rails adds custom directories under `app` to the autoload paths automatically. For example, if your application has `app/presenters`, you don't need to configure anything in order to autoload presenters.

The array of default autoload paths can be extended by pushing to `config.autoload_paths`, in `config/application.rb` or `config/environments/*.rb`. For example:

```ruby
module MyApplication
  class Application < Rails::Application
    config.autoload_paths << "#{root}/extras"
  end
end
```

Also, engines can do this in the body of the engine class and in their own `config/environments/*.rb`. See [engines section](#autoloading-and-engines) below for more details on autoloading with engines.

WARNING. Please do not mutate `ActiveSupport::Dependencies.autoload_paths`; the public interface to change autoload paths is `config.autoload_paths`.

WARNING: You cannot autoload code in the autoload paths while the application boots. In particular, directly in `config/initializers/*.rb`. Please check [_Autoloading when the application boots_](#autoloading-when-the-application-boots) down below for valid ways to do that.

The autoload paths are managed by the `Rails.autoloaders.main` autoloader.

Autoloading `lib`
----------------

By default, the `lib` directory is not in the autoload paths of applications or engines. The configuration method `config.autoload_lib` adds the `lib` directory to `config.autoload_paths` and `config.eager_load_paths`. It can be invoked from `config/application.rb` or `config/environments/*.rb`:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    config.autoload_lib(ignore: %w(assets tasks))
  end
end
```

With that in place, `lib` follows the same naming convention as the rest of your
application: `lib/payment_gateway.rb` defines `PaymentGateway`, and no `require`
call is needed to use it.

The `lib` directory may have subdirectories that should not be managed by the
autoloaders. You can pass their name relative to `lib` in the required `ignore`
keyword argument, as shown above: `ignore: %w(assets tasks)`.

Zeitwerk ignores files that do not have a `.rb` extension, so a `.rake`, `.js`,
or `.css` file is never autoloaded, reloaded, or eager loaded even if it sits in
an autoload path. But the loaders still have to scan the project tree to find
the `.rb` files they do manage. Telling them a subdirectory holds no Ruby lets
them skip it and that is the reason for an explicit `ignore` list.

Since `lib/assets` typically holds no Ruby files and `lib/tasks` holds Rake
tasks with `.rake` extension, they are on the ignore list.

The `ignore` list should have all `lib` subdirectories that do not contain files
with `.rb` extension, or that should not be reloaded or eager loaded. A complete
ignore list may look like this:

```ruby
config.autoload_lib(ignore: %w(assets tasks templates generators middleware))
```

Note that the `config.autoload_lib` is not available before Rails version 7.1, but you can emulate it, as shown below, as long as the application uses Zeitwerk:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    lib = root.join("lib")

    config.autoload_paths << lib
    config.eager_load_paths << lib

    Rails.autoloaders.main.ignore(
      lib.join("assets"),
      lib.join("tasks"),
      lib.join("generators")
    )

    # ...
  end
end
```

NOTE: `config.autoload_lib` is not available for engines.

Eager Loading
-------------

In production-like environments it's generally better to load all the application code when the application boots. Eager loading puts everything in memory ready to serve requests right away, and it is also [CoW](https://en.wikipedia.org/wiki/Copy-on-write)-friendly (which means Zeitwerk
defines every constant up front, before the server forks its workers, so those
workers share the loaded code in memory rather than each holding its own copy,
reducing total memory use).

Eager loading is controlled by the flag [`config.eager_load`][]. By default, `development` does not eager load, `test` eager loads if the environment variable `CI` is present, and `production` eager loads.

For Rake tasks, the value assigned to `config.eager_load` is replaced with [`config.rake_eager_load`][]. By default, this is `false` in `development` and `production`, and matches `config.eager_load` in `test`.

WARNING: The order in which files are eager-loaded is undefined.

During eager loading, Rails invokes the `Zeitwerk::Loader.eager_load_all`
method. Any gem that manages its own code with Zeitwerk sets up a loader too, so
your application's loaders are not the only ones in the process. The
`eager_load_all` method broadcasts `eager_load` to all loaders and ensures all
gem dependencies managed by Zeitwerk are eager-loaded too.

NOTE: The more accurate terminology would be _eager_ (upfront) vs. _lazy_ (on
demand) loading. You are _autoloading_ in both cases or whenever you don't
explicitly use `require`. Eager loading is a recursive autoload because while
you eager load, top-level references like modules in include calls or
superclasses may have not been loaded yet. In that case, they are autoloaded.
However, since the "autoloading vs. "eager loading" terminology has been used
for decades, this guide preserves it.

[`config.eager_load`]: configuring.html#config-eager-load
[`config.rake_eager_load`]: configuring.html#config-rake-eager-load

Reloading
---------

Rails automatically reloads classes and modules if application files in the autoload paths change (in `development`). More precisely, if the web server is running and application files have been modified, Rails unloads all autoloaded constants managed by the `main` autoloader just before the next request is processed. That way, application classes or modules used during that request will be autoloaded again, thus picking up their current implementation in the file system.

Reloading can be enabled or disabled. The setting that controls this behavior is [`config.enable_reloading`][], which is `true` by default in `development` mode, and `false` by default in `production` and `test` modes. For backwards compatibility, Rails also supports `config.cache_classes`, which is equivalent to `!config.enable_reloading`.

Rails uses an evented file monitor to detect file changes by default.  It can be configured instead to detect file changes by walking the autoload paths. This is controlled by the [`config.file_watcher`][] setting.

In a Rails console, there is no file watcher regardless of the value of `config.enable_reloading`. You generally want a console session to be served by a consistent, non-changing set of application classes and modules. It would be confusing to have code automatically reloaded in the middle of a console session.

However, you can explicitly reload in the console by executing `reload!`:

```irb
irb(main):001:0> User.object_id
=> 70136277390120
irb(main):002:0> reload!
Reloading...
=> true
irb(main):003:0> User.object_id
=> 70136284426020
```

As you can see, the class object stored in the `User` constant is different after reloading. Reloading does _not_ update an existing `User` object, it loads a new object.

[`config.enable_reloading`]: configuring.html#config-enable-reloading
[`config.file_watcher`]: configuring.html#config-file-watcher

### Reloading and Stale Objects

It is important to understand that Ruby does not have a way to truly reload
classes and modules in memory and have that reflected everywhere they are
already used. So reloading works by unloading instead. Rails removes the
constants it defined, and lets them be autoloaded again on the next reference.

Technically, "unloading" `User` means removing the constant with
`Object.send(:remove_const, "User")`. Rails also forgets that the file was ever
loaded, so that referencing `User` again loads `app/models/user.rb` afresh and
defines a new class.

For example, the Rails console session below illustrates this:

```irb
irb> joe = User.new
irb> reload!
irb> alice = User.new
irb> joe.class == alice.class
=> false
```

`joe` is an instance of the original `User` class. After a reload, the `User` constant evaluates to a different, reloaded class. `alice` is an instance of the newly loaded `User`, but `joe` is not — his class is stale. You may define `joe` again, start an IRB subsession, or just launch a new console instead of calling `reload!`.

Another situation in which you may find this gotcha is subclassing reloadable classes in a place that is not reloaded:

```ruby
# lib/vip_user.rb
class VipUser < User
end
```

If `User` is reloaded, since `VipUser` is not, the superclass of `VipUser` is the original stale `User` class (the example assumes `lib` is not in the autoload paths and hence `VipUser`  inside `lib` won't be reloaded).

The consequence is that the stale object keeps behaving as it did when it was
first loaded. Your edits are on disk and in the reloaded class, but the stale
object does not see them: methods you added are missing, methods you deleted are
still there, and in the `VipUser` case, instances of a class that looks like it
inherits from `User` no longer share `User`'s ancestry. No errors are raised.

WARNING: Do not cache reloadable classes or modules.

The solution is one of two moves. Either **store the name instead of the
object**, and resolve it when you need it, so every lookup goes through the
constant and picks up the current class:

```ruby
# Instead of holding on to the class object.
config.user_model = "User"

# Later, at run time:
config.user_model.constantize
```

Or **make the code non-reloadable**, so there is no new object to miss. Code
whose identity must be stable belongs in the autoload once paths, or in `lib`
loaded with an ordinary `require`. In the `VipUser` example above, the real fix
is the reverse of the usual advice though: the problem is not that `VipUser` lives in
`lib`, it is that a non-reloadable class subclasses a reloadable one. Move
`VipUser` into `app` so both reload together.

Which move applies depends on who is holding the reference. If it is your own
application code, moving the class into `app` is usually right. If it is
something outside the reload cycle — the middleware stack, a framework
registry, an engine's configuration — you cannot make that side reload, so pass
a name or make the referent non-reloadable.

WARNING: Do not cache reloadable classes or modules.

Autoloading Without Reloading (`autoload_once_paths`)
-----------------------------------------------------

You may need to be able to autoload classes and modules _without_ reloading them. The `autoload_once_paths` configuration specifies code that can be autoloaded, but won't be reloaded.

By default, the `autoload_once_paths` is empty, but you can add to it by pushing to `config.autoload_once_paths`. You can do so in `config/application.rb` or `config/environments/*.rb`. For example:

```ruby
module MyApplication
  class Application < Rails::Application
    config.autoload_once_paths << "#{root}/app/serializers"
  end
end
```

Engines can do the same, either in the body of the engine class itself or in
their own `config/environments/*.rb` file.

NOTE: If `app/serializers` is pushed to `config.autoload_once_paths`, Rails no longer considers this an autoload path, despite being a custom directory under `app`. The `autoload_once_paths` setting overrides that default.

The need to not reload arises whenever something outside the reload cycle holds
on to your class or module such as the Rails framework, an engine, or a
middleware stack. Reloading such a class produces a new object that is unused.
Making the class non-reloadable removes the discrepancy and ensures there is
only ever one object.

For an example of classes and modules that are cached in places that survive reloads, consider the Active Job serializers which are stored inside Active Job:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

Active Job itself is not reloaded during a reload, only application and engines code in the autoload paths is reloaded.

Making `MoneySerializer` reloadable would be confusing, because reloading an edited version would have no effect on the class object already stored within Active Job.

Another use case for not reloading and using `autoload_once_paths` is when engines decorate framework classes:

```ruby
initializer "decorate ActionController::Base" do
  ActiveSupport.on_load(:action_controller_base) do
    include MyDecoration
  end
end
```

When the above initializer runs, `include` inserts the module object
`MyDecoration` currently refers to into the ancestor chain of
`ActionController::Base`. The chain holds that object directly. If
`MyDecoration` were reloadable, a reload would define a new module, but the
ancestor chain would still hold the original. Controllers would keep running the
version loaded at boot, and your edits to `MyDecordation` would have no effect.

Classes and modules from the autoload once paths are safe to reference in `config/initializers`. For example:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

Initializers run once at boot and never again, so referencing a reloadable
constant there would cause Rails to raise a `NameError`. A constant that is
never reloaded, such as the `MoneySerializer`, has no such problem, and can be used in initializers freely.

INFO: Technically, you can autoload classes and modules managed by the `once` autoloader in any initializer that runs after `:bootstrap_hook`.

### config.autoload_lib_once(ignore:)

The method `config.autoload_lib_once` is similar to `config.autoload_lib`, except that it adds `lib` to `config.autoload_once_paths` instead. It has to be invoked from `config/application.rb` or `config/environments/*.rb`, and it is not available for engines:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    config.autoload_lib_once(ignore: %w(assets tasks))
  end
end
```

NOTE: The `ignore` option works the same as described for [`config.autoload_lib`](#autoloading-lib).

By calling `config.autoload_lib_once`, classes and modules in `lib` can be
autoloaded, even from application initializers, but won't be reloaded. With the
configuration above, `lib/money_serializer.rb` defines `MoneySerializer` with no
`require` call, and because that constant is never replaced, an initializer can
reference it directly:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

The `config.autoload_lib_once` configuration is not available before Rails version 7.1, but you can still emulate it as long as the application uses Zeitwerk:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    lib = root.join("lib")

    config.autoload_once_paths << lib
    config.eager_load_paths << lib

    Rails.autoloaders.once.ignore(
      lib.join("assets"),
      lib.join("tasks"),
      lib.join("generators")
    )

    # ...
  end
end
```

Autoloading When the Application Boots
--------------------------------------

While booting, applications can autoload from the autoload once paths, which are managed by the `once` autoloader. However, during boot you cannot autoload from the paths managed by the `main` autoloader. This applies to code in `config/initializers` as well as initializers declared by application or engines alike.

This is because initializers only run once, when the application boots. They do not run again on reloads. If an initializer used a reloadable class or module, edits to those would not be reflected in that initial code. Therefore, referring to reloadable constants during initialization raises an error (See [Autoloading Without Reloading](#autoloading-without-reloading-autoload-once-paths) section for more).

Let's see some situations in which this comes up and different solutions for it:
when you need reloadable code to run at boot, when you need code at boot that
something outside the reload cycle will keep a reference to, and when an engine
needs to be configured with one of your application classes.

### Loading Reloadable Code During Boot

#### `to_prepare`

Let's imagine `ApiGateway` is a reloadable class and you need to configure its endpoint while the application boots:

```ruby
# config/initializers/api_gateway_setup.rb
ApiGateway.endpoint = "https://example.com" # NameError
```

Since initializers cannot refer to reloadable constants, the above code will generate a `NameError`. The solution is to wrap that in a `to_prepare` block, which runs on boot and after each reload:

```ruby
# config/initializers/api_gateway_setup.rb
Rails.application.config.to_prepare do
  ApiGateway.endpoint = "https://example.com" # CORRECT
end
```

NOTE: For historical reasons, this callback may run twice. The code it executes must be idempotent.

#### `after_initialize`

Reloadable classes and modules can be autoloaded in `after_initialize` blocks
too. These run on boot but not on reload, which is what you want when the work
is a one-time check rather than configuration that must be reapplied to each
reloaded class.

One use case is verifying at startup that the application's environment is
usable, and refusing to start if not:

```ruby
# config/initializers/check_admin_presence.rb
Rails.application.config.after_initialize do
  unless Role.where(name: "admin").exists?
    abort "The admin role is not present, please seed the database."
  end
end
```

### Loading Code That Is Externally Cached

Some configuration takes a class or module object and stores it in an external
place, somewhere the reload cycle never touches (the framework's own state, a
gem's registry). Reloading only replaces constants in the autoload paths, so
anything already holding the old object keeps holding it. If the class you
handed over is reloadable, you have the [stale
object](#reloading-and-stale-objects) problem. One example is middleware:

```ruby
config.middleware.use MyApp::Middleware::Foo
```

When you reload, the middleware stack is not affected. It would be confusing for `MyApp::Middleware::Foo` to be reloadable since changes in its implementation would have no effect.

Another example is Active Job serializers:

```ruby
# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

Whatever `MoneySerializer` evaluates to during initialization gets pushed to the custom serializers, and that object stays unchanged on reloads.

Yet another example are railties or engines decorating framework classes by including modules. For instance, [`turbo-rails`](https://github.com/hotwired/turbo-rails) decorates `ActiveRecord::Base` this way:

```ruby
initializer "turbo.broadcastable" do
  ActiveSupport.on_load(:active_record) do
    include Turbo::Broadcastable
  end
end
```

That adds a module object to the ancestor chain of `ActiveRecord::Base`. Changes in `Turbo::Broadcastable` would have no effect if reloaded, the ancestor chain would still have the original one.

Due to the stale object problem, classes and modules that something outside of the reload cycle keeps a reference to cannot be reloadable.

An idiomatic way to organize these files is to put them in the `lib` directory and load them with `require` where needed. For example, if the application has custom middleware in `lib/middleware`, issue a regular `require` call before configuring it:

```ruby
require "middleware/my_middleware"
config.middleware.use MyMiddleware
```

Additionally, if `lib` is in the autoload paths, configure the autoloader to ignore that subdirectory:

```ruby
# config/application.rb
config.autoload_lib(ignore: %w(assets tasks ... middleware))
```

As noted above, another option is to have the directory that defines them in the autoload once paths and autoload. Please check the [section about config.autoload_once_paths](#autoloading-without-reloading-autoload-once-paths) for details.

### Configuring Application Classes for Engines

Let's suppose an engine works with the reloadable application class that models users, and has a configuration point for it:

```ruby
# config/initializers/my_engine.rb
MyEngine.configure do |config|
  config.user_model = User # NameError
end
```

The above code generates a `NameError` assuming `User` is in autoload paths and hence reloadable.

In order to play well with reloadable application code, the engine can instead refer to the _name_ of that reloadable class:

```ruby
# config/initializers/my_engine.rb
MyEngine.configure do |config|
  config.user_model = "User" # OK
end
```

Then, use `config.user_model.constantize` to get the current class object.

Loading Constants to Allow Single Table Inheritance
---------------------------------------------------

[Single Table Inheritance](association_basics.html#single-table-inheritance-sti) (STI) doesn't play well with lazy loading. Active Record has to be aware of STI model hierarchies to work correctly, but when lazy loading, classes are loaded on demand, meaning Active Record cannot infer the inheritance tree as it needs all relevant classes to be loaded.

To address this fundamental mismatch we need to preload STI models. There are a few options to accomplish this, with different trade-offs. Let's see them.

### Option 1: Enable Eager Loading

The easiest way to preload STI models is to enable eager loading in `config/environments/development.rb` and `config/environments/test.rb`:

```ruby
config.eager_load = true
```

This is simple, but may be costly because it eager loads the entire application on boot and on every reload. The trade-off may be worthwhile for small applications, though.

### Option 2: Preload a Collapsed Directory

You can also store the files that define the hierarchy in a dedicated directory. We eager load these few files on boot and reload even if the STI is not used.

The directory is not meant to represent a namespace, its sole purpose is to group the STI models:

```
app/models/shapes/shape.rb
app/models/shapes/circle.rb
app/models/shapes/square.rb
app/models/shapes/triangle.rb
```

In this example, we still want `app/models/shapes/circle.rb` to define `Circle`, not `Shapes::Circle`. This may be your personal preference to keep things simple, and also avoids having to refactor an existing codebase. The [collapsing](https://github.com/fxn/zeitwerk#collapsing-directories) feature of Zeitwerk allows us to do that:

```ruby
# config/initializers/preload_stis.rb

shapes = "#{Rails.root}/app/models/shapes"
Rails.autoloaders.main.collapse(shapes) # Not a namespace.

unless Rails.application.config.eager_load
  Rails.application.config.to_prepare do
    Rails.autoloaders.main.eager_load_dir(shapes)
  end
end
```

Unless your application has a lot of STI models, this won't have any measurable negative impact of this approach.

INFO: The method `Zeitwerk::Loader#eager_load_dir` was added in Zeitwerk 2.6.2. For older versions, you can still list the `app/models/shapes` directory and invoke `require_dependency` on its contents.

WARNING: If models are added, modified, or deleted from the STI, reloading works as expected. However, if a new separate STI hierarchy is added to the application, you'll need to edit the initializer and restart the server.

### Option 3: Preload a Regular Directory

Similar to the previous option, but the directory is meant to be a namespace. That is, `app/models/shapes/circle.rb` is expected to define `Shapes::Circle`.

For this one, the initializer is the same except no collapsing is configured:

```ruby
# config/initializers/preload_stis.rb

unless Rails.application.config.eager_load
  Rails.application.config.to_prepare do
    Rails.autoloaders.main.eager_load_dir("#{Rails.root}/app/models/shapes")
  end
end
```

Same trade-offs.

### Option 4: Preload Types from the Database

In this option we do not need to organize the files in a new directory, we check the database instead:

```ruby
# config/initializers/preload_stis.rb

unless Rails.application.config.eager_load
  Rails.application.config.to_prepare do
    types = Shape.unscoped.select(:type).distinct.pluck(:type)
    types.compact.each(&:constantize)
  end
end
```

WARNING: The STI will work correctly even if the table does not have all the types, but methods like `subclasses` or `descendants` won't return the missing types.

WARNING: If models are added, modified, or deleted from the STI, reloading works as expected. However, if a new separate STI hierarchy is added to the application, you'll need to edit the initializer and restart the server.

Customizing File Names and Defined Constants
--------------------------------------------

By default, Rails uses `String#camelize` to infer which constant a given file or
directory name defines. For example, `posts_controller.rb` defines
`PostsController` because that is what `"posts_controller".camelize` returns.

You can customize this if a particular file or directory name does not get
inflected as you want. For instance, `"html_parser".camelize` returns
`HtmlParser`. But what if you prefer the class to be `HTMLParser`? There are a
few ways to customize this.

The easiest way is to define acronyms:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "HTML"
  inflect.acronym "SSL"
end
```

Doing so affects how Active Support inflects globally. That may be fine in some applications, but you can also customize how to camelize individual basenames independently from Active Support by passing a collection of overrides to the default inflectors:

```ruby
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    "html_parser" => "HTMLParser",
    "ssl_error"   => "SSLError"
  )
end
```

The above technique still depends on `String#camelize`, though, because that is what the default inflectors use as fallback. If you prefer not to depend on Active Support inflections at all and have absolute control over inflections, configure the inflectors to be instances of `Zeitwerk::Inflector`:

```ruby
Rails.autoloaders.each do |autoloader|
  autoloader.inflector = Zeitwerk::Inflector.new
  autoloader.inflector.inflect(
    "html_parser" => "HTMLParser",
    "ssl_error"   => "SSLError"
  )
end
```

These `Zeitwerk::Inflector` inflectors do not consult
`ActiveSupport::Inflector.inflections`, so no global configuration (from a gem,
engine, or initializer) can change how your files are mapped to constants. The
mapping is determined entirely by the overrides you pass here.

You can even define a custom inflector for full flexibility. Please check the [Zeitwerk documentation](https://github.com/fxn/zeitwerk#custom-inflector) for further details.

### Where Should Inflection Customization Go?

If an application does not use the `once` autoloader, the snippets above can go in `config/initializers`. For example, `config/initializers/inflections.rb` for the Active Support use case, or `config/initializers/zeitwerk.rb` for the Zeitwerk ones.

Applications using the `once` autoloader have to move or load this configuration from the body of the application class in `config/application.rb`, because the `once` autoloader uses the inflector early in the boot process.

Custom Namespaces
-----------------

As we saw above, autoload paths represent the top-level namespace: `Object`. An
autoload path marks the boundary of what the loader manages, and only the
directories _inside_ it act as namespaces.

Let's consider `app/services`, for example. This directory is not generated by
default, but if it exists, Rails automatically adds it to the autoload paths.

By default, the file `app/services/users/signup.rb` defines `Users::Signup`
since `app/services` is the autoload path. But what if you prefer that entire
subtree to be under a `Services` namespace so the above file defines
`Servicess::Users::Signup`?

One workaround to accomplish this can be to create a subdirectory:
`app/services/services`. Since `app/services` is the autoload path, the nested
`services` directory is the first level Zeitwerk sees, and it becomes the
`Services` module, turning `app/services/services/users/signup.rb` into
`Servicess::Users::Signup` as desired.

The placeholder `services` directory approach works, but perhaps you prefer
`app/services` to represent the `Services` namespace. Another option is a
Zietwerk feature that allows `app/services/users/signup.rb` to define
`Services::Users::Signup` directly.

Zeitwerk supports [custom root
namespaces](https://github.com/fxn/zeitwerk#custom-root-namespaces) to address
this use case. You can add a configuration for the `main` autoloader as shown
below. Instead of representing `Object`, the autoload path is configured to
represent a class or module of your choosing, so the file layout stays the same
while everything under that autoload path is namespaced:

```ruby
# config/initializers/autoloading.rb

module Services; end

Rails.autoloaders.main.push_dir("#{Rails.root}/app/services", namespace: Services)
```

The namespace has to exist. In the above example, we define the module on the spot. It could also be created elsewhere and its definition loaded with an ordinary `require`. In any case, `push_dir` expects a class or module object.

NOTE: Since the `Services` directory is defined by you rather than by the
autoloader, it is not reloadable. Keep it empty, or put only code you do not
expect to edit in development in its body.

Rails < 7.1 did not support this feature, but you can still add this additional
code in the same file and get it working. The two extra lines undo what Rails
did automatically for `app/services` — it was added to the autoload paths as a
root namespace directory, and that registration has to be removed before
`push_dir` takes over, while still keeping the directory watched for changes so
reloading works:

```ruby
# Additional code for applications running on Rails < 7.1.
app_services_dir = "#{Rails.root}/app/services" # has to be a string
ActiveSupport::Dependencies.autoload_paths.delete(app_services_dir)
Rails.application.config.watchable_dirs[app_services_dir] = [:rb]
```

Custom namespaces are also supported for the `once` autoloader. However, since that one is set up earlier in the boot process, the configuration cannot be done in an application initializer. Instead, please put it in `config/application.rb`, for example.

Autoloading In Engines
-----------------------

[Engines](https://guides.rubyonrails.org/engines.html) run in the context of a parent application, and their code is autoloaded, reloaded, and eager loaded by the parent application. If the application runs in `zeitwerk` mode, the engine code is loaded by `zeitwerk` mode. If the application runs in `classic` mode, the engine code is loaded by `classic` mode.

TIP: If your engine supports Rails 6 as well as current Rails, you can detect
the parent application's autoloading mode with
`Rails.autoloaders.zeitwerk_enabled?`. The predicate still exists in Rails 7 and
later, where it simply returns `true`.

When Rails boots, engine directories are added to the autoload paths, and from the point of view of the autoloader, there's no difference. Autoloaders' main inputs are the autoload paths, and whether they belong to the application source tree or to some engine source tree is irrelevant.

For example, this application uses the [Devise](https://github.com/heartcombo/devise) gem:

```bash
$ bin/rails runner 'pp ActiveSupport::Dependencies.autoload_paths'
[".../app/controllers",
 ".../app/controllers/concerns",
 ".../app/helpers",
 ".../app/models",
 ".../app/models/concerns",
 ".../gems/devise-4.8.0/app/controllers",
 ".../gems/devise-4.8.0/app/helpers",
 ".../gems/devise-4.8.0/app/mailers"]
 ```

If the engine controls the autoloading mode of its parent application, the engine can be written as usual. However, if an engine supports Rails 6 or Rails 6.1 and does not control its parent applications, it has to be ready to run under either `classic` or `zeitwerk` mode. Things to take into account:

1. If `classic` mode would need a `require_dependency` call to ensure some constant is loaded at some point, write it. While `zeitwerk` would not need it, it won't hurt, it will work in `zeitwerk` mode too.

2. `classic` mode underscores constant names ("User" -> "user.rb"), and `zeitwerk` mode camelizes file names ("user.rb" -> "User"). They coincide in most cases, but they don't if there are series of consecutive uppercase letters as in "HTMLParser". The easiest way to be compatible is to avoid such names. In this case, pick "HtmlParser".

3. In `classic` mode, the file `app/model/concerns/foo.rb` is allowed to define both `Foo` and `Concerns::Foo`. In `zeitwerk` mode, there's only one option: it has to define `Foo`. In order to be compatible, define `Foo`.

Testing and Troubleshooting
---------------------------

### Using `zeitwerk:check`

The task `zeitwerk:check` checks if the project tree follows the expected naming conventions and it is handy for manual checks. For example, if you're migrating from `classic` to `zeitwerk` mode, or if you're fixing something:

```bash
$ bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

There can be additional output depending on the application configuration, but the last "All is good!" is what you are looking for.

### Automated Testing

It is a good practice to verify in the test suite that the project eager loads correctly.

That covers Zeitwerk naming compliance and other possible error conditions. Please check the [section about testing eager loading](testing.html#testing-eager-loading) in the [_Testing Rails Applications_](testing.html) guide.

### Inspecting Autoloading Logs

The best way to follow what the loaders are doing is to inspect their activity
after loading the framework defaults:

```ruby
# config/application.rb
Rails.autoloaders.log!
```

That will print traces to standard output. You can also log to a file instead:

```ruby
Rails.autoloaders.logger = Logger.new("#{Rails.root}/log/autoloading.log")
```

The Rails logger is not yet available when `config/application.rb` executes. If you prefer to use the Rails logger, configure this setting in an initializer:

```ruby
# config/initializers/log_autoloaders.rb
Rails.autoloaders.logger = Rails.logger
```

How Zeitwerk Interfaces with Rails (`Rails.autoloaders`)
--------------------------------------------------------

Zeitwerk is an independent library with its own public API. Rails does not wrap
that API in Rails specific configuration settings. Instead, it exposes the two
loader objects it sets up and lets you call Zeitwerk's methods on them directly:

```ruby
Rails.autoloaders.main
Rails.autoloaders.once
```

These accessors are the interface between Rails and Zeitwerk. Anything Rails
configures for you — the autoload paths, the autoload once paths, reloading,
eager loading — has a Rails setting. Anything beyond that is Zeitwerk's
API, reached through these objects, as we've seen with these examples:

```ruby
# Treat a directory as organizational rather than as a namespace.
Rails.autoloaders.main.collapse("#{Rails.root}/app/models/shapes")

# Map an autoload path to a namespace other than Object.
Rails.autoloaders.main.push_dir("#{Rails.root}/app/services", namespace: Services)

# Override how file names are converted to constant names.
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect("html_parser" => "HTMLParser")
end
```

NOTE: `Rails.autoloaders` also responds to `each`, which is useful when a
customization should apply to both loaders, as in the inflector example above.

For anything not documented in this guide, consult the [Zeitwerk
documentation](https://github.com/fxn/zeitwerk) and call the method on the
loader you want it applied to.
