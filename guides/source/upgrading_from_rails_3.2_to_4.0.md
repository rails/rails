**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 3.2 to Rails 4.0
=====================================

This guide provides steps to be followed when you upgrade your applications from
Rails 3.2 to Rails 4.0. These steps are also available in individual release
guides.

--------------------------------------------------------------------------------

Key Changes
-----------

If your application is currently on any version of Rails older than 3.2.x, you
should upgrade to Rails 3.2 before attempting one to Rails 4.0.

The following changes are meant for upgrading your application to Rails 4.0.

### HTTP PATCH

Rails 4 now uses `PATCH` as the primary HTTP verb for updates when a RESTful
resource is declared in `config/routes.rb`. The `update` action is still used,
and `PUT` requests will continue to be routed to the `update` action as well.
So, if you're using only the standard RESTful routes, no changes need to be
made:

```ruby
resources :users
```

```erb
<%= form_for @user do |f| %>
```

```ruby
class UsersController < ApplicationController
  def update
    # No change needed; PATCH will be preferred, and PUT will still work.
  end
end
```

However, you will need to make a change if you are using `form_for` to update a
resource in conjunction with a custom route using the `PUT` HTTP method:

```ruby
resources :users do
  put :update_name, on: :member
end
```

```erb
<%= form_for [ :update_name, @user ] do |f| %>
```

```ruby
class UsersController < ApplicationController
  def update_name
    # Change needed; form_for will try to use a non-existent PATCH route.
  end
end
```

If the action is not being used in a public API and you are free to change the
HTTP method, you can update your route to use `patch` instead of `put`:

```ruby
resources :users do
  patch :update_name, on: :member
end
```

`PUT` requests to `/users/:id` in Rails 4 get routed to `update` as they are
today. So, if you have an API that gets real PUT requests it is going to work.
The router also routes `PATCH` requests to `/users/:id` to the `update` action.

If the action is being used in a public API and you can't change to HTTP method
being used, you can update your form to use the `PUT` method instead:

```erb
<%= form_for [ :update_name, @user ], method: :put do |f| %>
```

For more on PATCH and why this change was made, see [this
post](https://rubyonrails.org/2012/2/26/edge-rails-patch-is-the-new-primary-http-method-for-updates)
on the Rails blog.

#### A note about media types

The errata for the `PATCH` verb [specifies that a 'diff' media type should be
used with `PATCH`](http://www.rfc-editor.org/errata_search.php?rfc=5789). One
such format is [JSON Patch](https://tools.ietf.org/html/rfc6902). While Rails
does not support JSON Patch natively, it's easy enough to add support:

```ruby
# in your controller:
def update
  respond_to do |format|
    format.json do
      # perform a partial update
      @article.update params[:article]
    end

    format.json_patch do
      # perform sophisticated change
    end
  end
end
```

```ruby
# config/initializers/json_patch.rb
Mime::Type.register "application/json-patch+json", :json_patch
```

As JSON Patch was only recently made into an RFC, there aren't a lot of great
Ruby libraries yet. Aaron Patterson's [hana](https://github.com/tenderlove/hana)
is one such gem, but doesn't have full support for the last few changes in the
specification.

### Gemfile

Rails 4.0 removed the `assets` group from `Gemfile`. You'd need to remove that
line from your `Gemfile` when upgrading. You should also update your application
file (in `config/application.rb`):

```ruby
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
```

### vendor/plugins

Rails 4.0 no longer supports loading plugins from `vendor/plugins`. You must
replace any plugins by extracting them to gems and adding them to your
`Gemfile`. If you choose not to make them gems, you can move them into, say,
`lib/my_plugin/*` and add an appropriate initializer in
`config/initializers/my_plugin.rb`.

### Active Record

* Rails 4.0 has removed the identity map from Active Record, due to [some
  inconsistencies with
  associations](https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6).
  If you have manually enabled it in your application, you will have to remove
  the following config that has no effect anymore:
  `config.active_record.identity_map`.

* The `delete` method in collection associations can now receive `Integer` or
  `String` arguments as record ids, besides records, pretty much like the
  `destroy` method does. Previously it raised
  `ActiveRecord::AssociationTypeMismatch` for such arguments. From Rails 4.0 on
  `delete` automatically tries to find the records matching the given ids before
  deleting them.

* In Rails 4.0 when a column or a table is renamed the related indexes are also
  renamed. If you have migrations which rename the indexes, they are no longer
  needed.

* Rails 4.0 has changed `serialized_attributes` and `attr_readonly` to class
  methods only. You shouldn't use instance methods since it's now deprecated.
  You should change them to use class methods, e.g. `self.serialized_attributes`
  to `self.class.serialized_attributes`.

* When using the default coder, assigning `nil` to a serialized attribute will
  save it to the database as `NULL` instead of passing the `nil` value through
  YAML (`"--- \n...\n"`).

* Rails 4.0 has removed `attr_accessible` and `attr_protected` feature in favor
  of Strong Parameters. You can use the [Protected Attributes
  gem](https://github.com/rails/protected_attributes) for a smooth upgrade path.

* If you are not using Protected Attributes, you can remove any options related
  to this gem such as `whitelist_attributes` or `mass_assignment_sanitizer`
  options.

* Rails 4.0 requires that scopes use a callable object such as a Proc or lambda:

    ```ruby
    scope :active, where(active: true)

    # becomes
    scope :active, -> { where active: true }
    ```

* Rails 4.0 has deprecated `ActiveRecord::Fixtures` in favor of
  `ActiveRecord::FixtureSet`.

* Rails 4.0 has deprecated `ActiveRecord::TestCase` in favor of
  `ActiveSupport::TestCase`.

* Rails 4.0 has deprecated the old-style hash-based finder API. This means that
  methods which previously accepted "finder options" no longer do.  For example,
  `Book.find(:all, conditions: { name: '1984' })` has been deprecated in favor
  of `Book.where(name: '1984')`

* All dynamic methods except for `find_by_...` and `find_by_...!` are
  deprecated. Here's how you can handle the changes:

      * `find_all_by_...`           becomes `where(...)`.
      * `find_last_by_...`          becomes `where(...).last`.
      * `scoped_by_...`             becomes `where(...)`.
      * `find_or_initialize_by_...` becomes `find_or_initialize_by(...)`.
      * `find_or_create_by_...`     becomes `find_or_create_by(...)`.

* Note that `where(...)` returns a relation, not an array like the old finders.
  If you require an `Array`, use `where(...).to_a`.

* These equivalent methods may not execute the same SQL as the previous
  implementation.

* To re-enable the old finders, you can use the [activerecord-deprecated_finders
  gem](https://github.com/rails/activerecord-deprecated_finders).

* Rails 4.0 has changed to default join table for `has_and_belongs_to_many`
  relations to strip the common prefix off the second table name. Any existing
  `has_and_belongs_to_many` relationship between models with a common prefix
  must be specified with the `join_table` option. For example:

    ```ruby
    class CatalogCategory < ActiveRecord::Base
      has_and_belongs_to_many :catalog_products, join_table: "catalog_categories_catalog_products"
    end

    class CatalogProduct < ActiveRecord::Base
      has_and_belongs_to_many :catalog_categories, join_table: "catalog_categories_catalog_products"
    end
    ```

* Note that the prefix takes scopes into account as well, so relations between
  `Catalog::Category` and `Catalog::Product` or `Catalog::Category` and
  `CatalogProduct` need to be updated similarly.

### Active Resource

Rails 4.0 extracted Active Resource to its own gem. If you still need the
feature you can add the [Active Resource
gem](https://github.com/rails/activeresource) in your `Gemfile`.

### Active Model

* Rails 4.0 has changed how errors attach with the
  `ActiveModel::Validations::ConfirmationValidator`. Now when confirmation
  validations fail, the error will be attached to `:#{attribute}_confirmation`
  instead of `attribute`.

* Rails 4.0 has changed `ActiveModel::Serializers::JSON.include_root_in_json`
  default value to `false`. Now, Active Model Serializers and Active Record
  objects have the same default behavior. This means that you can comment or
  remove the following option in the `config/initializers/wrap_parameters.rb`
  file:

    ```ruby
    # Disable root element in JSON by default.
    # ActiveSupport.on_load(:active_record) do
    #   self.include_root_in_json = false
    # end
    ```

### Action Pack

* Rails 4.0 introduces `ActiveSupport::KeyGenerator` and uses this as a base
  from which to generate and verify signed cookies (among other things).
  Existing signed cookies generated with Rails 3.x will be transparently
  upgraded if you leave your existing `secret_token` in place and add the new
  `secret_key_base`.

    ```ruby
    # config/initializers/secret_token.rb
    Myapp::Application.config.secret_token = "existing secret token"
    Myapp::Application.config.secret_key_base = "new secret key base"
    ```

    Please note that you should wait to set `secret_key_base` until you have
    100% of your userbase on Rails 4.x and are reasonably sure you will not need
    to rollback to Rails 3.x. This is because cookies signed based on the new
    `secret_key_base` in Rails 4.x are not backwards compatible with Rails 3.x.
    You are free to leave your existing `secret_token` in place, not set the new
    `secret_key_base`, and ignore the deprecation warnings until you are
    reasonably sure that your upgrade is otherwise complete.

    If you are relying on the ability for external applications or JavaScript to
    be able to read your Rails app's signed session cookies (or signed cookies
    in general) you should not set `secret_key_base` until you have decoupled
    these concerns.

* Rails 4.0 encrypts the contents of cookie-based sessions if `secret_key_base`
  has been set. Rails 3.x signed, but did not encrypt, the contents of
  cookie-based session. Signed cookies are "secure" in that they are verified to
  have been generated by your app and are tamper-proof. However, the contents
  can be viewed by end users, and encrypting the contents eliminates this
  caveat/concern without a significant performance penalty.

    Please read [Pull Request #9978](https://github.com/rails/rails/pull/9978)
    for details on the move to encrypted session cookies.

* Rails 4.0 removed the `ActionController::Base.asset_path` option. Use the
  assets pipeline feature.

* Rails 4.0 has deprecated `ActionController::Base.page_cache_extension` option.
  Use `ActionController::Base.default_static_extension` instead.

* Rails 4.0 has removed Action and Page caching from Action Pack. You will need
  to add the `actionpack-action_caching` gem in order to use `caches_action` and
  the `actionpack-page_caching` to use `caches_page` in your controllers.

* Rails 4.0 has removed the XML parameters parser. You will need to add the
  `actionpack-xml_parser` gem if you require this feature.

* Rails 4.0 changes the default `layout` lookup set using symbols or procs that
  return nil. To get the "no layout" behavior, return false instead of nil.

* Rails 4.0 changes the default memcached client from `memcache-client` to
  `dalli`. To upgrade, simply add `gem "dalli"` to your `Gemfile`.

* Rails 4.0 deprecates the `dom_id` and `dom_class` methods in controllers (they
  are fine in views). You will need to include the
  `ActionView::RecordIdentifier` module in controllers requiring this feature.

* Rails 4.0 deprecates the `:confirm` option for the `link_to` helper. You
  should instead rely on a data attribute (e.g. `data: { confirm: 'Are you
  sure?' }`). This deprecation also concerns the helpers based on this one (such
  as `link_to_if` or `link_to_unless`).

* Rails 4.0 changed how `assert_generates`, `assert_recognizes`, and
  `assert_routing` work. Now all these assertions raise `Assertion` instead of
  `ActionController::RoutingError`.

* Rails 4.0 raises an `ArgumentError` if clashing named routes are defined. This
  can be triggered by explicitly defined named routes or by the `resources`
  method. Here are two examples that clash with routes named `example_path`:

    ```ruby
    get "one" => "test#example", as: :example
    get "two" => "test#example", as: :example
    ```

    ```ruby
    resources :examples
    get "clashing/:id" => "test#example", as: :example
    ```

    In the first case, you can simply avoid using the same name for multiple
    routes. In the second, you can use the `only` or `except` options provided
    by the `resources` method to restrict the routes created as detailed in the
    [Routing Guide](routing.html#restricting-the-routes-created).

* Rails 4.0 also changed the way unicode character routes are drawn. Now you can
  draw unicode character routes directly. If you already draw such routes, you
  must change them, for example:

    ```ruby
    get Rack::Utils.escape("こんにちは"), controller: "welcome", action: "index"
    ```

    becomes

    ```ruby
    get "こんにちは", controller: "welcome", action: "index"
    ```

* Rails 4.0 requires that routes using `match` must specify the request method.
  For example:

    ```ruby
    # Rails 3.x
    match "/" => "root#index"

    # becomes
    match "/" => "root#index", via: :get

    # or
    get "/" => "root#index"
    ```

* Rails 4.0 has removed `ActionDispatch::BestStandardsSupport` middleware,
  `<!DOCTYPE html>` already triggers standards mode per
  https://msdn.microsoft.com/en-us/library/jj676915(v=vs.85).aspx and
  ChromeFrame header has been moved to `config.action_dispatch.default_headers`.

    Remember you must also remove any references to the middleware from your
    application code, for example:

    ```ruby
    # Raise exception
    config.middleware.insert_before(Rack::Lock, ActionDispatch::BestStandardsSupport)
    ```

    Also check your environment settings for
    `config.action_dispatch.best_standards_support` and remove it if present.

* Rails 4.0 allows configuration of HTTP headers by setting
  `config.action_dispatch.default_headers`. The defaults are as follows:

    ```ruby
    config.action_dispatch.default_headers = {
      "X-Frame-Options" => "SAMEORIGIN",
      "X-XSS-Protection" => "1; mode=block"
    }
    ```

    Please note that if your application is dependent on loading certain pages
    in a `<frame>` or `<iframe>`, then you may need to explicitly set
    `X-Frame-Options` to `ALLOW-FROM ...` or `ALLOWALL`.

* In Rails 4.0, precompiling assets no longer automatically copies non-JS/CSS
  assets from `vendor/assets` and `lib/assets`. Rails application and engine
  developers should put these assets in `app/assets` or configure
  [`config.assets.precompile`][].

* In Rails 4.0, `ActionController::UnknownFormat` is raised when the action
  doesn't handle the request format. By default, the exception is handled by
  responding with 406 Not Acceptable, but you can override that now. In Rails 3,
  406 Not Acceptable was always returned. No overrides.

* In Rails 4.0, a generic `ActionDispatch::ParamsParser::ParseError` exception
  is raised when `ParamsParser` fails to parse request params. You will want to
  rescue this exception instead of the low-level `MultiJson::DecodeError`, for
  example.

* In Rails 4.0, `SCRIPT_NAME` is properly nested when engines are mounted on an
  app that's served from a URL prefix. You no longer have to set
  `default_url_options[:script_name]` to work around overwritten URL prefixes.

* Rails 4.0 deprecated `ActionController::Integration` in favor of
  `ActionDispatch::Integration`.
* Rails 4.0 deprecated `ActionController::IntegrationTest` in favor of
  `ActionDispatch::IntegrationTest`.
* Rails 4.0 deprecated `ActionController::PerformanceTest` in favor of
  `ActionDispatch::PerformanceTest`.
* Rails 4.0 deprecated `ActionController::AbstractRequest` in favor of
  `ActionDispatch::Request`.
* Rails 4.0 deprecated `ActionController::Request` in favor of
  `ActionDispatch::Request`.
* Rails 4.0 deprecated `ActionController::AbstractResponse` in favor of
  `ActionDispatch::Response`.
* Rails 4.0 deprecated `ActionController::Response` in favor of
  `ActionDispatch::Response`.
* Rails 4.0 deprecated `ActionController::Routing` in favor of
  `ActionDispatch::Routing`.

[`config.assets.precompile`]: configuring.html#config-assets-precompile

### Active Support

Rails 4.0 removes the `j` alias for `ERB::Util#json_escape` since `j` is already
used for `ActionView::Helpers::JavaScriptHelper#escape_javascript`.

#### Cache

The caching method changed between Rails 3.x and 4.0. You should [change the
cache
namespace](https://guides.rubyonrails.org/v4.0/caching_with_rails.html#activesupport-cache-store)
and roll out with a cold cache.

### Helpers Loading Order

The order in which helpers from more than one directory are loaded has changed
in Rails 4.0. Previously, they were gathered and then sorted alphabetically.
After upgrading to Rails 4.0, helpers will preserve the order of loaded
directories and will be sorted alphabetically only within each directory. Unless
you explicitly use the `helpers_path` parameter, this change will only impact
the way of loading helpers from engines. If you rely on the ordering, you should
check if correct methods are available after upgrade. If you would like to
change the order in which engines are loaded, you can use
`config.railties_order=` method.

### Active Record Observer and Action Controller Sweeper

`ActiveRecord::Observer` and `ActionController::Caching::Sweeper` have been
extracted to the `rails-observers` gem. You will need to add the
`rails-observers` gem if you require these features.

### sprockets-rails

* `assets:precompile:primary` and `assets:precompile:all` have been removed. Use
  `assets:precompile` instead.
* The `config.assets.compress` option should be changed to
  [`config.assets.js_compressor`][] like so for instance:

    ```ruby
    config.assets.js_compressor = :uglifier
    ```

[`config.assets.js_compressor`]: configuring.html#config-assets-js-compressor

### sass-rails

* `asset-url` with two arguments is deprecated. For example:
  `asset-url("rails.png", image)` becomes `asset-url("rails.png")`.
