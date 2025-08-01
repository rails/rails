**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 5.2 to Rails 6.0
=====================================

This guide provides steps to be followed when you upgrade your applications from Rails 5.2 to Rails 6.0. These steps are also available in individual release guides.

--------------------------------------------------------------------------------

Key Changes
-----------

For more information on changes made to Rails 6.0 please see the [release notes](6_0_release_notes.html).

### Using Webpacker

[Webpacker](https://github.com/rails/webpacker)
is the default JavaScript compiler for Rails 6. But if you are upgrading the app, it is not activated by default.
If you want to use Webpacker, then include it in your Gemfile and install it:

```ruby
gem "webpacker"
```

```bash
$ bin/rails webpacker:install
```

### Force SSL

The `force_ssl` method on controllers has been deprecated and will be removed in
Rails 6.1. You are encouraged to enable [`config.force_ssl`][] to enforce HTTPS
connections throughout your application. If you need to exempt certain endpoints
from redirection, you can use [`config.ssl_options`][] to configure that behavior.

[`config.force_ssl`]: configuring.html#config-force-ssl
[`config.ssl_options`]: configuring.html#config-ssl-options

### Purpose and expiry metadata is now embedded inside signed and encrypted cookies for increased security

To improve security, Rails embeds the purpose and expiry metadata inside encrypted or signed cookies value.

Rails can then thwart attacks that attempt to copy the signed/encrypted value
of a cookie and use it as the value of another cookie.

This new embed metadata make those cookies incompatible with versions of Rails older than 6.0.

If you require your cookies to be read by Rails 5.2 and older, or you are still validating your 6.0 deploy and want
to be able to rollback set
`Rails.application.config.action_dispatch.use_cookies_with_metadata` to `false`.

### All npm packages have been moved to the `@rails` scope

If you were previously loading any of the `actioncable`, `activestorage`,
or `rails-ujs` packages through npm/yarn, you must update the names of these
dependencies before you can upgrade them to `6.0.0`:

```
actioncable   → @rails/actioncable
activestorage → @rails/activestorage
rails-ujs     → @rails/ujs
```

### Action Cable JavaScript API Changes

The Action Cable JavaScript package has been converted from CoffeeScript
to ES2015, and we now publish the source code in the npm distribution.

This release includes some breaking changes to optional parts of the
Action Cable JavaScript API:

- Configuration of the WebSocket adapter and logger adapter have been moved
  from properties of `ActionCable` to properties of `ActionCable.adapters`.
  If you are configuring these adapters you will need to make
  these changes:

    ```diff
    -    ActionCable.WebSocket = MyWebSocket
    +    ActionCable.adapters.WebSocket = MyWebSocket
    ```

    ```diff
    -    ActionCable.logger = myLogger
    +    ActionCable.adapters.logger = myLogger
    ```

- The `ActionCable.startDebugging()` and `ActionCable.stopDebugging()`
  methods have been removed and replaced with the property
  `ActionCable.logger.enabled`. If you are using these methods you
  will need to make these changes:

    ```diff
    -    ActionCable.startDebugging()
    +    ActionCable.logger.enabled = true
    ```

    ```diff
    -    ActionCable.stopDebugging()
    +    ActionCable.logger.enabled = false
    ```

### `ActionDispatch::Response#content_type` now returns the Content-Type header without modification

Previously, the return value of `ActionDispatch::Response#content_type` did NOT contain the charset part.
This behavior has changed to include the previously omitted charset part as well.

If you want just the MIME type, please use `ActionDispatch::Response#media_type` instead.

Before:

```ruby
resp = ActionDispatch::Response.new(200, "Content-Type" => "text/csv; header=present; charset=utf-16")
resp.content_type #=> "text/csv; header=present"
```

After:

```ruby
resp = ActionDispatch::Response.new(200, "Content-Type" => "text/csv; header=present; charset=utf-16")
resp.content_type #=> "text/csv; header=present; charset=utf-16"
resp.media_type   #=> "text/csv"
```

### New `config.hosts` setting

Rails now has a new `config.hosts` setting for security purposes. This setting
defaults to `localhost` in development. If you use other domains in development
you need to allow them like this:

```ruby
# config/environments/development.rb

config.hosts << "dev.myapp.com"
config.hosts << /[a-z0-9-]+\.myapp\.com/ # Optionally, regexp is allowed as well
```

For other environments `config.hosts` is empty by default, which means Rails
won't validate the host at all. You can optionally add them if you want to
validate it in production.

### Autoloading

The default configuration for Rails 6

```ruby
# config/application.rb

config.load_defaults 6.0
```

enables `zeitwerk` autoloading mode on CRuby. In that mode, autoloading, reloading, and eager loading are managed by [Zeitwerk](https://github.com/fxn/zeitwerk).

If you are using defaults from a previous Rails version, you can enable zeitwerk like so:

```ruby
# config/application.rb

config.autoloader = :zeitwerk
```

#### Public API

In general, applications do not need to use the API of Zeitwerk directly. Rails sets things up according to the existing contract: `config.autoload_paths`, `config.cache_classes`, etc.

While applications should stick to that interface, the actual Zeitwerk loader object can be accessed as

```ruby
Rails.autoloaders.main
```

That may be handy if you need to preload Single Table Inheritance (STI) classes or configure a custom inflector, for example.

#### Project Structure

If the application being upgraded autoloads correctly, the project structure should be already mostly compatible.

However, `classic` mode infers file names from missing constant names (`underscore`), whereas `zeitwerk` mode infers constant names from file names (`camelize`). These helpers are not always inverse of each other, in particular if acronyms are involved. For instance, `"FOO".underscore` is `"foo"`, but `"foo".camelize` is `"Foo"`, not `"FOO"`.

Compatibility can be checked with the `zeitwerk:check` task:

```bash
$ bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

#### require_dependency

All known use cases of `require_dependency` have been eliminated, you should grep the project and delete them.

If your application uses Single Table Inheritance, please see the [Single Table Inheritance section](autoloading_and_reloading_constants.html#single-table-inheritance) of the Autoloading and Reloading Constants (Zeitwerk Mode) guide.

#### Qualified names in class and module definitions

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

#### Concerns

You can autoload and eager load from a standard structure like

```
app/models
app/models/concerns
```

In that case, `app/models/concerns` is assumed to be a root directory (because it belongs to the autoload paths), and it is ignored as namespace. So, `app/models/concerns/foo.rb` should define `Foo`, not `Concerns::Foo`.

The `Concerns::` namespace worked with the classic autoloader as a side-effect of the implementation, but it was not really an intended behavior. An application using `Concerns::` needs to rename those classes and modules to be able to run in `zeitwerk` mode.

#### Having `app` in the autoload paths

Some projects want something like `app/api/base.rb` to define `API::Base`, and add `app` to the autoload paths to accomplish that in `classic` mode. Since Rails adds all subdirectories of `app` to the autoload paths automatically, we have another situation in which there are nested root directories, so that setup no longer works. Similar principle we explained above with `concerns`.

If you want to keep that structure, you'll need to delete the subdirectory from the autoload paths in an initializer:

```ruby
ActiveSupport::Dependencies.autoload_paths.delete("#{Rails.root}/app/api")
```

#### Autoloaded Constants and Explicit Namespaces

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

#### One file, one constant (at the same top-level)

In `classic` mode you could technically define several constants at the same top-level and have them all reloaded. For example, given

```ruby
# app/models/foo.rb

class Foo
end

class Bar
end
```

while `Bar` could not be autoloaded, autoloading `Foo` would mark `Bar` as autoloaded too. This is not the case in `zeitwerk` mode, you need to move `Bar` to its own file `bar.rb`. One file, one constant.

This only applies to constants at the same top-level as in the example above. Inner classes and modules are fine. For example, consider

```ruby
# app/models/foo.rb

class Foo
  class InnerClass
  end
end
```

If the application reloads `Foo`, it will reload `Foo::InnerClass` too.

#### Spring and the `test` Environment

Spring reloads the application code if something changes. In the `test` environment you need to enable reloading for that to work:

```ruby
# config/environments/test.rb

config.cache_classes = false
```

Otherwise you'll get this error:

```
reloading is disabled because config.cache_classes is true
```

#### Bootsnap

Bootsnap should be at least version 1.4.2.

In addition to that, Bootsnap needs to disable the iseq cache due to a bug in the interpreter if running Ruby 2.5. Please make sure to depend on at least Bootsnap 1.4.4 in that case.

#### `config.add_autoload_paths_to_load_path`

The new configuration point [`config.add_autoload_paths_to_load_path`][] is `true` by default for backwards compatibility, but allows you to opt-out from adding the autoload paths to `$LOAD_PATH`.

This makes sense in most applications, since you never should require a file in `app/models`, for example, and Zeitwerk only uses absolute file names internally.

By opting-out you optimize `$LOAD_PATH` lookups (less directories to check), and save Bootsnap work and memory consumption, since it does not need to build an index for these directories.

[`config.add_autoload_paths_to_load_path`]: configuring.html#config-add-autoload-paths-to-load-path

#### Thread-safety

In classic mode, constant autoloading is not thread-safe, though Rails has locks in place for example to make web requests thread-safe when autoloading is enabled, as it is common in the development environment.

Constant autoloading is thread-safe in `zeitwerk` mode. For example, you can now autoload in multi-threaded scripts executed by the `runner` command.

#### Globs in config.autoload_paths

Beware of configurations like

```ruby
config.autoload_paths += Dir["#{config.root}/lib/**/"]
```

Every element of `config.autoload_paths` should represent the top-level namespace (`Object`) and they cannot be nested in consequence (with the exception of `concerns` directories explained above).

To fix this, just remove the wildcards:

```ruby
config.autoload_paths << "#{config.root}/lib"
```

#### Eager loading and autoloading are consistent

In `classic` mode, if `app/models/foo.rb` defines `Bar`, you won't be able to autoload that file, but eager loading will work because it loads files recursively blindly. This can be a source of errors if you test things first eager loading, execution may fail later autoloading.

In `zeitwerk` mode both loading modes are consistent, they fail and err in the same files.

#### How to Use the Classic Autoloader in Rails 6

Applications can load Rails 6 defaults and still use the classic autoloader by setting `config.autoloader` this way:

```ruby
# config/application.rb

config.load_defaults 6.0
config.autoloader = :classic
```

When using the Classic Autoloader in Rails 6 application it is recommended to set concurrency level to 1 in development environment, for the web servers and background processors, due to the thread-safety concerns.

### Active Storage assignment behavior change

With the configuration defaults for Rails 5.2, assigning to a collection of attachments declared with `has_many_attached` appends new files:

```ruby
class User < ApplicationRecord
  has_many_attached :highlights
end

user.highlights.attach(filename: "funky.jpg")
user.highlights.count # => 1

blob = ActiveStorage::Blob.create_after_upload!(filename: "town.jpg")
user.update!(highlights: [ blob ])

user.highlights.count # => 2
user.highlights.first.filename # => "funky.jpg"
user.highlights.second.filename # => "town.jpg"
```

With the configuration defaults for Rails 6.0, assigning to a collection of attachments replaces existing files instead of appending to them. This matches Active Record behavior when assigning to a collection association:

```ruby
user.highlights.attach(filename: "funky.jpg")
user.highlights.count # => 1

blob = ActiveStorage::Blob.create_after_upload!(filename: "town.jpg")
user.update!(highlights: [ blob ])

user.highlights.count # => 1
user.highlights.first.filename # => "town.jpg"
```

`#attach` can be used to add new attachments without removing the existing ones:

```ruby
blob = ActiveStorage::Blob.create_after_upload!(filename: "town.jpg")
user.highlights.attach(blob)

user.highlights.count # => 2
user.highlights.first.filename # => "funky.jpg"
user.highlights.second.filename # => "town.jpg"
```

Existing applications can opt in to this new behavior by setting [`config.active_storage.replace_on_assign_to_many`][] to `true`. The old behavior will be deprecated in Rails 7.0 and removed in Rails 7.1.

[`config.active_storage.replace_on_assign_to_many`]: configuring.html#config-active-storage-replace-on-assign-to-many

### Custom exception handling applications

Invalid `Accept` or `Content-Type` request headers will now raise an exception.
The default [`config.exceptions_app`][] specifically handles that error and compensates for it.
Custom exceptions applications will need to handle that error as well, or such requests will cause Rails to use the fallback exceptions application, which returns a `500 Internal Server Error`.

[`config.exceptions_app`]: configuring.html#config-exceptions-app