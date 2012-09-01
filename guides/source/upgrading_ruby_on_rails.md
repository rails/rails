h2. A Guide for Upgrading Ruby on Rails

This guide provides steps to be followed when you upgrade your applications to a newer version of Ruby on Rails. These steps are also available in individual release guides.

endprologue.

h3. General Advice

Before attempting to upgrade an existing application, you should be sure you have a good reason to upgrade. You need to balance out several factors: the need for new features, the increasing difficulty of finding support for old code, and your available time and skills, to name a few.

h4(#general_testing). Test Coverage

The best way to be sure that your application still works after upgrading is to have good test coverage before you start the process. If you don't have automated tests that exercise the bulk of your application, you'll need to spend time manually exercising all the parts that have changed. In the case of a Rails upgrade, that will mean every single piece of functionality in the application. Do yourself a favor and make sure your test coverage is good _before_ you start an upgrade.

h4(#general_ruby). Ruby Versions

Rails generally stays close to the latest released Ruby version when it's released:

* Rails 3 and above requires Ruby 1.8.7 or higher. Support for all of the previous Ruby versions has been dropped officially and you should upgrade as early as possible.
* Rails 3.2.x will be the last branch to support Ruby 1.8.7.
* Rails 4 will support only Ruby 1.9.3.

TIP: Ruby 1.8.7 p248 and p249 have marshaling bugs that crash Rails. Ruby Enterprise Edition has these fixed since the release of 1.8.7-2010.02. On the 1.9 front, Ruby 1.9.1 is not usable because it outright segfaults, so if you want to use 1.9.x, jump on to 1.9.2 or 1.9.3 for smooth sailing.

h3. Upgrading from Rails 3.2 to Rails 4.0

NOTE: This section is a work in progress.

If your application is currently on any version of Rails older than 3.2.x, you should upgrade to Rails 3.2 before attempting an update to Rails 4.0.

The following changes are meant for upgrading your application to Rails 4.0.

h4(#plugins4_0). vendor/plugins

Rails 4.0 no longer supports loading plugins from <tt>vendor/plugins</tt>. You must replace any plugins by extracting them to gems and adding them to your Gemfile. If you choose not to make them gems, you can move them into, say, <tt>lib/my_plugin/*</tt> and add an appropriate initializer in <tt>config/initializers/my_plugin.rb</tt>.

h4(#identity_map4_0). Identity Map

Rails 4.0 has removed the identity map from Active Record, due to "some inconsistencies with associations":https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6. If you have manually enabled it in your application, you will have to remove the following config that has no effect anymore: <tt>config.active_record.identity_map</tt>.

h4(#active_record4_0). Active Record

The <tt>delete</tt> method in collection associations can now receive <tt>Fixnum</tt> or <tt>String</tt> arguments as record ids, besides records, pretty much like the <tt>destroy</tt> method does. Previously it raised <tt>ActiveRecord::AssociationTypeMismatch</tt> for such arguments. From Rails 4.0 on <tt>delete</tt> automatically tries to find the records matching the given ids before deleting them.

Rails 4.0 has changed how orders get stacked in +ActiveRecord::Relation+. In previous versions of rails new order was applied after previous defined order. But this is no long true. Check "ActiveRecord Query guide":active_record_querying.html#ordering for more information.

Rails 4.0 has changed <tt>serialized_attributes</tt> and <tt>&#95;attr_readonly</tt> to class methods only. Now you shouldn't use instance methods, it's deprecated. You must change them, e.g. <tt>self.serialized_attributes</tt> to <tt>self.class.serialized_attributes</tt>.

h4(#active_model4_0). Active Model

Rails 4.0 has changed how errors attach with the <tt>ActiveModel::Validations::ConfirmationValidator</tt>. Now when confirmation validations fail the error will be attached to <tt>:#{attribute}_confirmation</tt> instead of <tt>attribute</tt>.

h4(#action_pack4_0). Action Pack

Rails 4.0 changed how <tt>assert_generates</tt>, <tt>assert_recognizes</tt>, and <tt>assert_routing</tt> work. Now all these assertions raise <tt>Assertion</tt> instead of <tt>ActionController::RoutingError</tt>.

Rails 4.0 also changed the way unicode character routes are drawn. Now you can draw unicode character routes directly. If you already draw such routes, you must change them, for example:

<ruby>
get Rack::Utils.escape('こんにちは'), :controller => 'welcome', :action => 'index'
</ruby>

becomes

<ruby>
get 'こんにちは', :controller => 'welcome', :action => 'index'
</ruby>

h4(#active_support4_0). Active Support

Rails 4.0 Removed the <tt>j</tt> alias for <tt>ERB::Util#json_escape</tt> since <tt>j</tt> is already used for <tt>ActionView::Helpers::JavaScriptHelper#escape_javascript</tt>.

h4(#helpers_order). Helpers Loading Order

The loading order of helpers from more than one directory has changed in Rails 4.0. Previously, helpers from all directories were gathered and then sorted alphabetically. After upgrade to Rails 4.0 helpers will preserve the order of loaded directories and will be sorted alphabetically only within each directory. Unless you explicitly use <tt>helpers_path</tt> parameter, this change will only impact the way of loading helpers from engines. If you rely on the fact that particular helper from engine loads before or after another helper from application or another engine, you should check if correct methods are available after upgrade. If you would like to change order in which engines are loaded, you can use <tt>config.railties_order=</tt> method.

h3. Upgrading from Rails 3.1 to Rails 3.2

If your application is currently on any version of Rails older than 3.1.x, you should upgrade to Rails 3.1 before attempting an update to Rails 3.2.

The following changes are meant for upgrading your application to Rails 3.2.2, the latest 3.2.x version of Rails.

h4(#gemfile3_2). Gemfile

Make the following changes to your +Gemfile+.

<ruby>
gem 'rails', '= 3.2.2'

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '>= 1.0.3'
end
</ruby>

h4(#config_dev3_2). config/environments/development.rb

There are a couple of new configuration settings that you should add to your development environment:

<ruby>
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict

# Log the query plan for queries taking more than this (works
# with SQLite, MySQL, and PostgreSQL)
config.active_record.auto_explain_threshold_in_seconds = 0.5
</ruby>

h4(#config_test3_2). config/environments/test.rb

The <tt>mass_assignment_sanitizer</tt> configuration setting should also be be added to <tt>config/environments/test.rb</tt>:

<ruby>
# Raise exception on mass assignment protection for Active Record models
config.active_record.mass_assignment_sanitizer = :strict
</ruby>

h4(#plugins3_2). vendor/plugins

Rails 3.2 deprecates <tt>vendor/plugins</tt> and Rails 4.0 will remove them completely. While it's not strictly necessary as part of a Rails 3.2 upgrade, you can start replacing any plugins by extracting them to gems and adding them to your Gemfile. If you choose not to make them gems, you can move them into, say, <tt>lib/my_plugin/*</tt> and add an appropriate initializer in <tt>config/initializers/my_plugin.rb</tt>.

h3. Upgrading from Rails 3.0 to Rails 3.1

If your application is currently on any version of Rails older than 3.0.x, you should upgrade to Rails 3.0 before attempting an update to Rails 3.1.

The following changes are meant for upgrading your application to Rails 3.1.3, the latest 3.1.x version of Rails.

h4(#gemfile3_1). Gemfile

Make the following changes to your +Gemfile+.

<ruby>
gem 'rails', '= 3.1.3'
gem 'mysql2'

# Needed for the new asset pipeline
group :assets do
  gem 'sass-rails',   "~> 3.1.5"
  gem 'coffee-rails', "~> 3.1.1"
  gem 'uglifier',     ">= 1.0.3"
end

# jQuery is the default JavaScript library in Rails 3.1
gem 'jquery-rails'
</ruby>

h4(#config_app3_1). config/application.rb

The asset pipeline requires the following additions:

<ruby>
config.assets.enabled = true
config.assets.version = '1.0'
</ruby>

If your application is using an "/assets" route for a resource you may want change the prefix used for assets to avoid conflicts:

<ruby>
# Defaults to '/assets'
config.assets.prefix = '/asset-files'
</ruby>

h4(#config_dev3_1). config/environments/development.rb

Remove the RJS setting <tt>config.action_view.debug_rjs = true</tt>.

Add these settings if you enable the asset pipeline:

<ruby>
# Do not compress assets
config.assets.compress = false

# Expands the lines which load the assets
config.assets.debug = true
</ruby>

h4(#config_prod3_1). config/environments/production.rb

Again, most of the changes below are for the asset pipeline. You can read more about these in the "Asset Pipeline":asset_pipeline.html guide.

<ruby>
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
</ruby>

h4(#config_test3_1). config/environments/test.rb

You can help test performance with these additions to your test environment:

<ruby>
# Configure static asset server for tests with Cache-Control for performance
config.serve_static_assets = true
config.static_cache_control = "public, max-age=3600"
</ruby>

h4(#config_wp3_1). config/initializers/wrap_parameters.rb

Add this file with the following contents, if you wish to wrap parameters into a nested hash. This is on by default in new applications.

<ruby>
# Be sure to restart your server when you modify this file.
# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.

# Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters :format => [:json]
end

# Disable root element in JSON by default.
ActiveSupport.on_load(:active_record) do
  self.include_root_in_json = false
end
</ruby>
