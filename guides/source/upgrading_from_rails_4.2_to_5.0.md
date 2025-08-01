**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 4.2 to Rails 5.0
=====================================

This guide provides steps to be followed when you upgrade your applications from Rails 4.2 to Rails 5.0. These steps are also available in individual release guides.

--------------------------------------------------------------------------------

Key Changes
-----------

For more information on changes made to Rails 5.0 please see the [release notes](5_0_release_notes.html).

### Ruby 2.2.2+ required

From Ruby on Rails 5.0 onwards, Ruby 2.2.2+ is the only supported Ruby version.
Make sure you are on Ruby 2.2.2 version or greater, before you proceed.

### Active Record Models Now Inherit from ApplicationRecord by Default

In Rails 4.2, an Active Record model inherits from `ActiveRecord::Base`. In Rails 5.0,
all models inherit from `ApplicationRecord`.

`ApplicationRecord` is a new superclass for all app models, analogous to app
controllers subclassing `ApplicationController` instead of
`ActionController::Base`. This gives apps a single spot to configure app-wide
model behavior.

When upgrading from Rails 4.2 to Rails 5.0, you need to create an
`application_record.rb` file in `app/models/` and add the following content:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
```

Then make sure that all your models inherit from it.

### Halting Callback Chains via `throw(:abort)`

In Rails 4.2, when a 'before' callback returns `false` in Active Record
and Active Model, then the entire callback chain is halted. In other words,
successive 'before' callbacks are not executed, and neither is the action wrapped
in callbacks.

In Rails 5.0, returning `false` in an Active Record or Active Model callback
will not have this side effect of halting the callback chain. Instead, callback
chains must be explicitly halted by calling `throw(:abort)`.

When you upgrade from Rails 4.2 to Rails 5.0, returning `false` in those kind of
callbacks will still halt the callback chain, but you will receive a deprecation
warning about this upcoming change.

When you are ready, you can opt into the new behavior and remove the deprecation
warning by adding the following configuration to your `config/application.rb`:

```ruby
ActiveSupport.halt_callback_chains_on_return_false = false
```

Note that this option will not affect Active Support callbacks since they never
halted the chain when any value was returned.

See [#17227](https://github.com/rails/rails/pull/17227) for more details.

### ActiveJob Now Inherits from ApplicationJob by Default

In Rails 4.2, an Active Job inherits from `ActiveJob::Base`. In Rails 5.0, this
behavior has changed to now inherit from `ApplicationJob`.

When upgrading from Rails 4.2 to Rails 5.0, you need to create an
`application_job.rb` file in `app/jobs/` and add the following content:

```ruby
class ApplicationJob < ActiveJob::Base
end
```

Then make sure that all your job classes inherit from it.

See [#19034](https://github.com/rails/rails/pull/19034) for more details.

### Rails Controller Testing

#### Extraction of some helper methods to `rails-controller-testing`

`assigns` and `assert_template` have been extracted to the `rails-controller-testing` gem. To
continue using these methods in your controller tests, add `gem "rails-controller-testing"` to
your `Gemfile`.

If you are using RSpec for testing, please see the extra configuration required in the gem's
documentation.

#### New behavior when uploading files

If you are using `ActionDispatch::Http::UploadedFile` in your tests to
upload files, you will need to change to use the similar `Rack::Test::UploadedFile`
class instead.

See [#26404](https://github.com/rails/rails/issues/26404) for more details.

### Autoloading is Disabled After Booting in the Production Environment

Autoloading is now disabled after booting in the production environment by
default.

Eager loading the application is part of the boot process, so top-level
constants are fine and are still autoloaded, no need to require their files.

Constants in deeper places only executed at runtime, like regular method bodies,
are also fine because the file defining them will have been eager loaded while booting.

For the vast majority of applications this change needs no action. But in the
very rare event that your application needs autoloading while running in
production, set `Rails.application.config.enable_dependency_loading` to true.

### XML Serialization

`ActiveModel::Serializers::Xml` has been extracted from Rails to the `activemodel-serializers-xml`
gem. To continue using XML serialization in your application, add `gem "activemodel-serializers-xml"`
to your `Gemfile`.

### Removed Support for Legacy `mysql` Database Adapter

Rails 5 removes support for the legacy `mysql` database adapter. Most users should be able to
use `mysql2` instead. It will be converted to a separate gem when we find someone to maintain
it.

### Removed Support for Debugger

`debugger` is not supported by Ruby 2.2 which is required by Rails 5. Use `byebug` instead.

### Use `bin/rails` for running tasks and tests

Rails 5 adds the ability to run tasks and tests through `bin/rails` instead of rake. Generally
these changes are in parallel with rake, but some were ported over altogether.

To use the new test runner simply type `bin/rails test`.

`rake dev:cache` is now `bin/rails dev:cache`.

Run `bin/rails` inside your application's root directory to see the list of commands available.

### `ActionController::Parameters` No Longer Inherits from `HashWithIndifferentAccess`

Calling `params` in your application will now return an object instead of a hash. If your
parameters are already permitted, then you will not need to make any changes. If you are using `map`
and other methods that depend on being able to read the hash regardless of `permitted?` you will
need to upgrade your application to first permit and then convert to a hash.

```ruby
params.permit([:proceed_to, :return_to]).to_h
```

### `protect_from_forgery` Now Defaults to `prepend: false`

`protect_from_forgery` defaults to `prepend: false` which means that it will be inserted into
the callback chain at the point in which you call it in your application. If you want
`protect_from_forgery` to always run first, then you should change your application to use
`protect_from_forgery prepend: true`.

### Default Template Handler is Now RAW

Files without a template handler in their extension will be rendered using the raw handler.
Previously Rails would render files using the ERB template handler.

If you do not want your file to be handled via the raw handler, you should add an extension
to your file that can be parsed by the appropriate template handler.

### Added Wildcard Matching for Template Dependencies

You can now use wildcard matching for your template dependencies. For example, if you were
defining your templates as such:

```erb
<% # Template Dependency: recordings/threads/events/subscribers_changed %>
<% # Template Dependency: recordings/threads/events/completed %>
<% # Template Dependency: recordings/threads/events/uncompleted %>
```

You can now just call the dependency once with a wildcard.

```erb
<% # Template Dependency: recordings/threads/events/* %>
```

### `ActionView::Helpers::RecordTagHelper` moved to external gem (record_tag_helper)

`content_tag_for` and `div_for` have been removed in favor of just using `content_tag`. To continue using the older methods, add the `record_tag_helper` gem to your `Gemfile`:

```ruby
gem "record_tag_helper", "~> 1.0"
```

See [#18411](https://github.com/rails/rails/pull/18411) for more details.

### Removed Support for `protected_attributes` Gem

The `protected_attributes` gem is no longer supported in Rails 5.

### Removed support for `activerecord-deprecated_finders` gem

The `activerecord-deprecated_finders` gem is no longer supported in Rails 5.

### `ActiveSupport::TestCase` Default Test Order is Now Random

When tests are run in your application, the default order is now `:random`
instead of `:sorted`. Use the following config option to set it back to `:sorted`.

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_support.test_order = :sorted
end
```

### `ActionController::Live` became a `Concern`

If you include `ActionController::Live` in another module that is included in your controller, then you
should also extend the module with `ActiveSupport::Concern`. Alternatively, you can use the `self.included` hook
to include `ActionController::Live` directly to the controller once the `StreamingSupport` is included.

This means that if your application used to have its own streaming module, the following code
would break in production:

```ruby
# This is a work-around for streamed controllers performing authentication with Warden/Devise.
# See https://github.com/plataformatec/devise/issues/2332
# Authenticating in the router is another solution as suggested in that issue
class StreamingSupport
  include ActionController::Live # this won't work in production for Rails 5
  # extend ActiveSupport::Concern # unless you uncomment this line.

  def process(name)
    super(name)
  rescue ArgumentError => e
    if e.message == "uncaught throw :warden"
      throw :warden
    else
      raise e
    end
  end
end
```

### New Framework Defaults

#### Active Record `belongs_to` Required by Default Option

`belongs_to` will now trigger a validation error by default if the association is not present.

This can be turned off per-association with `optional: true`.

This default will be automatically configured in new applications. If an existing application
wants to add this feature it will need to be turned on in an initializer:

```ruby
config.active_record.belongs_to_required_by_default = true
```

The configuration is by default global for all your models, but you can
override it on a per model basis. This should help you migrate all your models to have their
associations required by default.

```ruby
class Book < ApplicationRecord
  # model is not yet ready to have its association required by default

  self.belongs_to_required_by_default = false
  belongs_to(:author)
end

class Car < ApplicationRecord
  # model is ready to have its association required by default

  self.belongs_to_required_by_default = true
  belongs_to(:pilot)
end
```

#### Per-form CSRF Tokens

Rails 5 now supports per-form CSRF tokens to mitigate against code-injection attacks with forms
created by JavaScript. With this option turned on, forms in your application will each have their
own CSRF token that is specific to the action and method for that form.

```ruby
config.action_controller.per_form_csrf_tokens = true
```

#### Forgery Protection with Origin Check

You can now configure your application to check if the HTTP `Origin` header should be checked
against the site's origin as an additional CSRF defense. Set the following in your config to
true:

```ruby
config.action_controller.forgery_protection_origin_check = true
```

#### Allow Configuration of Action Mailer Queue Name

The default mailer queue name is `mailers`. This configuration option allows you to globally change
the queue name. Set the following in your config:

```ruby
config.action_mailer.deliver_later_queue_name = :new_queue_name
```

#### Support Fragment Caching in Action Mailer Views

Set [`config.action_mailer.perform_caching`][] in your config to determine whether your Action Mailer views
should support caching.

```ruby
config.action_mailer.perform_caching = true
```

[`config.action_mailer.perform_caching`]: configuring.html#config-action-mailer-perform-caching

#### Configure the Output of `db:structure:dump`

If you're using `schema_search_path` or other PostgreSQL extensions, you can control how the schema is
dumped. Set to `:all` to generate all dumps, or to `:schema_search_path` to generate from schema search path.

```ruby
config.active_record.dump_schemas = :all
```

#### Configure SSL Options to Enable HSTS with Subdomains

Set the following in your config to enable HSTS when using subdomains:

```ruby
config.ssl_options = { hsts: { subdomains: true } }
```

#### Preserve Timezone of the Receiver

When using Ruby 2.4, you can preserve the timezone of the receiver when calling `to_time`.

```ruby
ActiveSupport.to_time_preserves_timezone = false
```

### Changes with JSON/JSONB serialization

In Rails 5.0, how JSON/JSONB attributes are serialized and deserialized changed. Now, if
you set a column equal to a `String`, Active Record will no longer turn that string
into a `Hash`, and will instead only return the string. This is not limited to code
interacting with models, but also affects `:default` column settings in `db/schema.rb`.
It is recommended that you do not set columns equal to a `String`, but pass a `Hash`
instead, which will be converted to and from a JSON string automatically.
