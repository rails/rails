Ruby on Rails 4.0 Release Notes
===============================

Highlights in Rails 4.0:

* Ruby 2.0 preferred; 1.9.3+ required
* Strong Parameters
* Turbolinks
* Russian Doll Caching

These release notes cover only the major changes. To know about various bug fixes and changes, please refer to the change logs or check out the [list of commits](https://github.com/rails/rails/commits/master) in the main Rails repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 4.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test coverage before going in. You should also first upgrade to Rails 3.2 in case you haven't and make sure your application still runs as expected before attempting an update to Rails 4.0. A list of things to watch out for when upgrading is available in the [Upgrading to Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-3-2-to-rails-4-0) guide.


Creating a Rails 4.0 application
--------------------------------

```
 You should have the 'rails' RubyGem installed
$ rails new myapp
$ cd myapp
```

### Vendoring Gems

Rails now uses a `Gemfile` in the application root to determine the gems you require for your application to start. This `Gemfile` is processed by the [Bundler](https://github.com/carlhuda/bundler) gem, which then installs all your dependencies. It can even install all the dependencies locally to your application so that it doesn't depend on the system gems.

More information: [Bundler homepage](http://gembundler.com)

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

TODO. Give a list and then talk about each of them briefly. We can point to relevant code commits or documentation from these sections.

[![Rails 4.0](images/rails4_features.png)](http://guides.rubyonrails.org/images/rails4_features.png)

Extraction of features to gems
---------------------------

In Rails 4.0, several features have been extracted into gems. You can simply add the extracted gems to your `Gemfile` to bring the functionality back.

* Hash-based & Dynamic finder methods ([GitHub](https://github.com/rails/activerecord-deprecated_finders))
* Mass assignment protection in Active Record models ([GitHub](https://github.com/rails/protected_attributes), [Pull Request](https://github.com/rails/rails/pull/7251))
* ActiveRecord::SessionStore ([GitHub](https://github.com/rails/activerecord-session_store), [Pull Request](https://github.com/rails/rails/pull/7436))
* Active Record Observers ([GitHub](https://github.com/rails/rails-observers), [Commit](https://github.com/rails/rails/commit/39e85b3b90c58449164673909a6f1893cba290b2))
* Active Resource ([GitHub](https://github.com/rails/activeresource), [Pull Request](https://github.com/rails/rails/pull/572), [Blog](http://yetimedia.tumblr.com/post/35233051627/activeresource-is-dead-long-live-activeresource))
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

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/railties/CHANGELOG.md) for detailed changes.

### Notable changes

*   New test locations `test/models`, `test/helpers`, `test/controllers`, and `test/mailers`. Corresponding rake tasks added as well. ([Pull Request](https://github.com/rails/rails/pull/7878))

* Your app's executables now live in the `bin/` dir. Run `rake rails:update:bin` to get `bin/bundle`, `bin/rails`, and `bin/rake`.

* Threadsafe on by default

* Ability to use a custom builder by passing `--builder` (or `-b`) to
  `rails new` has been removed. Consider using application templates
  instead. ([Pull Request](https://github.com/rails/rails/pull/9401))

### Deprecations

* `config.threadsafe!` is deprecated in favor of `config.eager_load` which provides a more fine grained control on what is eager loaded.

* `Rails::Plugin` has gone. Instead of adding plugins to `vendor/plugins` use gems or bundler with path or git dependencies.

Action Mailer
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/actionmailer/CHANGELOG.md) for detailed changes.

### Notable changes

### Deprecations

Active Model
------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/activemodel/CHANGELOG.md) for detailed changes.

### Notable changes

*   Add `ActiveModel::ForbiddenAttributesProtection`, a simple module to protect attributes from mass assignment when non-permitted attributes are passed.

*   Added `ActiveModel::Model`, a mixin to make Ruby objects work with
    Action Pack out of box.

### Deprecations

Active Support
--------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/activesupport/CHANGELOG.md) for detailed changes.

### Notable changes

*   Replace deprecated `memcache-client` gem with `dalli` in ActiveSupport::Cache::MemCacheStore.

*   Optimize ActiveSupport::Cache::Entry to reduce memory and processing overhead.

*   Inflections can now be defined per locale. `singularize` and `pluralize` accept locale as an extra argument.

*   `Object#try` will now return nil instead of raise a NoMethodError if the receiving object does not implement the method, but you can still get the old behavior by using the new `Object#try!`.

* `String#to_date` now raises `ArgumentError: invalid date` instead of `NoMethodError: undefined method 'div' for nil:NilClass`
  when given an invalid date. It is now the same as `Date.parse`, and it accepts more invalid dates than 3.x, such as:

  ```
  # ActiveSupport 3.x
  "asdf".to_date # => NoMethodError: undefined method `div' for nil:NilClass
  "333".to_date # => NoMethodError: undefined method `div' for nil:NilClass

  # ActiveSupport 4
  "asdf".to_date # => ArgumentError: invalid date
  "333".to_date # => Fri, 29 Nov 2013
  ```

### Deprecations

*   Deprecate `ActiveSupport::TestCase#pending` method, use `skip` from MiniTest instead.

*   `ActiveSupport::Benchmarkable#silence` has been deprecated due to its lack of thread safety. It will be removed without replacement in Rails 4.1.

*   `ActiveSupport::JSON::Variable` is deprecated. Define your own `#as_json` and `#encode_json` methods for custom JSON string literals.

*   Deprecates the compatibility method `Module#local_constant_names`, use `Module#local_constants` instead (which returns symbols).

*   `BufferedLogger` is deprecated. Use `ActiveSupport::Logger`, or the logger from Ruby standard library.

*   Deprecate `assert_present` and `assert_blank` in favor of `assert object.blank?` and `assert object.present?`

Action Pack
-----------

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/actionpack/CHANGELOG.md) for detailed changes.

### Notable changes

* Change the stylesheet of exception pages for development mode. Additionally display also the line of code and fragment that raised the exception in all exceptions pages.

### Deprecations


Active Record
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/master/activerecord/CHANGELOG.md) for detailed changes.

### Notable changes

*   Improve ways to write `change` migrations, making the old `up` & `down` methods no longer necessary.

    * The methods `drop_table` and `remove_column` are now reversible, as long as the necessary information is given.
      The method `remove_column` used to accept multiple column names; instead use `remove_columns` (which is not revertible).
      The method `change_table` is also reversible, as long as its block doesn't call `remove`, `change` or `change_default`

    * New method `reversible` makes it possible to specify code to be run when migrating up or down.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/migrations.md#using-the-reversible-method)

    * New method `revert` will revert a whole migration or the given block.
      If migrating down, the given migration / block is run normally.
      See the [Guide on Migration](https://github.com/rails/rails/blob/master/guides/source/migrations.md#reverting-previous-migrations)

*   Adds PostgreSQL array type support. Any datatype can be used to create an array column, with full migration and schema dumper support.

*   Add `Relation#load` to explicitly load the record and return `self`.

*   `Model.all` now returns an `ActiveRecord::Relation`, rather than an array of records. Use `Relation#to_a` if you really want an array. In some specific cases, this may cause breakage when upgrading.

*   Added `ActiveRecord::Migration.check_pending!` that raises an error if migrations are pending.

*   Added custom coders support for `ActiveRecord::Store`. Now you can set your custom coder like this:

        store :settings, accessors: [ :color, :homepage ], coder: JSON

*   `mysql` and `mysql2` connections will set `SQL_MODE=STRICT_ALL_TABLES` by default to avoid silent data loss. This can be disabled by specifying `strict: false` in your `database.yml`.

*   Remove IdentityMap.

*   Remove automatic execution of EXPLAIN queries. The option `active_record.auto_explain_threshold_in_seconds` is no longer used and should be removed.

*   Adds `ActiveRecord::NullRelation` and `ActiveRecord::Relation#none` implementing the null object pattern for the Relation class.

*   Added `create_join_table` migration helper to create HABTM join tables.

*   Allows PostgreSQL hstore records to be created.

### Deprecations

*   Deprecated the old-style hash based finder API. This means that methods which previously accepted "finder options" no longer do.

*   All dynamic methods except for `find_by_...` and `find_by_...!` are deprecated. Here's
    how you can rewrite the code:

      * `find_all_by_...` can be rewritten using `where(...)`.
      * `find_last_by_...` can be rewritten using `where(...).last`.
      * `scoped_by_...` can be rewritten using `where(...)`.
      * `find_or_initialize_by_...` can be rewritten using `where(...).first_or_initialize`.
      * `find_or_create_by_...` can be rewritten using `find_or_create_by(...)` or `where(...).first_or_create`.
      * `find_or_create_by_...!` can be rewritten using `find_or_create_by!(...)` or `where(...).first_or_create!`.

Credits
-------

See the [full list of contributors to Rails](http://contributors.rubyonrails.org/) for the many people who spent many hours making Rails, the stable and robust framework it is. Kudos to all of them.
