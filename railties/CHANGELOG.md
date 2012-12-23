## Rails 3.2.10 ##

## Rails 3.2.9 (Nov 12, 2012) ##

*   Update supported ruby versions error message in ruby_version_check.rb *Lihan Li*

## Rails 3.2.8 (Aug 9, 2012) ##

*   ERB scaffold generator use the `:data => { :confirm => "Text" }` syntax instead of `:confirm`.

    *Rafael Mendonça França*


## Rails 3.2.7 (Jul 26, 2012) ##

*   Since Rails 3.2, use layout false to render no layout
*   Use strict_args_position! if available from Thor


## Rails 3.2.6 (Jun 12, 2012) ##

*   No changes.


## Rails 3.2.4 (May 31, 2012) ##

*   Add hook for resource route's generator. *Santiago Pastorino*


## Rails 3.2.3 (unreleased) ##

*   No changes.


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   Documentation fixes.

*   Migration generation understands decimal{1.2} and decimal{1-2}, in
    addition to decimal{1,2}. *José Valim*


## Rails 3.2.0 (January 20, 2012) ##

*   Rails 2.3-style plugins in vendor/plugins are deprecated and will be removed in Rails 4.0. Move them out of vendor/plugins and bundle them in your Gemfile, or fold them in to your app as lib/myplugin/* and config/initializers/myplugin.rb.  *Santiago Pastorino*

*   Guides are available as a single .mobi for the Kindle and free Kindle readers apps. *Michael Pearson & Xavier Noria*

*   Allow scaffold/model/migration generators to accept a "index" and "uniq" modifiers, as in: "tracking_id:integer:uniq" in order to generate (unique) indexes. Some types also accept custom options, for instance, you can specify the precision and scale for decimals as "price:decimal{7,2}". *Dmitrii Samoilov*

*   Added `config.exceptions_app` to set the exceptions application invoked by the ShowException middleware when an exception happens. Defaults to `ActionDispatch::PublicExceptions.new(Rails.public_path)`. *José Valim*

*   Speed up development by only reloading classes if dependencies files changed. This can be turned off by setting `config.reload_classes_only_on_change` to false. *José Valim*

*   New applications get a flag `config.active_record.auto_explain_threshold_in_seconds` in the environments configuration files. With a value of 0.5 in development.rb, and commented out in production.rb. No mention in test.rb. *fxn*

*   Add DebugExceptions middleware which contains features extracted from ShowExceptions middleware *José Valim*

*   Display mounted engine's routes in `rake routes` *Piotr Sarnacki*

*   Allow to change the loading order of railties with `config.railties_order=` *Piotr Sarnacki*

    Example:
        config.railties_order = [Blog::Engine, :main_app, :all]

*   Scaffold returns 204 No Content for API requests without content. This makes scaffold work with jQuery out of the box *José Valim*

*   Update Rails::Rack::Logger middleware to apply any tags set in config.log_tags to the newly ActiveSupport::TaggedLogging Rails.logger. This makes it easy to tag log lines with debug information like subdomain and request id -- both very helpful in debugging multi-user production applications *DHH*

*   Default options to `rails new` can be set in ~/.railsrc *Guillermo Iguaran*

*   Add destroy alias to Rails engines *Guillermo Iguaran*

*   Add destroy alias for Rails command line. This allows the following: `rails d model post` *Andrey Ognevsky*

*   Attributes on scaffold and model generators default to string. This allows the following: "rails g scaffold Post title body:text author" *José Valim*

*   Remove old plugin generator (`rails generate plugin`) in favor of `rails plugin new` command *Guillermo Iguaran*

*   Remove old 'config.paths.app.controller' API in favor of 'config.paths["app/controller"]' API *Guillermo Iguaran*

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/railties/CHANGELOG.md) for previous changes.
