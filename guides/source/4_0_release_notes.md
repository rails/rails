**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 4.0 Release Notes
===============================

Highlights in Rails 4.0:

* Ruby 2.0 preferred; 1.9.3+ required
* Strong Parameters
* Turbolinks
* Russian Doll Caching

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/4-0-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 4.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test coverage before going in. You should also first upgrade to Rails 3.2 in case you haven't and make sure your application still runs as expected before attempting an update to Rails 4.0. A list of things to watch out for when upgrading is available in the [Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-3-2-to-rails-4-0) guide.


Creating a Rails 4.0 application
--------------------------------

```
 You should have the 'rails' RubyGem installed
$ rails new myapp
$ cd myapp
```

### Vendoring Gems

Rails now uses a `Gemfile` in the application root to determine the gems you require for your application to start. This `Gemfile` is processed by the [Bundler](https://github.com/carlhuda/bundler) gem, which then installs all your dependencies. It can even install all the dependencies locally to your application so that it doesn't depend on the system gems.

More information: [Bundler homepage](https://bundler.io)

### Living on the Edge

`Bundler` and `Gemfile` makes freezing your Rails application easy as pie with the new dedicated `bundle` command. If you want to bundle straight from the Git repository, you can pass the `--edge` flag:

```
$ rails new myapp --edge
```

If you have a local checkout of the Rails repository and want to generate an application using that, you can pass the `--dev` flag:

```
$ ruby /path/to/rails/railties/bin/rails new myapp --dev
```

Major Features
--------------

[![Rails 4.0](images/4_0_release_notes/rails4_features.png)](https://guides.rubyonrails.org/images/4_0_release_notes/rails4_features.png)

### Upgrade

* **Ruby 1.9.3** ([commit](https://github.com/rails/rails/commit/a0380e808d3dbd2462df17f5d3b7fcd8bd812496)) - Ruby 2.0 preferred; 1.9.3+ required
* **[New deprecation policy](https://www.youtube.com/watch?v=z6YgD6tVPQs)** - Deprecated features are warnings in Rails 4.0 and will be removed in Rails 4.1.
* **ActionPack page and action caching** ([commit](https://github.com/rails/rails/commit/b0a7068564f0c95e7ef28fc39d0335ed17d93e90)) - Page and action caching are extracted to a separate gem. Page and action caching requires too much manual intervention (manually expiring caches when the underlying model objects are updated). Instead, use Russian doll caching.
* **ActiveRecord observers** ([commit](https://github.com/rails/rails/commit/ccecab3ba950a288b61a516bf9b6962e384aae0b)) - Observers are extracted to a separate gem. Observers are only needed for page and action caching, and can lead to spaghetti code.
* **ActiveRecord session store** ([commit](https://github.com/rails/rails/commit/0ffe19056c8e8b2f9ae9d487b896cad2ce9387ad)) - The ActiveRecord session store is extracted to a separate gem. Storing sessions in SQL is costly. Instead, use cookie sessions, memcache sessions, or a custom session store.
* **ActiveModel mass assignment protection** ([commit](https://github.com/rails/rails/commit/f8c9a4d3e88181cee644f91e1342bfe896ca64c6)) - Rails 3 mass assignment protection is deprecated. Instead, use strong parameters.
* **ActiveResource** ([commit](https://github.com/rails/rails/commit/f1637bf2bb00490203503fbd943b73406e043d1d)) - ActiveResource is extracted to a separate gem. ActiveResource was not widely used.
* **vendor/plugins removed** ([commit](https://github.com/rails/rails/commit/853de2bd9ac572735fa6cf59fcf827e485a231c3)) - Use a `Gemfile` to manage installed gems.

### ActionPack

* **Strong parameters** ([commit](https://github.com/rails/rails/commit/a8f6d5c6450a7fe058348a7f10a908352bb6c7fc)) - Only allow permitted parameters to update model objects (`params.permit(:title, :text)`).
* **Routing concerns** ([commit](https://github.com/rails/rails/commit/0dd24728a088fcb4ae616bb5d62734aca5276b1b)) - In the routing DSL, factor out common subroutes (`comments` from `/posts/1/comments` and `/videos/1/comments`).
* **ActionController::Live** ([commit](https://github.com/rails/rails/commit/af0a9f9eefaee3a8120cfd8d05cbc431af376da3)) - Stream JSON with `response.stream`.
* **Declarative ETags** ([commit](https://github.com/rails/rails/commit/ed5c938fa36995f06d4917d9543ba78ed506bb8d)) - Add controller-level etag additions that will be part of the action etag computation.
* **[Russian doll caching](http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works)** ([commit](https://github.com/rails/rails/commit/4154bf012d2bec2aae79e4a49aa94a70d3e91d49)) - Cache nested fragments of views. Each fragment expires based on a set of dependencies (a cache key). The cache key is usually a template version number and a model object.
* **Turbolinks** ([commit](https://github.com/rails/rails/commit/e35d8b18d0649c0ecc58f6b73df6b3c8d0c6bb74)) - Serve only one initial HTML page. When the user navigates to another page, use pushState to update the URL and use AJAX to update the title and body.
* **Decouple ActionView from ActionController** ([commit](https://github.com/rails/rails/commit/78b0934dd1bb84e8f093fb8ef95ca99b297b51cd)) - ActionView was decoupled from ActionPack and will be moved to a separated gem in Rails 4.1.
* **Do not depend on ActiveModel** ([commit](https://github.com/rails/rails/commit/166dbaa7526a96fdf046f093f25b0a134b277a68)) - ActionPack no longer depends on ActiveModel.

### General

 * **ActiveModel::Model** ([commit](https://github.com/rails/rails/commit/3b822e91d1a6c4eab0064989bbd07aae3a6d0d08)) - `ActiveModel::Model`, a mixin to make normal Ruby objects to work with ActionPack out of box (ex. for `form_for`)
 * **New scope API** ([commit](https://github.com/rails/rails/commit/50cbc03d18c5984347965a94027879623fc44cce)) - Scopes must always use callables.
 * **Schema cache dump** ([commit](https://github.com/rails/rails/commit/5ca4fc95818047108e69e22d200e7a4a22969477)) - To improve Rails boot time, instead of loading the schema directly from the database, load the schema from a dump file.
 * **Support for specifying transaction isolation level** ([commit](https://github.com/rails/rails/commit/392eeecc11a291e406db927a18b75f41b2658253)) - Choose whether repeatable reads or improved performance (less locking) is more important.
 * **Dalli** ([commit](https://github.com/rails/rails/commit/82663306f428a5bbc90c511458432afb26d2f238)) - Use Dalli memcache client for the memcache store.
 * **Notifications start &amp; finish** ([commit](https://github.com/rails/rails/commit/f08f8750a512f741acb004d0cebe210c5f949f28)) - Active Support instrumentation reports start and finish notifications to subscribers.
 * **Thread safe by default** ([commit](https://github.com/rails/rails/commit/5d416b907864d99af55ebaa400fff217e17570cd)) - Rails can run in threaded app servers without additional configuration.

NOTE: Check that the gems you are using are threadsafe.

 * **PATCH verb** ([commit](https://github.com/rails/rails/commit/eed9f2539e3ab5a68e798802f464b8e4e95e619e)) - In Rails, PATCH replaces PUT. PATCH is used for partial updates of resources.

### Security

* **match do not catch all** ([commit](https://github.com/rails/rails/commit/90d2802b71a6e89aedfe40564a37bd35f777e541)) - In the routing DSL, match requires the HTTP verb or verbs to be specified.
* **html entities escaped by default** ([commit](https://github.com/rails/rails/commit/5f189f41258b83d49012ec5a0678d827327e7543)) - Strings rendered in erb are escaped unless wrapped with `raw` or `html_safe` is called.
* **New security headers** ([commit](https://github.com/rails/rails/commit/6794e92b204572d75a07bd6413bdae6ae22d5a82)) - Rails sends the following headers with every HTTP request: `X-Frame-Options` (prevents clickjacking by forbidding the browser from embedding the page in a frame), `X-XSS-Protection` (asks the browser to halt script injection) and `X-Content-Type-Options` (prevents the browser from opening a jpeg as an exe).

Extraction of features to gems
---------------------------

In Rails 4.0, several features have been extracted into gems. You can simply add the extracted gems to your `Gemfile` to bring the functionality back.

* Hash-based & Dynamic finder methods ([GitHub](https://github.com/rails/activerecord-deprecated_finders))
* Mass assignment protection in Active Record models ([GitHub](https://github.com/rails/protected_attributes), [Pull Request](https://github.com/rails/rails/pull/7251))
* ActiveRecord::SessionStore ([GitHub](https://github.com/rails/activerecord-session_store), [Pull Request](https://github.com/rails/rails/pull/7436))
* Active Record Observers ([GitHub](https://github.com/rails/rails-observers), [Commit](https://github.com/rails/rails/commit/39e85b3b90c58449164673909a6f1893cba290b2))
* Active Resource ([GitHub](https://github.com/rails/activeresource), [Pull Request](https://github.com/rails/rails/pull/572), [Blog](http://yetimedia-blog-blog.tumblr.com/post/35233051627/activeresource-is-dead-long-live-activeresource))
* Action Caching ([GitHub](https://github.com/rails/actionpack-action_caching), [Pull Request](https://github.com/rails/rails/pull/7833))
* Page Caching ([GitHub](https://github.com/rails/actionpack-page_caching), [Pull Request](https://github.com/rails/rails/pull/7833))
* Sprockets ([GitHub](https://github.com/rails/sprockets-rails))
* Performance tests ([GitHub](https://github.com/rails/rails-perftest), [Pull Request](https://github.com/rails/rails/pull/8876))

Documentation
-------------

* Guides are rewritten in GitHub Flavored Markdown.

* Guides have a responsive design.

Railties
--------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/railties/CHANGELOG.md) for detailed changes.

### Notable changes

* New test locations `test/models`, `test/helpers`, `test/controllers`, and `test/mailers`. Corresponding rake tasks added as well. ([Pull Request](https://github.com/rails/rails/pull/7878))

* Your app's executables now live in the `bin/` directory. Run `rake rails:update:bin` to get `bin/bundle`, `bin/rails`, and `bin/rake`.

* Threadsafe on by default

* Ability to use a custom builder by passing `--builder` (or `-b`) to
  `rails new` has been removed. Consider using application templates
  instead. ([Pull Request](https://github.com/rails/rails/pull/9401))

### Deprecations

* `config.threadsafe!` is deprecated in favor of `config.eager_load` which provides a more fine grained control on what is eager loaded.

* `Rails::Plugin` has gone. Instead of adding plugins to `vendor/plugins` use gems or bundler with path or git dependencies.

Action Mailer
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/actionmailer/CHANGELOG.md) for detailed changes.

### Notable changes

### Deprecations

Active Model
------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for detailed changes.

### Notable changes

* Add `ActiveModel::ForbiddenAttributesProtection`, a simple module to protect attributes from mass assignment when non-permitted attributes are passed.

* Added `ActiveModel::Model`, a mixin to make Ruby objects work with Action Pack out of box.

### Deprecations

Active Support
--------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/activesupport/CHANGELOG.md) for detailed changes.

### Notable changes

* Replace deprecated `memcache-client` gem with `dalli` in `ActiveSupport::Cache::MemCacheStore`.

* Optimize `ActiveSupport::Cache::Entry` to reduce memory and processing overhead.

* Inflections can now be defined per locale. `singularize` and `pluralize` accept locale as an extra argument.

* `Object#try` will now return nil instead of raise a NoMethodError if the receiving object does not implement the method, but you can still get the old behavior by using the new `Object#try!`.

* `String#to_date` now raises `ArgumentError: invalid date` instead of `NoMethodError: undefined method 'div' for nil:NilClass`
  when given an invalid date. It is now the same as `Date.parse`, and it accepts more invalid dates than 3.x, such as:

  ```ruby
  # ActiveSupport 3.x
  "asdf".to_date # => NoMethodError: undefined method `div' for nil:NilClass
  "333".to_date # => NoMethodError: undefined method `div' for nil:NilClass

  # ActiveSupport 4
  "asdf".to_date # => ArgumentError: invalid date
  "333".to_date # => Fri, 29 Nov 2013
  ```

### Deprecations

* Deprecate `ActiveSupport::TestCase#pending` method, use `skip` from MiniTest instead.

* `ActiveSupport::Benchmarkable#silence` has been deprecated due to its lack of thread safety. It will be removed without replacement in Rails 4.1.

* `ActiveSupport::JSON::Variable` is deprecated. Define your own `#as_json` and `#encode_json` methods for custom JSON string literals.

* Deprecates the compatibility method `Module#local_constant_names`, use `Module#local_constants` instead (which returns symbols).

* `BufferedLogger` is deprecated. Use `ActiveSupport::Logger`, or the logger from Ruby standard library.

* Deprecate `assert_present` and `assert_blank` in favor of `assert object.blank?` and `assert object.present?`

Action Pack
-----------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for detailed changes.

### Notable changes

* Change the stylesheet of exception pages for development mode. Additionally display also the line of code and fragment that raised the exception in all exceptions pages.

### Deprecations


Active Record
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/4-0-stable/activerecord/CHANGELOG.md) for detailed changes.

### Notable changes

* Improve ways to write `change` migrations, making the old `up` & `down` methods no longer necessary.

    * The methods `drop_table` and `remove_column` are now reversible, as long as the necessary information is given.
      The method `remove_column` used to accept multiple column names; instead use `remove_columns` (which is not revertible).
      The method `change_table` is also reversible, as long as its block doesn't call `remove`, `change` or `change_default`

    * New method `reversible` makes it possible to specify code to be run when migrating up or down.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/active_record_migrations.md#using-reversible)

    * New method `revert` will revert a whole migration or the given block.
      If migrating down, the given migration / block is run normally.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/active_record_migrations.md#reverting-previous-migrations)

* Adds PostgreSQL array type support. Any datatype can be used to create an array column, with full migration and schema dumper support.

* Add `Relation#load` to explicitly load the record and return `self`.

* `Model.all` now returns an `ActiveRecord::Relation`, rather than an array of records. Use `Relation#to_a` if you really want an array. In some specific cases, this may cause breakage when upgrading.

* Added `ActiveRecord::Migration.check_pending!` that raises an error if migrations are pending.

* Added custom coders support for `ActiveRecord::Store`. Now you can set your custom coder like this:

        store :settings, accessors: [ :color, :homepage ], coder: JSON

* `mysql` and `mysql2` connections will set `SQL_MODE=STRICT_ALL_TABLES` by default to avoid silent data loss. This can be disabled by specifying `strict: false` in your `database.yml`.

* Remove IdentityMap.

* Remove automatic execution of EXPLAIN queries. The option `active_record.auto_explain_threshold_in_seconds` is no longer used and should be removed.

* Adds `ActiveRecord::NullRelation` and `ActiveRecord::Relation#none` implementing the null object pattern for the Relation class.

* Added `create_join_table` migration helper to create HABTM join tables.

* Allows PostgreSQL hstore records to be created.

### Deprecations

* Deprecated the old-style hash based finder API. This means that methods which previously accepted "finder options" no longer do.

* All dynamic methods except for `find_by_...` and `find_by_...!` are deprecated. Here's
  how you can rewrite the code:

      * `find_all_by_...` can be rewritten using `where(...)`.
      * `find_last_by_...` can be rewritten using `where(...).last`.
      * `scoped_by_...` can be rewritten using `where(...)`.
      * `find_or_initialize_by_...` can be rewritten using `find_or_initialize_by(...)`.
      * `find_or_create_by_...` can be rewritten using `find_or_create_by(...)`.
      * `find_or_create_by_...!` can be rewritten using `find_or_create_by!(...)`.

Credits
-------

See the [full list of contributors to Rails](http://contributors.rubyonrails.org/) for the many people who spent many hours making Rails, the stable and robust framework it is. Kudos to all of them.
