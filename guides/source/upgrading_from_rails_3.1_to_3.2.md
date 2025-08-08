**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 3.1 to Rails 3.2
=====================================

This guide provides steps to be followed when you upgrade your applications from
Rails 3.1 to Rails 3.2. These steps are also available in individual release
guides.

--------------------------------------------------------------------------------

Key Changes
-----------

If your application is currently on any version of Rails older than 3.1.x, you
should upgrade to Rails 3.1 before attempting an update to Rails 3.2.

The following changes are meant for upgrading your application to the latest
3.2.x version of Rails.

### Gemfile

Make the following changes to your `Gemfile`.

```ruby
gem "rails", "3.2.21"

group :assets do
  gem "sass-rails",   "~> 3.2.6"
  gem "coffee-rails", "~> 3.2.2"
  gem "uglifier",     ">= 1.0.3"
end
```

### config/environments/development.rb

There are a couple of new configuration settings that you should add to your
development environment:

```ruby
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict

# Log the query plan for queries taking more than this (works
# with SQLite, MySQL, and PostgreSQL)
config.active_record.auto_explain_threshold_in_seconds = 0.5
```

### config/environments/test.rb

The `mass_assignment_sanitizer` configuration setting should also be added to
`config/environments/test.rb`:

```ruby
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict
```

### vendor/plugins

Rails 3.2 deprecates `vendor/plugins` and Rails 4.0 will remove them completely.
While it's not strictly necessary as part of a Rails 3.2 upgrade, you can start
replacing any plugins by extracting them to gems and adding them to your
`Gemfile`. If you choose not to make them gems, you can move them into, say,
`lib/my_plugin/*` and add an appropriate initializer in
`config/initializers/my_plugin.rb`.

### Active Record

Option `:dependent => :restrict` has been removed from `belongs_to`. If you want
to prevent deleting the object if there are any associated objects, you can set
`:dependent => :destroy` and return `false` after checking for existence of
association from any of the associated object's destroy callbacks.
