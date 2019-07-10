**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Autoloading and Reloading Constants (Zeitwerk Mode)
======================================================

This guide documents how autoloading and reloading works in `zeitwerk` mode.

After reading this guide, you will know:

* Autoloading modes
* Related Rails configuration
* File system conventions
* Autoloading in `zeitwerk` mode
* Reloading in `zeitwerk` mode
* Eager loading in `zeitwerk` mode
* Single Table Inheritance
* File path to constant path inflection


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
config.load_defaults "6.x" # enables zeitwerk mode in CRuby
```

In `zeitwerk` mode, Rails uses [Zeitwerk](https://github.com/fxn/zeitwerk) internally to autoload, reload, and eager load. Rails instantiates and configures a dedicated Zeitwerk instance that manages the project.

INFO. You do not configure Zeitwerk manually in a Rails application. Rather, you configure the application using the portable configuration points explained in this guide, and Rails translates that to Zeitwerk on your behalf.


Autoload paths
--------------

We call _autoload paths_ to the list of application directories whose contents are to be autoloaded. For example, `app/models`. Such directories represent the root namespace: `Object`.

INFO. Autoload paths are called _root directories_ in Zeitwerk documentation, but we'll stay with "autoload path" in this guide.

Within an autoload path, file names must match the constants they define as documented [here](https://github.com/fxn/zeitwerk#file-structure).

By default, the autoload paths of an application consist of all the subdirectories of `app` that exist when the application boots ---except for `aasets`, `javascripts`, `views`,--- plus the autoload paths of engines it might depend on.

For example, if `UsersHelper` is implemented in `app/helpers/users_helper.rb`, the module is autoloadable, you do not need (and should not write) a `require` call for it:

```
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

However, you can force a reload in the console executing `reload!`:

```
$ bin/rails c
Loading development environment (Rails 6.0.0)
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

Therefore, if you store a reloadable class or module object in a place that is not reloaded, that value is going to become stale.

For example, if an initializer stores and caches a certain class object

```ruby
# config/initializers/configure_payment_gateway.rb
# DO NOT DO THIS.
$PAYMENT_GATEWAY = Rails.env.production? ? RealGateway : MockedGateway
# DO NOT DO THIS.
```

and `MockedGateway` gets reloaded, `$PAYMENT_GATEWAY` still stores the class object `MockedGateway` evaluated to when the initializer ran. Reloading does not change the class object stored in `$PAYMENT_GATEWAY`.

Similarly, in the Rails console, if you have a user instance and reload:

```
> user = User.new
> reload!
```

the `user` object is instance of a stale class object. Ruby gives you a new class if you evaluate `User` again, but does not update the class `user` is instance of.

Another use case of this gotcha is subclassing reloadable classes in a place that is not reloaded:

```ruby
# lib/vip_user.rb
class VipUser < User
end
```

if `User` is reloaded, since `VipUser` is not, the superclass of `VipUser` is the original stale class object.

Bottom line: **do not cache reloadable classes or modules**.


Eager Loading
-------------

In production-like environments it is generally better to load all the application code when the application boots. Eager loading puts everything in memory ready to serve requests right away, and it is also [CoW](https://en.wikipedia.org/wiki/Copy-on-write)-friendly.

Eager loading is controlled by the flag `config.eager_load`, which is enabled by default in `production` mode.

The order in which files are eager loaded is undefined.

if the `Zeitwerk` constant is defined, Rails invokes `Zeitwerk::Loader.eager_load_all` regardless of the application autoloading mode. That ensures dependencies managed by Zeitwerk are eager loaded.


Single Table Inheritance
------------------------

TODO


Inflector
---------

Rails configures Zeitwerk to inflect file names with `String#camelize`. For example, it expects that `users_controller.rb` defines the constant `UsersController` because

```ruby
"users_controller".camelize # => UsersController
```

If you need to customize any of these inflections, for example to add an acronym, please have a look at `config/initializers/inflections.rb`.


Rails.autoloaders
-----------------

The Zeitwerk instances managing your application are availabe at

```ruby
Rails.autoloaders.main
Rails.autoloaders.once
```

The former is the main one. The latter is there mostly for backwards compatibily reasons, in case the application has something in `config.autoload_once_paths` (this is discouraged nowadays).

You can check if `zeitwerk` mode is enabled with

```ruby
Rails.autoloaders.zeitwerk_enabled?
```

Opting Out
----------

You can load Rails 6 defaults and still use the classic autoloader this way:

```ruby
# config/application.rb
config.load_defaults "6.x"
config.autoloader = :classic
```

That may be handy if upgrading to Rails 6 in different phases, but classic mode is discouraged for new applications.

`zeitwerk` mode is not available in versions of Rails previous to 6.0.
