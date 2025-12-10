**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 3.0 to Rails 3.1
=====================================

This guide provides steps to be followed when you upgrade your applications from
Rails 3.0 to Rails 3.1. These steps are also available in individual release
guides.

--------------------------------------------------------------------------------

Key Changes
-----------

If your application is currently on any version of Rails older than 3.0.x, you
should upgrade to Rails 3.0 before attempting an update to Rails 3.1.

The following changes are meant for upgrading your application to Rails 3.1.12,
the last 3.1.x version of Rails.

### Gemfile

Make the following changes to your `Gemfile`.

```ruby
gem "rails", "3.1.12"
gem "mysql2"

# Needed for the new asset pipeline
group :assets do
  gem "sass-rails",   "~> 3.1.7"
  gem "coffee-rails", "~> 3.1.1"
  gem "uglifier",     ">= 1.0.3"
end

# jQuery is the default JavaScript library in Rails 3.1
gem "jquery-rails"
```

### config/application.rb

The asset pipeline requires the following additions:

```ruby
config.assets.enabled = true
config.assets.version = "1.0"
```

If your application is using an "/assets" route for a resource you may want to
change the prefix used for assets to avoid conflicts:

```ruby
# Defaults to '/assets'
config.assets.prefix = "/asset-files"
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

Again, most of the changes below are for the asset pipeline. You can read more
about these in the [Asset Pipeline](asset_pipeline.html) guide.

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
# config.assets.precompile += %w( admin.js admin.css )

# Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
# config.force_ssl = true
```

### config/environments/test.rb

You can help test performance with these additions to your test environment:

```ruby
# Configure static asset server for tests with Cache-Control for performance
config.public_file_server.enabled = true
config.public_file_server.headers = {
  "Cache-Control" => "public, max-age=3600"
}
```

### config/initializers/wrap_parameters.rb

Add this file with the following contents, if you wish to wrap parameters into a
nested hash. This is on by default in new applications.

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
AppName::Application.config.session_store :cookie_store, key: "SOMETHINGNEW"
```

or

```bash
$ bin/rake db:sessions:clear
```

### Remove :cache and :concat options in asset helpers references in views

* With the Asset Pipeline the :cache and :concat options aren't used anymore,
  delete these options from your views.
