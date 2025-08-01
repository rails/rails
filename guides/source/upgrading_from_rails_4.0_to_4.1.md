**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 4.0 to Rails 4.1
=====================================

This guide provides steps to be followed when you upgrade your applications from Rails 4.0 to Rails 4.1. These steps are also available in individual release guides.

--------------------------------------------------------------------------------

Key Changes
-----------

### CSRF protection from remote `<script>` tags

Or, "whaaat my tests are failing!!!?" or "my `<script>` widget is busted!!"

Cross-site request forgery (CSRF) protection now covers GET requests with
JavaScript responses, too. This prevents a third-party site from remotely
referencing your JavaScript with a `<script>` tag to extract sensitive data.

This means that your functional and integration tests that use

```ruby
get :index, format: :js
```

will now trigger CSRF protection. Switch to

```ruby
xhr :get, :index, format: :js
```

to explicitly test an `XmlHttpRequest`.

NOTE: Your own `<script>` tags are treated as cross-origin and blocked by
default, too. If you really mean to load JavaScript from `<script>` tags,
you must now explicitly skip CSRF protection on those actions.

### Spring

If you want to use Spring as your application preloader you need to:

1. Add `gem "spring", group: :development` to your `Gemfile`.
2. Install spring using `bundle install`.
3. Generate the Spring binstub with `bundle exec spring binstub`.

NOTE: User defined rake tasks will run in the `development` environment by
default. If you want them to run in other environments consult the
[Spring README](https://github.com/rails/spring#rake).

### `config/secrets.yml`

If you want to use the new `secrets.yml` convention to store your application's
secrets, you need to:

1. Create a `secrets.yml` file in your `config` folder with the following content:

    ```yaml
    development:
      secret_key_base:

    test:
      secret_key_base:

    production:
      secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
    ```

2. Use your existing `secret_key_base` from the `secret_token.rb` initializer to
   set the `SECRET_KEY_BASE` environment variable for whichever users running the
   Rails application in production. Alternatively, you can simply copy the existing
   `secret_key_base` from the `secret_token.rb` initializer to `secrets.yml`
   under the `production` section, replacing `<%= ENV["SECRET_KEY_BASE"] %>`.

3. Remove the `secret_token.rb` initializer.

4. Use `rake secret` to generate new keys for the `development` and `test` sections.

5. Restart your server.

### Changes to test helper

If your test helper contains a call to
`ActiveRecord::Migration.check_pending!` this can be removed. The check
is now done automatically when you `require "rails/test_help"`, although
leaving this line in your helper is not harmful in any way.

### Cookies serializer

Applications created before Rails 4.1 uses `Marshal` to serialize cookie values into
the signed and encrypted cookie jars. If you want to use the new `JSON`-based format
in your application, you can add an initializer file with the following content:

```ruby
Rails.application.config.action_dispatch.cookies_serializer = :hybrid
```

This would transparently migrate your existing `Marshal`-serialized cookies into the
new `JSON`-based format.

When using the `:json` or `:hybrid` serializer, you should beware that not all
Ruby objects can be serialized as JSON. For example, `Date` and `Time` objects
will be serialized as strings, and `Hash`es will have their keys stringified.

```ruby
class CookiesController < ApplicationController
  def set_cookie
    cookies.encrypted[:expiration_date] = Date.tomorrow # => Thu, 20 Mar 2014
    redirect_to action: "read_cookie"
  end

  def read_cookie
    cookies.encrypted[:expiration_date] # => "2014-03-20"
  end
end
```

It's advisable that you only store simple data (strings and numbers) in cookies.
If you have to store complex objects, you would need to handle the conversion
manually when reading the values on subsequent requests.

If you use the cookie session store, this would apply to the `session` and
`flash` hash as well.

### Flash structure changes

Flash message keys are
[normalized to strings](https://github.com/rails/rails/commit/a668beffd64106a1e1fedb71cc25eaaa11baf0c1). They
can still be accessed using either symbols or strings. Looping through the flash
will always yield string keys:

```ruby
flash["string"] = "a string"
flash[:symbol] = "a symbol"

# Rails < 4.1
flash.keys # => ["string", :symbol]

# Rails >= 4.1
flash.keys # => ["string", "symbol"]
```

Make sure you are comparing Flash message keys against strings.

### Changes in JSON handling

There are a few major changes related to JSON handling in Rails 4.1.

#### MultiJSON removal

MultiJSON has reached its [end-of-life](https://github.com/rails/rails/pull/10576)
and has been removed from Rails.

If your application currently depends on MultiJSON directly, you have a few options:

1. Add 'multi_json' to your `Gemfile`. Note that this might cease to work in the future

2. Migrate away from MultiJSON by using `obj.to_json`, and `JSON.parse(str)` instead.

WARNING: Do not simply replace `MultiJson.load` with
`JSON.load` as that API is meant for deserializing arbitrary Ruby objects and
is generally [unsafe](https://docs.ruby-lang.org/en/master/JSON.html#method-i-load).
Prefer to use `JSON.parse`.

#### JSON gem compatibility

Historically, Rails had some compatibility issues with the JSON gem. Using
`JSON.generate` and `JSON.dump` inside a Rails application could produce
unexpected errors.

Rails 4.1 fixed these issues by isolating its own encoder from the JSON gem. The
JSON gem APIs will function as normal, but they will not have access to any
Rails-specific features. For example:

```ruby
class FooBar
  def as_json(options = nil)
    { foo: "bar" }
  end
end
```

```irb
irb> FooBar.new.to_json
=> "{\"foo\":\"bar\"}"
irb> JSON.generate(FooBar.new)
=> "\"#<FooBar:0x007fa80a481610>\""
```

#### New JSON encoder

The JSON encoder in Rails 4.1 has been rewritten to take advantage of the JSON
gem. For most applications, this should be a transparent change. However, as
part of the rewrite, the following features have been removed from the encoder:

1. Circular data structure detection
2. Support for the `encode_json` hook
3. Option to encode `BigDecimal` objects as numbers instead of strings

If your application depends on one of these features, you can get them back by
adding the [`activesupport-json_encoder`](https://github.com/rails/activesupport-json_encoder)
gem to your `Gemfile`.

#### JSON representation of Time objects

`#as_json` for objects with time component (`Time`, `DateTime`, `ActiveSupport::TimeWithZone`)
now returns millisecond precision by default. If you need to keep old behavior with no millisecond
precision, set the following in an initializer:

```ruby
ActiveSupport::JSON::Encoding.time_precision = 0
```

### Usage of `return` within inline callback blocks

Previously, Rails allowed inline callback blocks to use `return` this way:

```ruby
class ReadOnlyModel < ActiveRecord::Base
  before_save { return false } # BAD
end
```

This behavior was never intentionally supported. Due to a change in the internals
of `ActiveSupport::Callbacks`, this is no longer allowed in Rails 4.1. Using a
`return` statement in an inline callback block causes a `LocalJumpError` to
be raised when the callback is executed.

Inline callback blocks using `return` can be refactored to evaluate to the
returned value:

```ruby
class ReadOnlyModel < ActiveRecord::Base
  before_save { false } # GOOD
end
```

Alternatively, if `return` is preferred it is recommended to explicitly define
a method:

```ruby
class ReadOnlyModel < ActiveRecord::Base
  before_save :before_save_callback # GOOD

  private
    def before_save_callback
      false
    end
end
```

This change applies to most places in Rails where callbacks are used, including
Active Record and Active Model callbacks, as well as filters in Action
Controller (e.g. `before_action`).

See [this pull request](https://github.com/rails/rails/pull/13271) for more
details.

### Methods defined in Active Record fixtures

Rails 4.1 evaluates each fixture's ERB in a separate context, so helper methods
defined in a fixture will not be available in other fixtures.

Helper methods that are used in multiple fixtures should be defined on modules
included in the newly introduced `ActiveRecord::FixtureSet.context_class`, in
`test_helper.rb`.

```ruby
module FixtureFileHelpers
  def file_sha(path)
    OpenSSL::Digest::SHA256.hexdigest(File.read(Rails.root.join("test/fixtures", path)))
  end
end

ActiveRecord::FixtureSet.context_class.include FixtureFileHelpers
```

### I18n enforcing available locales

Rails 4.1 now defaults the I18n option `enforce_available_locales` to `true`. This
means that it will make sure that all locales passed to it must be declared in
the `available_locales` list.

To disable it (and allow I18n to accept *any* locale option) add the following
configuration to your application:

```ruby
config.i18n.enforce_available_locales = false
```

Note that this option was added as a security measure, to ensure user input
cannot be used as locale information unless it is previously known. Therefore,
it's recommended not to disable this option unless you have a strong reason for
doing so.

### Mutator methods called on Relation

`Relation` no longer has mutator methods like `#map!` and `#delete_if`. Convert
to an `Array` by calling `#to_a` before using these methods.

It intends to prevent odd bugs and confusion in code that call mutator
methods directly on the `Relation`.

```ruby
# Instead of this
Author.where(name: "Hank Moody").compact!

# Now you have to do this
authors = Author.where(name: "Hank Moody").to_a
authors.compact!
```

### Changes on Default Scopes

Default scopes are no longer overridden by chained conditions.

In previous versions when you defined a `default_scope` in a model
it was overridden by chained conditions in the same field. Now it
is merged like any other scope.

Before:

```ruby
class User < ActiveRecord::Base
  default_scope { where state: "pending" }
  scope :active, -> { where state: "active" }
  scope :inactive, -> { where state: "inactive" }
end

User.all
# SELECT "users".* FROM "users" WHERE "users"."state" = 'pending'

User.active
# SELECT "users".* FROM "users" WHERE "users"."state" = 'active'

User.where(state: "inactive")
# SELECT "users".* FROM "users" WHERE "users"."state" = 'inactive'
```

After:

```ruby
class User < ActiveRecord::Base
  default_scope { where state: "pending" }
  scope :active, -> { where state: "active" }
  scope :inactive, -> { where state: "inactive" }
end

User.all
# SELECT "users".* FROM "users" WHERE "users"."state" = 'pending'

User.active
# SELECT "users".* FROM "users" WHERE "users"."state" = 'pending' AND "users"."state" = 'active'

User.where(state: "inactive")
# SELECT "users".* FROM "users" WHERE "users"."state" = 'pending' AND "users"."state" = 'inactive'
```

To get the previous behavior it is needed to explicitly remove the
`default_scope` condition using `unscoped`, `unscope`, `rewhere` or
`except`.

```ruby
class User < ActiveRecord::Base
  default_scope { where state: "pending" }
  scope :active, -> { unscope(where: :state).where(state: "active") }
  scope :inactive, -> { rewhere state: "inactive" }
end

User.all
# SELECT "users".* FROM "users" WHERE "users"."state" = 'pending'

User.active
# SELECT "users".* FROM "users" WHERE "users"."state" = 'active'

User.inactive
# SELECT "users".* FROM "users" WHERE "users"."state" = 'inactive'
```

### Rendering content from string

Rails 4.1 introduces `:plain`, `:html`, and `:body` options to `render`. Those
options are now the preferred way to render string-based content, as it allows
you to specify which content type you want the response sent as.

* `render :plain` will set the content type to `text/plain`
* `render :html` will set the content type to `text/html`
* `render :body` will *not* set the content type header.

From the security standpoint, if you don't expect to have any markup in your
response body, you should be using `render :plain` as most browsers will escape
unsafe content in the response for you.

We will be deprecating the use of `render :text` in a future version. So please
start using the more precise `:plain`, `:html`, and `:body` options instead.
Using `render :text` may pose a security risk, as the content is sent as
`text/html`.

### PostgreSQL JSON and hstore datatypes

Rails 4.1 will map `json` and `hstore` columns to a string-keyed Ruby `Hash`.
In earlier versions, a `HashWithIndifferentAccess` was used. This means that
symbol access is no longer supported. This is also the case for
`store_accessors` based on top of `json` or `hstore` columns. Make sure to use
string keys consistently.

### Explicit block use for `ActiveSupport::Callbacks`

Rails 4.1 now expects an explicit block to be passed when calling
`ActiveSupport::Callbacks.set_callback`. This change stems from
`ActiveSupport::Callbacks` being largely rewritten for the 4.1 release.

```ruby
# Previously in Rails 4.0
set_callback :save, :around, ->(r, &block) { stuff; result = block.call; stuff }

# Now in Rails 4.1
set_callback :save, :around, ->(r, block) { stuff; result = block.call; stuff }
```
