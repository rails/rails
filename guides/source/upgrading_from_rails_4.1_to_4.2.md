**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 4.1 to Rails 4.2
=====================================

This guide provides steps to be followed when you upgrade your applications from Rails 4.1 to Rails 4.2. These steps are also available in individual release guides.

--------------------------------------------------------------------------------

Key Changes
-----------

### Web Console

First, add `gem "web-console", "~> 2.0"` to the `:development` group in your `Gemfile` and run `bundle install` (it won't have been included when you upgraded Rails). Once it's been installed, you can simply drop a reference to the console helper (i.e., `<%= console %>`) into any view you want to enable it for. A console will also be provided on any error page you view in your development environment.

### Responders

`respond_with` and the class-level `respond_to` methods have been extracted to the `responders` gem. To use them, simply add `gem "responders", "~> 2.0"` to your `Gemfile`. Calls to `respond_with` and `respond_to` (again, at the class level) will no longer work without having included the `responders` gem in your dependencies:

```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  respond_to :html, :json

  def show
    @user = User.find(params[:id])
    respond_with @user
  end
end
```

Instance-level `respond_to` is unaffected and does not require the additional gem:

```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: @user }
    end
  end
end
```

See [#16526](https://github.com/rails/rails/pull/16526) for more details.

### Error handling in transaction callbacks

Currently, Active Record suppresses errors raised
within `after_rollback` or `after_commit` callbacks and only prints them to
the logs. In the next version, these errors will no longer be suppressed.
Instead, the errors will propagate normally just like in other Active
Record callbacks.

When you define an `after_rollback` or `after_commit` callback, you
will receive a deprecation warning about this upcoming change. When
you are ready, you can opt into the new behavior and remove the
deprecation warning by adding following configuration to your
`config/application.rb`:

```ruby
config.active_record.raise_in_transactional_callbacks = true
```

See [#14488](https://github.com/rails/rails/pull/14488) and
[#16537](https://github.com/rails/rails/pull/16537) for more details.

### Ordering of test cases

In Rails 5.0, test cases will be executed in random order by default. In
anticipation of this change, Rails 4.2 introduced a new configuration option
`active_support.test_order` for explicitly specifying the test ordering. This
allows you to either lock down the current behavior by setting the option to
`:sorted`, or opt into the future behavior by setting the option to `:random`.

If you do not specify a value for this option, a deprecation warning will be
emitted. To avoid this, add the following line to your test environment:

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_support.test_order = :sorted # or `:random` if you prefer
end
```

### Serialized attributes

When using a custom coder (e.g. `serialize :metadata, JSON`),
assigning `nil` to a serialized attribute will save it to the database
as `NULL` instead of passing the `nil` value through the coder (e.g. `"null"`
when using the `JSON` coder).

### Production log level

In Rails 5, the default log level for the production environment will be changed
to `:debug` (from `:info`). To preserve the current default, add the following
line to your `production.rb`:

```ruby
# Set to `:info` to match the current default, or set to `:debug` to opt-into
# the future default.
config.log_level = :info
```

### `after_bundle` in Rails templates

If you have a Rails template that adds all the files in version control, it
fails to add the generated binstubs because it gets executed before Bundler:

```ruby
# template.rb
generate(:scaffold, "person name:string")
route "root to: 'people#index'"
rake("db:migrate")

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }
```

You can now wrap the `git` calls in an `after_bundle` block. It will be run
after the binstubs have been generated.

```ruby
# template.rb
generate(:scaffold, "person name:string")
route "root to: 'people#index'"
rake("db:migrate")

after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
```

### Rails HTML Sanitizer

There's a new choice for sanitizing HTML fragments in your applications. The
venerable html-scanner approach is now officially being deprecated in favor of
[`Rails HTML Sanitizer`](https://github.com/rails/rails-html-sanitizer).

This means the methods `sanitize`, `sanitize_css`, `strip_tags` and
`strip_links` are backed by a new implementation.

This new sanitizer uses [Loofah](https://github.com/flavorjones/loofah) internally. Loofah in turn uses Nokogiri, which
wraps XML parsers written in both C and Java, so sanitization should be faster
no matter which Ruby version you run.

The new version updates `sanitize`, so it can take a `Loofah::Scrubber` for
powerful scrubbing.
[See some examples of scrubbers here](https://github.com/flavorjones/loofah#loofahscrubber).

Two new scrubbers have also been added: `PermitScrubber` and `TargetScrubber`.
Read the [gem's readme](https://github.com/rails/rails-html-sanitizer) for more information.

The documentation for `PermitScrubber` and `TargetScrubber` explains how you
can gain complete control over when and how elements should be stripped.

If your application needs to use the old sanitizer implementation, include `rails-deprecated_sanitizer` in your `Gemfile`:

```ruby
gem "rails-deprecated_sanitizer"
```

### Rails DOM Testing

The [`TagAssertions` module](https://api.rubyonrails.org/v4.1/classes/ActionDispatch/Assertions/TagAssertions.html) (containing methods such as `assert_tag`), [has been deprecated](https://github.com/rails/rails/blob/6061472b8c310158a2a2e8e9a6b81a1aef6b60fe/actionpack/lib/action_dispatch/testing/assertions/dom.rb) in favor of the `assert_select` methods from the `SelectorAssertions` module, which has been extracted into the [rails-dom-testing gem](https://github.com/rails/rails-dom-testing).

### Masked Authenticity Tokens

In order to mitigate SSL attacks, `form_authenticity_token` is now masked so that it varies with each request.  Thus, tokens are validated by unmasking and then decrypting.  As a result, any strategies for verifying requests from non-rails forms that relied on a static session CSRF token have to take this into account.

### Action Mailer

Previously, calling a mailer method on a mailer class will result in the
corresponding instance method being executed directly. With the introduction of
Active Job and `#deliver_later`, this is no longer true. In Rails 4.2, the
invocation of the instance methods are deferred until either `deliver_now` or
`deliver_later` is called. For example:

```ruby
class Notifier < ActionMailer::Base
  def notify(user)
    puts "Called"
    mail(to: user.email)
  end
end
```

```ruby
mail = Notifier.notify(user) # Notifier#notify is not yet called at this point
mail = mail.deliver_now           # Prints "Called"
```

This should not result in any noticeable differences for most applications.
However, if you need some non-mailer methods to be executed synchronously, and
you were previously relying on the synchronous proxying behavior, you should
define them as class methods on the mailer class directly:

```ruby
class Notifier < ActionMailer::Base
  def self.broadcast_notifications(users, ...)
    users.each { |user| Notifier.notify(user, ...) }
  end
end
```

### Foreign Key Support

The migration DSL has been expanded to support foreign key definitions. If
you've been using the Foreigner gem, you might want to consider removing it.
Note that the foreign key support of Rails is a subset of Foreigner. This means
that not every Foreigner definition can be fully replaced by its Rails
migration DSL counterpart.

The migration procedure is as follows:

1. remove `gem "foreigner"` from the `Gemfile`.
2. run `bundle install`.
3. run `bin/rake db:schema:dump`.
4. make sure that `db/schema.rb` contains every foreign key definition with
  the necessary options.
