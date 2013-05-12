A Guide for Upgrading Ruby on Rails
===================================

This guide provides steps to be followed when you upgrade your applications to a newer version of Ruby on Rails. These steps are also available in individual release guides.

General Advice
--------------

Before attempting to upgrade an existing application, you should be sure you have a good reason to upgrade. You need to balance out several factors: the need for new features, the increasing difficulty of finding support for old code, and your available time and skills, to name a few.

### Test Coverage

The best way to be sure that your application still works after upgrading is to have good test coverage before you start the process. If you don't have automated tests that exercise the bulk of your application, you'll need to spend time manually exercising all the parts that have changed. In the case of a Rails upgrade, that will mean every single piece of functionality in the application. Do yourself a favor and make sure your test coverage is good _before_ you start an upgrade.

### Ruby Versions

Rails generally stays close to the latest released Ruby version when it's released:

* Rails 3 and above require Ruby 1.8.7 or higher. Support for all of the previous Ruby versions has been dropped officially. You should upgrade as early as possible.
* Rails 3.2.x is the last branch to support Ruby 1.8.7.
* Rails 4 prefers Ruby 2.0 and requires 1.9.3 or newer.

TIP: Ruby 1.8.7 p248 and p249 have marshaling bugs that crash Rails. Ruby Enterprise Edition has these fixed since the release of 1.8.7-2010.02. On the 1.9 front, Ruby 1.9.1 is not usable because it outright segfaults, so if you want to use 1.9.x, jump straight to 1.9.3 for smooth sailing.

Upgrading from Rails 3.2 to Rails 4.0
-------------------------------------

NOTE: This section is a work in progress.

If your application is currently on any version of Rails older than 3.2.x, you should upgrade to Rails 3.2 before attempting one to Rails 4.0.

The following changes are meant for upgrading your application to Rails 4.0.

### Gemfile

Rails 4.0 removed the `assets` group from Gemfile. You'd need to remove that line from your Gemfile when upgrading.

### vendor/plugins

Rails 4.0 no longer supports loading plugins from `vendor/plugins`. You must replace any plugins by extracting them to gems and adding them to your Gemfile. If you choose not to make them gems, you can move them into, say, `lib/my_plugin/*` and add an appropriate initializer in `config/initializers/my_plugin.rb`.

### Active Record

* Rails 4.0 has removed the identity map from Active Record, due to [some inconsistencies with associations](https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6). If you have manually enabled it in your application, you will have to remove the following config that has no effect anymore: `config.active_record.identity_map`.

* The `delete` method in collection associations can now receive `Fixnum` or `String` arguments as record ids, besides records, pretty much like the `destroy` method does. Previously it raised `ActiveRecord::AssociationTypeMismatch` for such arguments. From Rails 4.0 on `delete` automatically tries to find the records matching the given ids before deleting them.

* Rails 4.0 has changed how orders get stacked in `ActiveRecord::Relation`. In previous versions of Rails, the new order was applied after the previously defined order. But this is no longer true. Check [Active Record Query guide](active_record_querying.html#ordering) for more information.

* Rails 4.0 has changed `serialized_attributes` and `attr_readonly` to class methods only. You shouldn't use instance methods since it's now deprecated. You should change them to use class methods, e.g. `self.serialized_attributes` to `self.class.serialized_attributes`.

* Rails 4.0 has removed `attr_accessible` and `attr_protected` feature in favor of Strong Parameters. You can use the [Protected Attributes gem](https://github.com/rails/protected_attributes) to a smoothly upgrade path.

* Rails 4.0 requires that scopes use a callable object such as a Proc or lambda:

```ruby
  scope :active, where(active: true)

  # becomes
  scope :active, -> { where active: true }
```

* Rails 4.0 has deprecated `ActiveRecord::Fixtures` in favor of `ActiveRecord::FixtureSet`.
* Rails 4.0 has deprecated `ActiveRecord::TestCase` in favor of `ActiveSupport::TestCase`.

### Active Resource

Rails 4.0 extracted Active Resource to its own gem. If you still need the feature you can add the [Active Resource gem](https://github.com/rails/activeresource) in your Gemfile.

### Active Model

* Rails 4.0 has changed how errors attach with the `ActiveModel::Validations::ConfirmationValidator`. Now when confirmation validations fail, the error will be attached to `:#{attribute}_confirmation` instead of `attribute`.

* Rails 4.0 has changed `ActiveModel::Serializers::JSON.include_root_in_json` default value to `false`. Now, Active Model Serializers and Active Record objects have the same default behaviour. This means that you can comment or remove the following option in the `config/initializers/wrap_parameters.rb` file:

```ruby
# Disable root element in JSON by default.
# ActiveSupport.on_load(:active_record) do
#   self.include_root_in_json = false
# end
```

### Action Pack

* Rails 4.0 introduces `ActiveSupport::KeyGenerator` and uses this as a base from which to generate and verify signed cookies (among other things). Existing signed cookies generated with Rails 3.x will be transparently upgraded if you leave your existing `secret_token` in place and add the new `secret_key_base`.

```ruby
  # config/initializers/secret_token.rb
  Myapp::Application.config.secret_token = 'existing secret token'
  Myapp::Application.config.secret_key_base = 'new secret key base'
```

Please note that you should wait to set `secret_key_base` until you have 100% of your userbase on Rails 4.x and are reasonably sure you will not need to rollback to Rails 3.x. This is because cookies signed based on the new `secret_key_base` in Rails 4.x are not backwards compatible with Rails 3.x. You are free to leave your existing `secret_token` in place, not set the new `secret_key_base`, and ignore the deprecation warnings until you are reasonably sure that your upgrade is otherwise complete.

If you are relying on the ability for external applications or Javascript to be able to read your Rails app's signed session cookies (or signed cookies in general) you should not set `secret_key_base` until you have decoupled these concerns.

* Rails 4.0 encrypts the contents of cookie-based sessions if `secret_key_base` has been set. Rails 3.x signed, but did not encrypt, the contents of cookie-based session. Signed cookies are "secure" in that they are verified to have been generated by your app and are tamper-proof. However, the contents can be viewed by end users, and encrypting the contents eliminates this caveat/concern without a significant performance penalty.

As described above, existing signed cookies generated with Rails 3.x will be transparently upgraded if you leave your existing `secret_token` in place and add the new `secret_key_base`.

```ruby
  # config/initializers/secret_token.rb
  Myapp::Application.config.secret_token = 'existing secret token'
  Myapp::Application.config.secret_key_base = 'new secret key base'
```

The same caveats apply here, too. You should wait to set `secret_key_base` until you have 100% of your userbase on Rails 4.x and are reasonably sure you will not need to rollback to Rails 3.x. You should also take care to make sure you are not relying on the ability to decode signed cookies generated by your app in external applications or Javascript before upgrading.

Please read [Pull Request #9978](https://github.com/rails/rails/pull/9978) for details on the move to encrypted session cookies.

* Rails 4.0 removed the `ActionController::Base.asset_path` option. Use the assets pipeline feature.

* Rails 4.0 has deprecated `ActionController::Base.page_cache_extension` option. Use `ActionController::Base.default_static_extension` instead.

* Rails 4.0 has removed Action and Page caching from Action Pack. You will need to add the `actionpack-action_caching` gem in order to use `caches_action` and the `actionpack-page_caching` to use `caches_pages` in your controllers.

* Rails 4.0 has removed the XML parameters parser. You will need to add the `actionpack-xml_parser` gem if you require this feature.

* Rails 4.0 changes the default memcached client from `memcache-client` to `dalli`. To upgrade, simply add `gem 'dalli'` to your `Gemfile`.

* Rails 4.0 deprecates the `dom_id` and `dom_class` methods in controllers (they are fine in views). You will need to include the `ActionView::RecordIdentifier` module in controllers requiring this feature.

* Rails 4.0 changed how `assert_generates`, `assert_recognizes`, and `assert_routing` work. Now all these assertions raise `Assertion` instead of `ActionController::RoutingError`.

* Rails 4.0 raises an `ArgumentError` if clashing named routes are defined. This can be triggered by explicitly defined named routes or by the `resources` method. Here are two examples that clash with routes named `example_path`:

```ruby
  get 'one' => 'test#example', as: :example
  get 'two' => 'test#example', as: :example
```

```ruby
  resources :examples
  get 'clashing/:id' => 'test#example', as: :example
```

In the first case, you can simply avoid using the same name for multiple
routes. In the second, you can use the `only` or `except` options provided by
the `resources` method to restrict the routes created as detailed in the
[Routing Guide](routing.html#restricting-the-routes-created).

* Rails 4.0 also changed the way unicode character routes are drawn. Now you can draw unicode character routes directly. If you already draw such routes, you must change them, for example:

```ruby
get Rack::Utils.escape('こんにちは'), controller: 'welcome', action: 'index'
```

becomes

```ruby
get 'こんにちは', controller: 'welcome', action: 'index'
```

* Rails 4.0 requires that routes using `match` must specify the request method. For example:

```ruby
  # Rails 3.x
  match "/" => "root#index"

  # becomes
  match "/" => "root#index", via: :get

  # or
  get "/" => "root#index"
```

* Rails 4.0 has removed `ActionDispatch::BestStandardsSupport` middleware, `<!DOCTYPE html>` already triggers standards mode per http://msdn.microsoft.com/en-us/library/jj676915(v=vs.85).aspx and ChromeFrame header has been moved to `config.action_dispatch.default_headers`.

Remember you must also remove any references to the middleware from your application code, for example:

```ruby
# Raise exception
config.middleware.insert_before(Rack::Lock, ActionDispatch::BestStandardsSupport)
```

Also check your environment settings for `config.action_dispatch.best_standards_support` and remove it if present.

* In Rails 4.0, precompiling assets no longer automatically copies non-JS/CSS assets from `vendor/assets` and `lib/assets`. Rails application and engine developers should put these assets in `app/assets` or configure `config.assets.precompile`.

* In Rails 4.0, `ActionController::UnknownFormat` is raised when the action doesn't handle the request format. By default, the exception is handled by responding with 406 Not Acceptable, but you can override that now. In Rails 3, 406 Not Acceptable was always returned. No overrides.

* In Rails 4.0, a generic `ActionDispatch::ParamsParser::ParseError` exception is raised when `ParamsParser` fails to parse request params. You will want to rescue this exception instead of the low-level `MultiJson::DecodeError`, for example.

* In Rails 4.0, `SCRIPT_NAME` is properly nested when engines are mounted on an app that's served from a URL prefix. You no longer have to set `default_url_options[:script_name]` to work around overwritten URL prefixes.

* Rails 4.0 deprecated `ActionController::Integration` in favor of `ActionDispatch::Integration`.
* Rails 4.0 deprecated `ActionController::IntegrationTest` in favor of `ActionDispatch::IntegrationTest`.
* Rails 4.0 deprecated `ActionController::PerformanceTest` in favor of `ActionDispatch::PerformanceTest`.
* Rails 4.0 deprecated `ActionController::AbstractRequest` in favor of `ActionDispatch::Request`.
* Rails 4.0 deprecated `ActionController::Request` in favor of `ActionDispatch::Request`.
* Rails 4.0 deprecated `ActionController::AbstractResponse` in favor of `ActionDispatch::Response`.
* Rails 4.0 deprecated `ActionController::Response` in favor of `ActionDispatch::Response`.
* Rails 4.0 deprecated `ActionController::Routing` in favor of `ActionDispatch::Routing`.

### Active Support

Rails 4.0 removes the `j` alias for `ERB::Util#json_escape` since `j` is already used for `ActionView::Helpers::JavaScriptHelper#escape_javascript`.

### Helpers Loading Order

The order in which helpers from more than one directory are loaded has changed in Rails 4.0. Previously, they were gathered and then sorted alphabetically. After upgrading to Rails 4.0, helpers will preserve the order of loaded directories and will be sorted alphabetically only within each directory. Unless you explicitly use the `helpers_path` parameter, this change will only impact the way of loading helpers from engines. If you rely on the ordering, you should check if correct methods are available after upgrade. If you would like to change the order in which engines are loaded, you can use `config.railties_order=` method.

### Active Record Observer and Action Controller Sweeper

Active Record Observer and Action Controller Sweeper have been extracted to the `rails-observers` gem. You will need to add the `rails-observers` gem if you require these features.

### sprockets-rails

* `assets:precompile:primary` has been removed. Use `assets:precompile` instead.

### sass-rails

* `asset_url` with two arguments is deprecated. For example: `asset-url("rails.png", image)` becomes `asset-url("rails.png")`

Upgrading from Rails 3.1 to Rails 3.2
-------------------------------------

If your application is currently on any version of Rails older than 3.1.x, you should upgrade to Rails 3.1 before attempting an update to Rails 3.2.

The following changes are meant for upgrading your application to Rails 3.2.12, the latest 3.2.x version of Rails.

### Gemfile

Make the following changes to your `Gemfile`.

```ruby
gem 'rails', '= 3.2.12'

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '>= 1.0.3'
end
```

### config/environments/development.rb

There are a couple of new configuration settings that you should add to your development environment:

```ruby
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict

# Log the query plan for queries taking more than this (works
# with SQLite, MySQL, and PostgreSQL)
config.active_record.auto_explain_threshold_in_seconds = 0.5
```

### config/environments/test.rb

The `mass_assignment_sanitizer` configuration setting should also be be added to `config/environments/test.rb`:

```ruby
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict
```

### vendor/plugins

Rails 3.2 deprecates `vendor/plugins` and Rails 4.0 will remove them completely. While it's not strictly necessary as part of a Rails 3.2 upgrade, you can start replacing any plugins by extracting them to gems and adding them to your Gemfile. If you choose not to make them gems, you can move them into, say, `lib/my_plugin/*` and add an appropriate initializer in `config/initializers/my_plugin.rb`.

Upgrading from Rails 3.0 to Rails 3.1
-------------------------------------

If your application is currently on any version of Rails older than 3.0.x, you should upgrade to Rails 3.0 before attempting an update to Rails 3.1.

The following changes are meant for upgrading your application to Rails 3.1.11, the latest 3.1.x version of Rails.

### Gemfile

Make the following changes to your `Gemfile`.

```ruby
gem 'rails', '= 3.1.11'
gem 'mysql2'

# Needed for the new asset pipeline
group :assets do
  gem 'sass-rails',   "~> 3.1.5"
  gem 'coffee-rails', "~> 3.1.1"
  gem 'uglifier',     ">= 1.0.3"
end

# jQuery is the default JavaScript library in Rails 3.1
gem 'jquery-rails'
```

### config/application.rb

The asset pipeline requires the following additions:

```ruby
config.assets.enabled = true
config.assets.version = '1.0'
```

If your application is using an "/assets" route for a resource you may want change the prefix used for assets to avoid conflicts:

```ruby
# Defaults to '/assets'
config.assets.prefix = '/asset-files'
```

### config/environments/development.rb

Remove the RJS setting `config.action_view.debug_rjs = true`.

Add these settings if you enable the asset pipeline:

```ruby
# Do not compress assets
config.assets.compress = false

# Expands the lines which load the assets
config.assets.debug = true
```

### config/environments/production.rb

Again, most of the changes below are for the asset pipeline. You can read more about these in the [Asset Pipeline](asset_pipeline.html) guide.

```ruby
# Compress JavaScripts and CSS
config.assets.compress = true

# Don't fallback to assets pipeline if a precompiled asset is missed
config.assets.compile = false

# Generate digests for assets URLs
config.assets.digest = true

# Defaults to Rails.root.join("public/assets")
# config.assets.manifest = YOUR_PATH

# Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
# config.assets.precompile += %w( search.js )

# Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
# config.force_ssl = true
```

### config/environments/test.rb

You can help test performance with these additions to your test environment:

```ruby
# Configure static asset server for tests with Cache-Control for performance
config.serve_static_assets = true
config.static_cache_control = "public, max-age=3600"
```

### config/initializers/wrap_parameters.rb

Add this file with the following contents, if you wish to wrap parameters into a nested hash. This is on by default in new applications.

```ruby
# Be sure to restart your server when you modify this file.
# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.

# Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: [:json]
end

# Disable root element in JSON by default.
ActiveSupport.on_load(:active_record) do
  self.include_root_in_json = false
end
```

### config/initializers/session_store.rb

You need to change your session key to something new, or remove all sessions:

```ruby
# in config/initializers/session_store.rb
AppName::Application.config.session_store :cookie_store, key: 'SOMETHINGNEW'
```

or

```bash
$ rake db:sessions:clear
```

### Remove :cache and :concat options in asset helpers references in views

* With the Asset Pipeline the :cache and :concat options aren't used anymore, delete these options from your views.
