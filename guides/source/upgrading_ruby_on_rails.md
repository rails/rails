**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading Ruby on Rails
=======================

This guide provides steps to be followed when you upgrade your applications to a newer version of Ruby on Rails. These steps are also available in individual release guides.

--------------------------------------------------------------------------------

General Advice
--------------

Before attempting to upgrade an existing application, you should be sure you have a good reason to upgrade. You need to balance several factors: the need for new features, the increasing difficulty of finding support for old code, and your available time and skills, to name a few.

### Test Coverage

The best way to be sure that your application still works after upgrading is to have good test coverage before you start the process. If you don't have automated tests that exercise the bulk of your application, you'll need to spend time manually exercising all the parts that have changed. In the case of a Rails upgrade, that will mean every single piece of functionality in the application. Do yourself a favor and make sure your test coverage is good _before_ you start an upgrade.

### Ruby Versions

Rails generally stays close to the latest released Ruby version when it's released:

* Rails 8.0 and 8.1 require Ruby 3.2.0 or newer.
* Rails 7.2 requires Ruby 3.1.0 or newer.
* Rails 7.0 and 7.1 require Ruby 2.7.0 or newer.
* Rails 6 requires Ruby 2.5.0 or newer.
* Rails 5 requires Ruby 2.2.2 or newer.

It's a good idea to upgrade Ruby and Rails separately. Upgrade to the latest Ruby you can first, and then upgrade Rails.

### The Upgrade Process

When changing Rails versions, it's best to move slowly, one minor version at a time, in order to make good use of the deprecation warnings. Rails version numbers are in the form Major.Minor.Patch. Major and Minor versions are allowed to make changes to the public API, so this may cause errors in your application. Patch versions only include bug fixes, and don't change any public API.

The process should go as follows:

1. Write tests and make sure they pass.
2. Move to the latest patch version after your current version.
3. Fix tests and deprecated features.
4. Move to the latest patch version of the next minor version.

Repeat this process until you reach your target Rails version.

#### Moving between versions

To move between versions:

1. Change the Rails version number in the `Gemfile` and run `bundle update rails`.
2. Change the versions for Rails JavaScript packages in `package.json` and run `bin/rails javascript:install` if running jsbundling-rails.
3. Run the [Update task](#the-update-task).
4. Run your tests.

You can find a list of all released Rails gems [here](https://rubygems.org/gems/rails/versions).

### The Update Task

Rails provides the `bin/rails app:update` command, which should be run after updating the Rails version
in the `Gemfile`. This will help you manage any changes in an interactive session.

```bash
$ bin/rails app:update
       exist  config
    conflict  config/application.rb
Overwrite /myapp/config/application.rb? (enter "h" for help) [Ynaqdh]
       force  config/application.rb
      create  config/initializers/new_framework_defaults_8_0.rb
...
```

Don't forget to review the difference to see if there were any unexpected changes. Note that the tools used during this process can be defined using the `THOR_DIFF` and `THOR_MERGE` environment variables. For example:

```bash
# Use VS Code
$ export THOR_DIFF="code --diff"
$ export THOR_MERGE="code --merge" 
$ bin/rails app:update

# Use vimdiff
$ export THOR_DIFF="vimdiff"
$ export THOR_MERGE="vimdiff"
$ bin/rails app:update
```

NOTE: The `bin/rails app:update` command is only relevant when changing between releases (e.g. 8.0 to 8.1) and not between patch level versions (e.g. 7.1.2 to 7.1.3).

### Configure Framework Defaults

The new Rails version might have different configuration defaults than the previous version. However, after following the steps described above, your application would still run with configuration defaults from the *previous* Rails version. That's because the value for `config.load_defaults` in `config/application.rb` has not been changed yet.

To allow you to upgrade to new defaults one by one, the update task has created a file `config/initializers/new_framework_defaults_X_Y.rb` (with the desired Rails version in the filename). You should enable the new configuration defaults by uncommenting them in the file; this can be done gradually over several deployments. Once your application is ready to run with new defaults, you can remove this file and flip the `config.load_defaults` value.

Upgrading from Rails 8.1 to Rails 8.2
-------------------------------------

For more information on changes made to Rails 8.2 please see the [release notes](8_2_release_notes.html).

### The negative scopes for enums now include records with `nil` values.

Active Record negative scopes for enums now include records with `nil` values.

```ruby
class Book < ApplicationRecord
  enum :status, [:proposed, :written, :published]
end

book1 = Book.create!(status: :published)
book2 = Book.create!(status: :written)
book3 = Book.create!(status: nil)

# Before

Book.not_published # => [book2]

# After

Book.not_published # => [book2, book3]
```

Upgrading from Rails 8.0 to Rails 8.1
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 8.1 please see the [release notes](8_1_release_notes.html).

### The table columns inside `schema.rb` are now sorted alphabetically.

Active Record now alphabetically sorts table columns in `schema.rb` by default, so dumps are consistent across machines and don’t flip-flop with migration order -- meaning fewer noisy diffs. `structure.sql` can still be leveraged to preserve exact column order. [See #53281 for more details on alphabetizing schema changes.](https://github.com/rails/rails/pull/53281)

Upgrading from Rails 7.2 to Rails 8.0
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 8.0 please see the [release notes](8_0_release_notes.html).

Upgrading from Rails 7.1 to Rails 7.2
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 7.2 please see the [release notes](7_2_release_notes.html).

### All tests now respect the `active_job.queue_adapter` config

If you have set `config.active_job.queue_adapter` in your `config/application.rb` or `config/environments/test.rb` file,
the adapter you selected was previously not used consistently across all tests. In some tests your adapter would be
used, but other tests would use the `TestAdapter`.

In Rails 7.2, all tests will respect the `queue_adapter` config if provided. This may cause test errors, if you had
set the `queue_adapter` config to something other than `:test`, but written tests in a way that was dependent on the `TestAdapter`.

If no config is provided, the `TestAdapter` will continue to be used.

### `alias_attribute` now bypasses custom methods on the original attribute

In Rails 7.2, `alias_attribute` now bypasses custom methods defined on the original attribute and directly accesses the underlying database value. This change was announced via deprecation warnings in Rails 7.1.

**Before (Rails 7.1):**

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  alias_attribute :username, :email
end

user = User.create!(email: "test@example.com")
user.username
# => "custom_test@example.com"
```

**After (Rails 7.2):**

```ruby
user = User.create!(email: "test@example.com")
user.username
# => "test@example.com"  # Raw database value
```

If you received the deprecation warning "Since Rails 7.2 `#{method_name}` will not be calling `#{target_name}` anymore", you should manually define the alias method:

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  def username
    email  # This will call the custom email method
  end
end
```

Alternatively, you can use `alias_method`:

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  alias_method :username, :email
end
```

Upgrading from Rails 7.0 to Rails 7.1
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 7.1 please see the [release notes](7_1_release_notes.html).

### Development and test environments secret_key_base file changed

In development and test environments, the file from which Rails reads the `secret_key_base` has been renamed from `tmp/development_secret.txt` to `tmp/local_secret.txt`.

You can simply rename the previous file to `local_secret.txt` to continue using the same secret, or copy the key from the previous file to the new one.

Failure to do so will cause Rails to generate a new secret key in the new file `tmp/local_secret.txt` when the app loads.

This will invalidate all existing sessions/cookies in development and test environments, and also cause other signatures derived from `secret_key_base` to break, such as Active Storage/Action Text attachments.

Production and other environments are not affected.

### New ActiveSupport::Cache serialization format

A new 7.1 cache format is available which includes an optimization for bare string values such as view fragments.

The 7.1 cache format is used by default for new apps, and existing apps can enable the format by setting `config.load_defaults 7.1` or by setting `config.active_support.cache_format_version = 7.1` in `config/application.rb` or a `config/environments/*.rb` file.

Cache entries written using the 6.1 or 7.0 cache formats can be read when using the 7.1 format. To perform a rolling deploy of a Rails 7.1 upgrade, wherein servers that have not yet been upgraded must be able to read caches from upgraded servers, leave the cache format unchanged on the first deploy, then enable the 7.1 cache format on a subsequent deploy.

### Autoloaded paths are no longer in $LOAD_PATH

Starting from Rails 7.1, the directories managed by the autoloaders are no
longer added to `$LOAD_PATH`. This means it won't be possible to load their
files with a manual `require` call, which shouldn't be done anyway.

Reducing the size of `$LOAD_PATH` speeds up `require` calls for apps not using
`bootsnap`, and reduces the size of the `bootsnap` cache for the others.

If you'd like to have these paths still in `$LOAD_PATH`, you can opt-in:

```ruby
config.add_autoload_paths_to_load_path = true
```

but we discourage doing so, classes and modules in the autoload paths are meant
to be autoloaded. That is, just reference them.

The `lib` directory is not affected by this flag, it is added to `$LOAD_PATH`
always.

### config.autoload_lib and config.autoload_lib_once

If your application does not have `lib` in the autoload or autoload once paths,
please skip this section. You can find that out by inspecting the output of

```bash
# Print autoload paths.
$ bin/rails runner 'pp Rails.autoloaders.main.dirs'

# Print autoload once paths.
$ bin/rails runner 'pp Rails.autoloaders.once.dirs'
```

If your application already has `lib` in the autoload paths, normally there is
configuration in `config/application.rb` that looks something like

```ruby
# Autoload lib, but do not eager load it (maybe overlooked).
config.autoload_paths << config.root.join("lib")
```

or

```ruby
# Autoload and also eager load lib.
config.autoload_paths << config.root.join("lib")
config.eager_load_paths << config.root.join("lib")
```

or

```ruby
# Same, because all eager load paths become autoload paths too.
config.eager_load_paths << config.root.join("lib")
```

That still works, but it is recommended to replace those lines with the more
concise

```ruby
config.autoload_lib(ignore: %w(assets tasks))
```

Please, add to the `ignore` list any other `lib` subdirectories that do not
contain `.rb` files, or that should not be reloaded or eager loaded. For
example, if your application has `lib/templates`, `lib/generators`, or
`lib/middleware`, you'd add their name relative to `lib`:

```ruby
config.autoload_lib(ignore: %w(assets tasks templates generators middleware))
```

With that one-liner, the (non-ignored) code in `lib` will be also eager loaded
if `config.eager_load` is `true` (the default in `production` mode). This is
normally what you want, but if `lib` was not added to the eager load paths
before and you still want it that way, please opt-out:

```ruby
Rails.autoloaders.main.do_not_eager_load(config.root.join("lib"))
```

The method `config.autoload_lib_once` is the analogous one if the application
had `lib` in `config.autoload_once_paths`.

### `ActiveStorage::BaseController` no longer includes the streaming concern

Application controllers that inherit from `ActiveStorage::BaseController` and use streaming to implement custom file serving logic must now explicitly include the `ActiveStorage::Streaming` module.

### `MemCacheStore` and `RedisCacheStore` now use connection pooling by default

The `connection_pool` gem has been added as a dependency of the `activesupport` gem,
and the `MemCacheStore` and `RedisCacheStore` now use connection pooling by default.

If you don't want to use connection pooling, set `:pool` option to `false` when
configuring your cache store:

```ruby
config.cache_store = :mem_cache_store, "cache.example.com", { pool: false }
```

See the [caching with Rails](https://guides.rubyonrails.org/v7.1/caching_with_rails.html#connection-pool-options) guide for more information.

### `SQLite3Adapter` now configured to be used in a strict strings mode

The use of a strict strings mode disables double-quoted string literals.

SQLite has some quirks around double-quoted string literals.
It first tries to consider double-quoted strings as identifier names, but if they don't exist
it then considers them as string literals. Because of this, typos can silently go unnoticed.
For example, it is possible to create an index for a non existing column.
See [SQLite documentation](https://www.sqlite.org/quirks.html#double_quoted_string_literals_are_accepted) for more details.

If you don't want to use `SQLite3Adapter` in a strict mode, you can disable this behavior:

```ruby
# config/application.rb
config.active_record.sqlite3_adapter_strict_strings_by_default = false
```

### Support multiple preview paths for `ActionMailer::Preview`

Option `config.action_mailer.preview_path` is deprecated in favor of `config.action_mailer.preview_paths`. Appending paths to this configuration option will cause those paths to be used in the search for mailer previews.

```ruby
config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
```

### `config.i18n.raise_on_missing_translations = true` now raises on any missing translation.

Previously it would only raise when called in a view or controller. Now it will raise anytime `I18n.t` is provided an unrecognized key.

```ruby
# with config.i18n.raise_on_missing_translations = true

# in a view or controller:
t("missing.key") # raises in 7.0, raises in 7.1
I18n.t("missing.key") # didn't raise in 7.0, raises in 7.1

# anywhere:
I18n.t("missing.key") # didn't raise in 7.0, raises in 7.1
```

If you don't want this behavior, you can set `config.i18n.raise_on_missing_translations = false`:

```ruby
# with config.i18n.raise_on_missing_translations = false

# in a view or controller:
t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1
I18n.t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1

# anywhere:
I18n.t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1
```

Alternatively, you can customize the `I18n.exception_handler`.
See the [i18n guide](https://guides.rubyonrails.org/v7.1/i18n.html#using-different-exception-handlers) for more information.

`AbstractController::Translation.raise_on_missing_translations` has been removed. This was a private API, if you were
relying on it you should migrate to `config.i18n.raise_on_missing_translations` or to a custom exception handler.

### `bin/rails test` now runs `test:prepare` task

When running tests via `bin/rails test`, the `rake test:prepare` task will run before tests run. If you've enhanced
the `test:prepare` task, your enhancements will run before your tests. `tailwindcss-rails`, `jsbundling-rails`, and `cssbundling-rails`
enhance this task, as do other third party gems.

See the [Testing Rails Applications](https://guides.rubyonrails.org/testing.html#running-tests-in-continuous-integration-ci) guide for more information.

If you run a single file's tests (`bin/rails test test/models/user_test.rb`), `test:prepare` will not run before it.

### Import syntax from `@rails/ujs` is modified

Starting from Rails 7.1, the syntax for importing modules from `@rails/ujs` is modified. Rails no longer supports the
direct import of a module from `@rails/ujs`.

For example, attempting to import a function from the library will fail:

```javascript
import { fileInputSelector } from "@rails/ujs"
// ERROR: export 'fileInputSelector' (imported as 'fileInputSelector') was not found in '@rails/ujs' (possible exports: default)
```

In Rails 7.1, users should first import the Rails object directly from `@rails/ujs`.
Users can then import specific modules from the Rails object.

An example of imports in Rails 7.1 is shown below:

```javascript
import Rails from "@rails/ujs"
// Alias the method
const fileInputSelector = Rails.fileInputSelector
// Alternatively, reference it from the Rails object where it is used
Rails.fileInputSelector(...)
```

### `Rails.logger` now returns an `ActiveSupport::BroadcastLogger` instance

The `ActiveSupport::BroadcastLogger` class is a new logger that allows to broadcast logs to different sinks (STDOUT, a log file...) in an easy way.

The API to broadcast logs (using the `ActiveSupport::Logger.broadcast` method) was removed and was previously private.
If your application or library was relying on this API, you need to make the following changes:

```ruby
logger = Logger.new("some_file.log")

# Before

Rails.logger.extend(ActiveSupport::Logger.broadcast(logger))

# After

Rails.logger.broadcast_to(logger)
```

If your application had configured a custom logger, `Rails.logger` will wrap and proxy all methods to it. No changes on your side are required to make it work.

If you need to access your custom logger instance, you can do so using the `broadcasts` method:

```ruby
# config/application.rb
config.logger = MyLogger.new

# Anywhere in your application
puts Rails.logger.class #=> BroadcastLogger
puts Rails.logger.broadcasts #=> [MyLogger]
```

[assert_match]: https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-assert_match


### Active Record Encryption algorithm changes

Active Record Encryption now uses SHA-256 as its hash digest algorithm. If you have data encrypted with previous Rails
versions, there are two scenarios to consider:

1. If you have `config.active_support.key_generator_hash_digest_class` configured as SHA-1 (the default
   before Rails 7.0), you need to configure SHA-1 for Active Record Encryption too:

    ```ruby
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1
    ```

    If all of your data was encrypted non-deterministicly (the default unless `encrypts` is passed `deterministic: true`, you can instead configure SHA-256 for Active Record Encryption as in scenario 2 below and also allow columns previously encrypted with SHA-1 to be decrypted by setting:

    ```ruby
    config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
    ```

2. If you have `config.active_support.key_generator_hash_digest_class` configured as SHA-256 (the new default
   in 7.0), then you need to configure SHA-256 for Active Record Encryption:

    ```ruby
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
    ```

See the [Configuring Rails Applications](configuring.html#config-active-record-encryption-hash-digest-class)
guide for more information on `config.active_record.encryption.hash_digest_class`.

In addition, a new configuration [`config.active_record.encryption.support_sha1_for_non_deterministic_encryption`](configuring.html#config-active-record-encryption-support-sha1-for-non-deterministic-encryption)
was introduced to resolve [a bug](https://github.com/rails/rails/issues/42922) that caused some attributes to be
encrypted using SHA-1 even when SHA-256 was configured via the aforementioned `hash_digest_class` configuration.

By default, `config.active_record.encryption.support_sha1_for_non_deterministic_encryption` is disabled in
Rails 7.1. If you have data encrypted in a version of Rails < 7.1 that you believe may be affected
by the aforementioned bug, this configuration should be enabled:

```ruby
config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
```

**If you are working with encrypted data, please carefully review the above.**

### New ways to handle exceptions in Controller Tests, Integration Tests, and System Tests

The `config.action_dispatch.show_exceptions` configuration controls how Action Pack handles exceptions raised while responding to requests.

Prior to Rails 7.1, setting `config.action_dispatch.show_exceptions = true` configured Action Pack to rescue exceptions and render appropriate HTML error pages, like rendering `public/404.html` with a `404 Not found` status code instead of raising an `ActiveRecord::RecordNotFound` exception. Setting `config.action_dispatch.show_exceptions = false` configured Action Pack to not rescue the exception. Prior to Rails 7.1, new applications were generated with a line in `config/environments/test.rb` that set `config.action_dispatch.show_exceptions = false`.

Rails 7.1 changes the acceptable values from `true` and `false` to `:all`, `:rescuable`, and `:none`.

* `:all` - render HTML error pages for all exceptions (equivalent to `true`)
* `:rescuable` - render HTML error pages for exceptions declared by [`config.action_dispatch.rescue_responses`](/configuring.html#config-action-dispatch-rescue-responses)
* `:none` (equivalent to `false`) - do not rescue from any exceptions

Applications generated by Rails 7.1 or later set `config.action_dispatch.show_exceptions = :rescuable` in their `config/environments/test.rb`. When upgrading, existing applications can change `config.action_dispatch.show_exceptions = :rescuable` to utilize the new behavior, or replace the old values with the corresponding new ones (`:all` replaces `true`, `:none` replaces `false`).

Upgrading from Rails 6.1 to Rails 7.0
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 7.0 please see the [release notes](7_0_release_notes.html).

### `ActionView::Helpers::UrlHelper#button_to` changed behavior

Starting from Rails 7.0 `button_to` renders a `form` tag with `patch` HTTP verb if a persisted Active Record object is used to build button URL.
To keep current behavior consider explicitly passing `method:` option:

```diff
-button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)])
+button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)], method: :post)
```

or using helper to build the URL:

```diff
-button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)])
+button_to("Do a POST", my_custom_post_action_on_workshop_workshop_path(Workshop.find(1)))
```

### Spring

If your application uses Spring, it needs to be upgraded to at least version 3.0.0. Otherwise you'll get

```
undefined method `mechanism=' for ActiveSupport::Dependencies:Module
```

Also, make sure [`config.cache_classes`][] is set to `false` in `config/environments/test.rb`.

[`config.cache_classes`]: configuring.html#config-cache-classes

### Sprockets is now an optional dependency

The gem `rails` doesn't depend on `sprockets-rails` anymore. If your application still needs to use Sprockets,
make sure to add `sprockets-rails` to your Gemfile.

```ruby
gem "sprockets-rails"
```

### Applications need to run in `zeitwerk` mode

Applications still running in `classic` mode have to switch to `zeitwerk` mode. Please check the [Classic to Zeitwerk HOWTO](https://guides.rubyonrails.org/v7.0/classic_to_zeitwerk_howto.html) guide for details.

### The setter `config.autoloader=` has been deleted

In Rails 7 there is no configuration point to set the autoloading mode, `config.autoloader=` has been deleted. If you had it set to `:zeitwerk` for whatever reason, just remove it.

### `ActiveSupport::Dependencies` private API has been deleted

The private API of `ActiveSupport::Dependencies` has been deleted. That includes methods like `hook!`, `unhook!`, `depend_on`, `require_or_load`, `mechanism`, and many others.

A few of highlights:

* If you used `ActiveSupport::Dependencies.constantize` or `ActiveSupport::Dependencies.safe_constantize`, just change them to `String#constantize` or `String#safe_constantize`.

  ```ruby
  ActiveSupport::Dependencies.constantize("User") # NO LONGER POSSIBLE
  "User".constantize # 👍
  ```

* Any usage of `ActiveSupport::Dependencies.mechanism`, reader or writer, has to be replaced by accessing `config.cache_classes` accordingly.

* If you want to trace the activity of the autoloader, `ActiveSupport::Dependencies.verbose=` is no longer available, just throw `Rails.autoloaders.log!` in `config/application.rb`.

Auxiliary internal classes or modules are also gone, like `ActiveSupport::Dependencies::Reference`, `ActiveSupport::Dependencies::Blamable`, and others.

### Autoloading during initialization

Applications that autoloaded reloadable constants during initialization outside of `to_prepare` blocks got those constants unloaded and had this warning issued since Rails 6.0:

```
DEPRECATION WARNING: Initialization autoloaded the constant ....

Being able to do this is deprecated. Autoloading during initialization is going
to be an error condition in future versions of Rails.

...
```

If you still get this warning in the logs, please check the section about autoloading when the application boots in the [autoloading guide](https://guides.rubyonrails.org/v7.0/autoloading_and_reloading_constants.html#autoloading-when-the-application-boots). You'd get a `NameError` in Rails 7 otherwise.

Constants managed by the `once` autoloader can be autoloaded during initialization, and they can be used normally, no need for a `to_prepare` block. However, the `once` autoloader is now set up earlier to support that. If the application has custom inflections, and the `once` autoloader should be aware of them, you need to move the code in `config/initializers/inflections.rb` to the body of the application class definition in `config/application.rb`:

```ruby
module MyApp
  class Application < Rails::Application
    # ...

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "HTML"
    end
  end
end
```

### Ability to configure `config.autoload_once_paths`

[`config.autoload_once_paths`][] can be set in the body of the application class defined in `config/application.rb` or in the configuration for environments in `config/environments/*`.

Similarly, engines can configure that collection in the class body of the engine class or in the configuration for environments.

After that, the collection is frozen, and you can autoload from those paths. In particular, you can autoload from there during initialization. They are managed by the `Rails.autoloaders.once` autoloader, which does not reload, only autoloads/eager loads.

If you configured this setting after the environments configuration has been processed and are getting `FrozenError`, please just move the code.

[`config.autoload_once_paths`]: configuring.html#config-autoload-once-paths

### `ActionDispatch::Request#content_type` now returns Content-Type header as it is.

Previously, `ActionDispatch::Request#content_type` returned value does NOT contain charset part.
This behavior changed to returned Content-Type header containing charset part as it is.

If you want just MIME type, please use `ActionDispatch::Request#media_type` instead.

Before:

```ruby
request = ActionDispatch::Request.new("CONTENT_TYPE" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
request.content_type #=> "text/csv"
```

After:

```ruby
request = ActionDispatch::Request.new("Content-Type" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
request.content_type #=> "text/csv; header=present; charset=utf-16"
request.media_type   #=> "text/csv"
```

### Key generator digest class change requires a cookie rotator

The default digest class for the key generator is changing from SHA1 to SHA256.
This has consequences in any encrypted message generated by Rails, including
encrypted cookies.

In order to be able to read messages using the old digest class it is necessary
to register a rotator. Failing to do so may result in users having their sessions
invalidated during the upgrade.

The following is an example for rotator for the encrypted and the signed cookies.

```ruby
# config/initializers/cookie_rotator.rb
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    authenticated_encrypted_cookie_salt = Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt
    signed_cookie_salt = Rails.application.config.action_dispatch.signed_cookie_salt

    secret_key_base = Rails.application.secret_key_base

    key_generator = ActiveSupport::KeyGenerator.new(
      secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1
    )
    key_len = ActiveSupport::MessageEncryptor.key_len

    old_encrypted_secret = key_generator.generate_key(authenticated_encrypted_cookie_salt, key_len)
    old_signed_secret = key_generator.generate_key(signed_cookie_salt)

    cookies.rotate :encrypted, old_encrypted_secret
    cookies.rotate :signed, old_signed_secret
  end
end
```

### Digest class for ActiveSupport::Digest changing to SHA256

The default digest class for ActiveSupport::Digest is changing from SHA1 to SHA256.
This has consequences for things like Etags that will change and cache keys as well.
Changing these keys can have impact on cache hit rates, so be careful and watch out
for this when upgrading to the new hash.

### New ActiveSupport::Cache serialization format

A faster and more compact serialization format was introduced.

To enable it you must set `config.active_support.cache_format_version = 7.0`:

```ruby
# config/application.rb

config.load_defaults 6.1
config.active_support.cache_format_version = 7.0
```

Or simply:

```ruby
# config/application.rb

config.load_defaults 7.0
```

However Rails 6.1 applications are not able to read this new serialization format,
so to ensure a seamless upgrade you must first deploy your Rails 7.0 upgrade with
`config.active_support.cache_format_version = 6.1`, and then only once all Rails
processes have been updated you can set `config.active_support.cache_format_version = 7.0`.

Rails 7.0 is able to read both formats so the cache won't be invalidated during the
upgrade.

### Active Storage video preview image generation

Video preview image generation now uses FFmpeg's scene change detection to generate
more meaningful preview images. Previously the first frame of the video would be used
and that caused problems if the video faded in from black. This change requires
FFmpeg v3.4+.

### Active Storage default variant processor changed to `:vips`

For new apps, image transformation will use libvips instead of ImageMagick. This will reduce
the time taken to generate variants as well as CPU and memory usage, improving response
times in apps that rely on Active Storage to serve their images.

The `:mini_magick` option is not being deprecated, so it is fine to keep using it.

To migrate an existing app to libvips, set:

```ruby
Rails.application.config.active_storage.variant_processor = :vips
```

You will then need to change existing image transformation code to the
`image_processing` macros, and replace ImageMagick's options with libvips' options.

#### Replace resize with resize_to_limit

```diff
- variant(resize: "100x")
+ variant(resize_to_limit: [100, nil])
```

If you don't do this, when you switch to vips you will see this error: `no implicit conversion to float from string`.

#### Use an array when cropping

```diff
- variant(crop: "1920x1080+0+0")
+ variant(crop: [0, 0, 1920, 1080])
```

If you don't do this when migrating to vips, you will see the following error: `unable to call crop: you supplied 2 arguments, but operation needs 5`.

#### Clamp your crop values:

Vips is more strict than ImageMagick when it comes to cropping:

1. It will not crop if `x` and/or `y` are negative values. e.g.: `[-10, -10, 100, 100]`
2. It will not crop if position (`x` or `y`) plus crop dimension (`width`, `height`) is larger than the image. e.g.: a 125x125 image and a crop of `[50, 50, 100, 100]`

If you don't do this when migrating to vips, you will see the following error: `extract_area: bad extract area`

#### Adjust the background color used for `resize_and_pad`

Vips uses black as the default background color `resize_and_pad`, instead of white like ImageMagick. Fix that by using the `background` option:

```diff
- variant(resize_and_pad: [300, 300])
+ variant(resize_and_pad: [300, 300, background: [255]])
```

#### Remove any EXIF based rotation

Vips will auto rotate images using the EXIF value when processing variants. If you were storing rotation values from user uploaded photos to apply rotation with ImageMagick, you must stop doing that:

```diff
- variant(format: :jpg, rotate: rotation_value)
+ variant(format: :jpg)
```

#### Replace monochrome with colourspace

Vips uses a different option to make monochrome images:

```diff
- variant(monochrome: true)
+ variant(colourspace: "b-w")
```

#### Switch to libvips options for compressing images

JPEG

```diff
- variant(strip: true, quality: 80, interlace: "JPEG", sampling_factor: "4:2:0", colorspace: "sRGB")
+ variant(saver: { strip: true, quality: 80, interlace: true })
```

PNG

```diff
- variant(strip: true, quality: 75)
+ variant(saver: { strip: true, compression: 9 })
```

WEBP

```diff
- variant(strip: true, quality: 75, define: { webp: { lossless: false, alpha_quality: 85, thread_level: 1 } })
+ variant(saver: { strip: true, quality: 75, lossless: false, alpha_q: 85, reduction_effort: 6, smart_subsample: true })
```

GIF

```diff
- variant(layers: "Optimize")
+ variant(saver: { optimize_gif_frames: true, optimize_gif_transparency: true })
```

#### Deploy to production

Active Storage encodes into the url for the image the list of transformations that must be performed.
If your app is caching these urls, your images will break after you deploy the new code to production.
Because of this you must manually invalidate your affected cache keys.

For example, if you have something like this in a view:

```erb
<% @products.each do |product| %>
  <% cache product do %>
    <%= image_tag product.cover_photo.variant(resize: "200x") %>
  <% end %>
<% end %>
```

You can invalidate the cache either by touching the product, or changing the cache key:

```erb
<% @products.each do |product| %>
  <% cache ["v2", product] do %>
    <%= image_tag product.cover_photo.variant(resize_to_limit: [200, nil]) %>
  <% end %>
<% end %>
```

### Rails version is now included in the Active Record schema dump

Rails 7.0 changed some default values for some column types. To avoid that application upgrading from 6.1 to 7.0
load the current schema using the new 7.0 defaults, Rails now includes the version of the framework in the schema dump.

Before loading the schema for the first time in Rails 7.0, make sure to run `bin/rails app:update` to ensure that the
version of the schema is included in the schema dump.

The schema file will look like this:

```ruby
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[6.1].define(version: 2022_01_28_123512) do
  # ...
end
```

NOTE: The first time you dump the schema with Rails 7.0, you will see many changes to that file, including
some column information. Make sure to review the new schema file content and commit it to your repository.

Upgrading from Rails 6.0 to Rails 6.1
-------------------------------------

TIP: Consider using the [update task](#the-update-task) to help you manage the changes in an interactive session.

For more information on changes made to Rails 6.1 please see the [release notes](6_1_release_notes.html).

### `Rails.application.config_for` return value no longer supports access with String keys.

Given a configuration file like this:

```yaml
# config/example.yml
development:
  options:
    key: value
```

```ruby
Rails.application.config_for(:example).options
```

This used to return a hash on which you could access values with String keys. That was deprecated in 6.0, and now doesn't work anymore.

You can call `with_indifferent_access` on the return value of `config_for` if you still want to access values with String keys, e.g.:

```ruby
Rails.application.config_for(:example).with_indifferent_access.dig("options", "key")
```

### Response's Content-Type when using `respond_to#any`

The Content-Type header returned in the response can differ from what Rails 6.0 returned,
more specifically if your application uses `respond_to { |format| format.any }`.
The Content-Type will now be based on the given block rather than the request's format.

Example:

```ruby
def my_action
  respond_to do |format|
    format.any { render(json: { foo: "bar" }) }
  end
end
```

```ruby
get("my_action.csv")
```

Previous behavior was returning a `text/csv` response's Content-Type which is inaccurate since a JSON response is being rendered.
Current behavior correctly returns a `application/json` response's Content-Type.

If your application relies on the previous incorrect behavior, you are encouraged to specify
which formats your action accepts, i.e.

```ruby
format.any(:xml, :json) { render request.format.to_sym => @people }
```

### `ActiveSupport::Callbacks#halted_callback_hook` now receive a second argument

Active Support allows you to override the `halted_callback_hook` whenever a callback
halts the chain. This method now receives a second argument which is the name of the callback being halted.
If you have classes that override this method, make sure it accepts two arguments. Note that this is a breaking
change without a prior deprecation cycle (for performance reasons).

Example:

```ruby
class Book < ApplicationRecord
  before_save { throw(:abort) }
  before_create { throw(:abort) }

  def halted_callback_hook(filter, callback_name) # => This method now accepts 2 arguments instead of 1
    Rails.logger.info("Book couldn't be #{callback_name}d")
  end
end
```

### The `helper` class method in controllers uses `String#constantize`

Conceptually, before Rails 6.1

```ruby
helper "foo/bar"
```

resulted in

```ruby
require_dependency "foo/bar_helper"
module_name = "foo/bar_helper".camelize
module_name.constantize
```

Now it does this instead:

```ruby
prefix = "foo/bar".camelize
"#{prefix}Helper".constantize
```

This change is backwards compatible for the majority of applications, in which case you do not need to do anything.

Technically, however, controllers could configure `helpers_path` to point to a directory in `$LOAD_PATH` that was not in the autoload paths. That use case is no longer supported out of the box. If the helper module is not autoloadable, the application is responsible for loading it before calling `helper`.

### Redirection to HTTPS from HTTP will now use the 308 HTTP status code

The default HTTP status code used in `ActionDispatch::SSL` when redirecting non-GET/HEAD requests from HTTP to HTTPS has been changed to `308` as defined in https://tools.ietf.org/html/rfc7538.

### Active Storage now requires Image Processing

When processing variants in Active Storage, it's now required to have the [image_processing gem](https://github.com/janko/image_processing) bundled instead of directly using `mini_magick`. Image Processing is configured by default to use `mini_magick` behind the scenes, so the easiest way to upgrade is by replacing the `mini_magick` gem for the `image_processing` gem and making sure to remove the explicit usage of `combine_options` since it's no longer needed.

For readability, you may wish to change raw `resize` calls to `image_processing` macros. For example, instead of:

```ruby
video.preview(resize: "100x100")
video.preview(resize: "100x100>")
video.preview(resize: "100x100^")
```

you can respectively do:

```ruby
video.preview(resize_to_fit: [100, 100])
video.preview(resize_to_limit: [100, 100])
video.preview(resize_to_fill: [100, 100])
```

### New `ActiveModel::Error` class

Errors are now instances of a new `ActiveModel::Error` class, with changes to
the API. Some of these changes may throw errors depending on how you manipulate
errors, while others will print deprecation warnings to be fixed for Rails 7.0.

More information about this change and details about the API changes can be
found [in this PR](https://github.com/rails/rails/pull/32313).

Upgrading Versions before 6.0
-----------------------------

### Upgrading Rails 5.2 to 6.0

Please see this guide for help [upgrading Rails 5.2 to 6.0](upgrading_from_rails_5.2_to_6.0.html).

### Upgrading Rails 5.1 to 5.2

Please see this guide for help [upgrading Rails 5.1 to 5.2](upgrading_from_rails_5.1_to_5.2.html).

### Upgrading Rails 5.0 to 5.1

Please see this guide for help [upgrading Rails 5.0 to 5.1](upgrading_from_rails_5.0_to_5.1.html).

### Upgrading Rails 4.2 to 5.0

Please see this guide for help [upgrading Rails 4.2 to 5.0](upgrading_from_rails_4.2_to_5.0.html).

### Upgrading Rails 4.1 to 4.2

Please see this guide for help [upgrading Rails 4.1 to 4.2](upgrading_from_rails_4.1_to_4.2.html).

### Upgrading Rails 4.0 to 4.1

Please see this guide for help [upgrading Rails 4.0 to 4.1](upgrading_from_rails_4.0_to_4.1.html).

### Upgrading Rails 3.2 to 4.0

Please see this guide for help [upgrading Rails 3.2 to 4.0](upgrading_from_rails_3.2_to_4.0.html).

### Upgrading Rails 3.1 to 3.2

Please see this guide for help [upgrading Rails 3.1 to 3.2](upgrading_from_rails_3.1_to_3.2.html).

### Upgrading Rails 3.0 to 3.1

Please see this guide for help [upgrading Rails 3.0 to 3.1](upgrading_from_rails_3.1_to_3.2.html).