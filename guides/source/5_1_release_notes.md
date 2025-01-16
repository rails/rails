**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 5.1 Release Notes
===============================

Highlights in Rails 5.1:

* Yarn Support
* Optional Webpack support
* jQuery no longer a default dependency
* System tests
* Encrypted secrets
* Parameterized mailers
* Direct & resolved routes
* Unification of form_for and form_tag into form_with

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the changelogs or check out the [list of
commits](https://github.com/rails/rails/commits/5-1-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 5.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 5.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 5.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-5-0-to-rails-5-1)
guide.


Major Features
--------------

### Yarn Support

[Pull Request](https://github.com/rails/rails/pull/26836)

Rails 5.1 allows managing JavaScript dependencies
from npm via Yarn. This will make it easy to use libraries like React, VueJS
or any other library from npm world. The Yarn support is integrated with
the asset pipeline so that all dependencies will work seamlessly with the
Rails 5.1 app.

### Optional Webpack support

[Pull Request](https://github.com/rails/rails/pull/27288)

Rails apps can integrate with [Webpack](https://webpack.js.org/), a JavaScript
asset bundler, more easily using the new [Webpacker](https://github.com/rails/webpacker)
gem. Use the `--webpack` flag when generating new applications to enable Webpack
integration.

This is fully compatible with the asset pipeline, which you can continue to use for
images, fonts, sounds, and other assets. You can even have some JavaScript code
managed by the asset pipeline, and other code processed via Webpack. All of this is managed
by Yarn, which is enabled by default.

### jQuery no longer a default dependency

[Pull Request](https://github.com/rails/rails/pull/27113)

jQuery was required by default in earlier versions of Rails to provide features
like `data-remote`, `data-confirm` and other parts of Rails' Unobtrusive JavaScript
offerings. It is no longer required, as the UJS has been rewritten to use plain,
vanilla JavaScript. This code now ships inside of Action View as
`rails-ujs`.

You can still use jQuery if needed, but it is no longer required by default.

### System tests

[Pull Request](https://github.com/rails/rails/pull/26703)

Rails 5.1 has baked-in support for writing Capybara tests, in the form of
System tests. You no longer need to worry about configuring Capybara and
database cleaning strategies for such tests. Rails 5.1 provides a wrapper
for running tests in Chrome with additional features such as failure
screenshots.

### Encrypted secrets

[Pull Request](https://github.com/rails/rails/pull/28038)

Rails now allows management of application secrets in a secure way,
inspired by the [sekrets](https://github.com/ahoward/sekrets) gem.

Run `bin/rails secrets:setup` to set up a new encrypted secrets file. This will
also generate a master key, which must be stored outside of the repository. The
secrets themselves can then be safely checked into the revision control system,
in an encrypted form.

Secrets will be decrypted in production, using a key stored either in the
`RAILS_MASTER_KEY` environment variable, or in a key file.

### Parameterized mailers

[Pull Request](https://github.com/rails/rails/pull/27825)

Allows specifying common parameters used for all methods in a mailer class in
order to share instance variables, headers, and other common setup.

```ruby
class InvitationsMailer < ApplicationMailer
  before_action { @inviter, @invitee = params[:inviter], params[:invitee] }
  before_action { @account = params[:inviter].account }

  def account_invitation
    mail subject: "#{@inviter.name} invited you to their Basecamp (#{@account.name})"
  end
end
```

```ruby
InvitationsMailer.with(inviter: person_a, invitee: person_b)
                 .account_invitation.deliver_later
```

### Direct & resolved routes

[Pull Request](https://github.com/rails/rails/pull/23138)

Rails 5.1 adds two new methods, `resolve` and `direct`, to the routing
DSL. The `resolve` method allows customizing polymorphic mapping of models.

```ruby
resource :basket

resolve("Basket") { [:basket] }
```

```erb
<%= form_for @basket do |form| %>
  <!-- basket form -->
<% end %>
```

This will generate the singular URL `/basket` instead of the usual `/baskets/:id`.

The `direct` method allows creation of custom URL helpers.

```ruby
direct(:homepage) { "https://rubyonrails.org" }

homepage_url # => "https://rubyonrails.org"
```

The return value of the block must be a valid argument for the `url_for`
method. So, you can pass a valid string URL, Hash, Array, an
Active Model instance, or an Active Model class.

```ruby
direct :commentable do |model|
  [ model, anchor: model.dom_id ]
end

direct :main do
  { controller: 'pages', action: 'index', subdomain: 'www' }
end
```

### Unification of form_for and form_tag into form_with

[Pull Request](https://github.com/rails/rails/pull/26976)

Before Rails 5.1, there were two interfaces for handling HTML forms:
`form_for` for model instances and `form_tag` for custom URLs.

Rails 5.1 combines both of these interfaces with `form_with`, and
can generate form tags based on URLs, scopes, or models.

Using just a URL:

```erb
<%= form_with url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="title">
</form>
```

Adding a scope prefixes the input field names:

```erb
<%= form_with scope: :post, url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>
```

Using a model infers both the URL and scope:

```erb
<%= form_with model: Post.new do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>
```

An existing model makes an update form and fills out field values:

```erb
<%= form_with model: Post.first do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts/1" method="post" data-remote="true">
  <input type="hidden" name="_method" value="patch">
  <input type="text" name="post[title]" value="<the title of the post>">
</form>
```

Incompatibilities
-----------------

The following changes may require immediate action upon upgrade.

### Transactional tests with multiple connections

Transactional tests now wrap all Active Record connections in database
transactions.

When a test spawns additional threads, and those threads obtain database
connections, those connections are now handled specially:

The threads will share a single connection, which is inside the managed
transaction. This ensures all threads see the database in the same
state, ignoring the outermost transaction. Previously, such additional
connections were unable to see the fixture rows, for example.

When a thread enters a nested transaction, it will temporarily obtain
exclusive use of the connection, to maintain isolation.

If your tests currently rely on obtaining a separate,
outside-of-transaction, connection in a spawned thread, you'll need to
switch to more explicit connection management.

If your tests spawn threads and those threads interact while also using
explicit database transactions, this change may introduce a deadlock.

The easy way to opt-out of this new behavior is to disable transactional
tests on any test cases it affects.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `config.static_cache_control`.
    ([commit](https://github.com/rails/rails/commit/c861decd44198f8d7d774ee6a74194d1ac1a5a13))

*   Remove deprecated `config.serve_static_files`.
    ([commit](https://github.com/rails/rails/commit/0129ca2eeb6d5b2ea8c6e6be38eeb770fe45f1fa))

*   Remove deprecated file `rails/rack/debugger`.
    ([commit](https://github.com/rails/rails/commit/7563bf7b46e6f04e160d664e284a33052f9804b8))

*   Remove deprecated tasks: `rails:update`, `rails:template`, `rails:template:copy`,
    `rails:update:configs` and `rails:update:bin`.
    ([commit](https://github.com/rails/rails/commit/f7782812f7e727178e4a743aa2874c078b722eef))

*   Remove deprecated `CONTROLLER` environment variable for `routes` task.
    ([commit](https://github.com/rails/rails/commit/f9ed83321ac1d1902578a0aacdfe55d3db754219))

*   Remove -j (--javascript) option from `rails new` command.
    ([Pull Request](https://github.com/rails/rails/pull/28546))

### Notable changes

*   Added a shared section to `config/secrets.yml` that will be loaded for all
    environments.
    ([commit](https://github.com/rails/rails/commit/e530534265d2c32b5c5f772e81cb9002dcf5e9cf))

*   The config file `config/secrets.yml` is now loaded in with all keys as symbols.
    ([Pull Request](https://github.com/rails/rails/pull/26929))

*   Removed jquery-rails from default stack. rails-ujs, which is shipped
    with Action View, is included as default UJS adapter.
    ([Pull Request](https://github.com/rails/rails/pull/27113))

*   Add Yarn support in new apps with a yarn binstub and package.json.
    ([Pull Request](https://github.com/rails/rails/pull/26836))

*   Add Webpack support in new apps via the `--webpack` option, which will delegate
    to the rails/webpacker gem.
    ([Pull Request](https://github.com/rails/rails/pull/27288))

*   Initialize Git repo when generating new app, if option `--skip-git` is not
    provided.
    ([Pull Request](https://github.com/rails/rails/pull/27632))

*   Add encrypted secrets in `config/secrets.yml.enc`.
    ([Pull Request](https://github.com/rails/rails/pull/28038))

*   Display railtie class name in `rails initializers`.
    ([Pull Request](https://github.com/rails/rails/pull/25257))

Action Cable
-----------

Please refer to the [Changelog][action-cable] for detailed changes.

### Notable changes

*   Added support for `channel_prefix` to Redis and evented Redis adapters
    in `cable.yml` to avoid name collisions when using the same Redis server
    with multiple applications.
    ([Pull Request](https://github.com/rails/rails/pull/27425))

*   Add `ActiveSupport::Notifications` hook for broadcasting data.
    ([Pull Request](https://github.com/rails/rails/pull/24988))

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   Removed support for non-keyword arguments in `#process`, `#get`, `#post`,
    `#patch`, `#put`, `#delete`, and `#head` for the `ActionDispatch::IntegrationTest`
    and `ActionController::TestCase` classes.
    ([Commit](https://github.com/rails/rails/commit/98b8309569a326910a723f521911e54994b112fb),
    [Commit](https://github.com/rails/rails/commit/de9542acd56f60d281465a59eac11e15ca8b3323))

*   Removed deprecated `ActionDispatch::Callbacks.to_prepare` and
    `ActionDispatch::Callbacks.to_cleanup`.
    ([Commit](https://github.com/rails/rails/commit/3f2b7d60a52ffb2ad2d4fcf889c06b631db1946b))

*   Removed deprecated methods related to controller filters.
    ([Commit](https://github.com/rails/rails/commit/d7be30e8babf5e37a891522869e7b0191b79b757))

*   Removed deprecated support to `:text` and `:nothing` in `render`.
    ([Commit](https://github.com/rails/rails/commit/79a5ea9eadb4d43b62afacedc0706cbe88c54496),
    [Commit](https://github.com/rails/rails/commit/57e1c99a280bdc1b324936a690350320a1cd8111))

*   Removed deprecated support for calling `HashWithIndifferentAccess` methods on `ActionController::Parameters`.
    ([Commit](https://github.com/rails/rails/pull/26746/commits/7093ceb480ad6a0a91b511832dad4c6a86981b93))

### Deprecations

*   Deprecated `config.action_controller.raise_on_unfiltered_parameters`.
    It doesn't have any effect in Rails 5.1.
    ([Commit](https://github.com/rails/rails/commit/c6640fb62b10db26004a998d2ece98baede509e5))

### Notable changes

*   Added the `direct` and `resolve` methods to the routing DSL.
    ([Pull Request](https://github.com/rails/rails/pull/23138))

*   Added a new `ActionDispatch::SystemTestCase` class to write system tests in
    your applications.
    ([Pull Request](https://github.com/rails/rails/pull/26703))

Action View
-------------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Removed deprecated `#original_exception` in `ActionView::Template::Error`.
    ([commit](https://github.com/rails/rails/commit/b9ba263e5aaa151808df058f5babfed016a1879f))

*   Remove the option `encode_special_chars` misnomer from `strip_tags`.
    ([Pull Request](https://github.com/rails/rails/pull/28061))

### Deprecations

*   Deprecated Erubis ERB handler in favor of Erubi.
    ([Pull Request](https://github.com/rails/rails/pull/27757))

### Notable changes

*   Raw template handler (the default template handler in Rails 5) now outputs
    HTML-safe strings.
    ([commit](https://github.com/rails/rails/commit/1de0df86695f8fa2eeae6b8b46f9b53decfa6ec8))

*   Change `datetime_field` and `datetime_field_tag` to generate `datetime-local`
    fields.
    ([Pull Request](https://github.com/rails/rails/pull/25469))

*   New Builder-style syntax for HTML tags (`tag.div`, `tag.br`, etc.)
    ([Pull Request](https://github.com/rails/rails/pull/25543))

*   Add `form_with` to unify `form_tag` and `form_for` usage.
    ([Pull Request](https://github.com/rails/rails/pull/26976))

*   Add `check_parameters` option to `current_page?`.
    ([Pull Request](https://github.com/rails/rails/pull/27549))

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Notable changes

*   Allowed setting custom content type when attachments are included
    and body is set inline.
    ([Pull Request](https://github.com/rails/rails/pull/27227))

*   Allowed passing lambdas as values to the `default` method.
    ([Commit](https://github.com/rails/rails/commit/1cec84ad2ddd843484ed40b1eb7492063ce71baf))

*   Added support for parameterized invocation of mailers to share before filters and defaults
    between different mailer actions.
    ([Commit](https://github.com/rails/rails/commit/1cec84ad2ddd843484ed40b1eb7492063ce71baf))

*   Passed the incoming arguments to the mailer action to `process.action_mailer` event under
    an `args` key.
    ([Pull Request](https://github.com/rails/rails/pull/27900))

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Removed support for passing arguments and block at the same time to
    `ActiveRecord::QueryMethods#select`.
    ([Commit](https://github.com/rails/rails/commit/4fc3366d9d99a0eb19e45ad2bf38534efbf8c8ce))

*   Removed deprecated `activerecord.errors.messages.restrict_dependent_destroy.one` and
    `activerecord.errors.messages.restrict_dependent_destroy.many` i18n scopes.
    ([Commit](https://github.com/rails/rails/commit/00e3973a311))

*   Removed deprecated force-reload argument in singular and collection association readers.
    ([Commit](https://github.com/rails/rails/commit/09cac8c67af))

*   Removed deprecated support for passing a column to `#quote`.
    ([Commit](https://github.com/rails/rails/commit/e646bad5b7c))

*   Removed deprecated `name` arguments from `#tables`.
    ([Commit](https://github.com/rails/rails/commit/d5be101dd02214468a27b6839ffe338cfe8ef5f3))

*   Removed deprecated behavior of `#tables` and `#table_exists?` to return tables and views
    to return only tables and not views.
    ([Commit](https://github.com/rails/rails/commit/5973a984c369a63720c2ac18b71012b8347479a8))

*   Removed deprecated `original_exception` argument in `ActiveRecord::StatementInvalid#initialize`
    and `ActiveRecord::StatementInvalid#original_exception`.
    ([Commit](https://github.com/rails/rails/commit/bc6c5df4699d3f6b4a61dd12328f9e0f1bd6cf46))

*   Removed deprecated support of passing a class as a value in a query.
    ([Commit](https://github.com/rails/rails/commit/b4664864c972463c7437ad983832d2582186e886))

*   Removed deprecated support to query using commas on LIMIT.
    ([Commit](https://github.com/rails/rails/commit/fc3e67964753fb5166ccbd2030d7382e1976f393))

*   Removed deprecated `conditions` parameter from `#destroy_all`.
    ([Commit](https://github.com/rails/rails/commit/d31a6d1384cd740c8518d0bf695b550d2a3a4e9b))

*   Removed deprecated `conditions` parameter from `#delete_all`.
    ([Commit](https://github.com/rails/rails/pull/27503/commits/e7381d289e4f8751dcec9553dcb4d32153bd922b))

*   Removed deprecated method `#load_schema_for` in favor of `#load_schema`.
    ([Commit](https://github.com/rails/rails/commit/419e06b56c3b0229f0c72d3e4cdf59d34d8e5545))

*   Removed deprecated `#raise_in_transactional_callbacks` configuration.
    ([Commit](https://github.com/rails/rails/commit/8029f779b8a1dd9848fee0b7967c2e0849bf6e07))

*   Removed deprecated `#use_transactional_fixtures` configuration.
    ([Commit](https://github.com/rails/rails/commit/3955218dc163f61c932ee80af525e7cd440514b3))

### Deprecations

*   Deprecated `error_on_ignored_order_or_limit` flag in favor of
    `error_on_ignored_order`.
    ([Commit](https://github.com/rails/rails/commit/451437c6f57e66cc7586ec966e530493927098c7))

*   Deprecated `sanitize_conditions` in favor of `sanitize_sql`.
    ([Pull Request](https://github.com/rails/rails/pull/25999))

*   Deprecated `supports_migrations?` on connection adapters.
    ([Pull Request](https://github.com/rails/rails/pull/28172))

*   Deprecated `Migrator.schema_migrations_table_name`, use `SchemaMigration.table_name` instead.
    ([Pull Request](https://github.com/rails/rails/pull/28351))

*   Deprecated using `#quoted_id` in quoting and type casting.
    ([Pull Request](https://github.com/rails/rails/pull/27962))

*   Deprecated passing `default` argument to `#index_name_exists?`.
    ([Pull Request](https://github.com/rails/rails/pull/26930))

### Notable changes

*   Change Default Primary Keys to BIGINT.
    ([Pull Request](https://github.com/rails/rails/pull/26266))

*   Virtual/generated column support for MySQL 5.7.5+ and MariaDB 5.2.0+.
    ([Commit](https://github.com/rails/rails/commit/65bf1c60053e727835e06392d27a2fb49665484c))

*   Added support for limits in batch processing.
    ([Commit](https://github.com/rails/rails/commit/451437c6f57e66cc7586ec966e530493927098c7))

*   Transactional tests now wrap all Active Record connections in database
    transactions.
    ([Pull Request](https://github.com/rails/rails/pull/28726))

*   Skipped comments in the output of `mysqldump` command by default.
    ([Pull Request](https://github.com/rails/rails/pull/23301))

*   Fixed `ActiveRecord::Relation#count` to use Ruby's `Enumerable#count` for counting
    records when a block is passed as argument instead of silently ignoring the
    passed block.
    ([Pull Request](https://github.com/rails/rails/pull/24203))

*   Pass `"-v ON_ERROR_STOP=1"` flag with `psql` command to not suppress SQL errors.
    ([Pull Request](https://github.com/rails/rails/pull/24773))

*   Add `ActiveRecord::Base.connection_pool.stat`.
    ([Pull Request](https://github.com/rails/rails/pull/26988))

*   Inheriting directly from `ActiveRecord::Migration` raises an error.
    Specify the Rails version for which the migration was written for.
    ([Commit](https://github.com/rails/rails/commit/249f71a22ab21c03915da5606a063d321f04d4d3))

*   An error is raised when `through` association has ambiguous reflection name.
    ([Commit](https://github.com/rails/rails/commit/0944182ad7ed70d99b078b22426cbf844edd3f61))

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

*   Removed deprecated methods in `ActiveModel::Errors`.
    ([commit](https://github.com/rails/rails/commit/9de6457ab0767ebab7f2c8bc583420fda072e2bd))

*   Removed deprecated `:tokenizer` option in the length validator.
    ([commit](https://github.com/rails/rails/commit/6a78e0ecd6122a6b1be9a95e6c4e21e10e429513))

*   Remove deprecated behavior that halts callbacks when the return value is false.
    ([commit](https://github.com/rails/rails/commit/3a25cdca3e0d29ee2040931d0cb6c275d612dffe))

### Notable changes

*   The original string assigned to a model attribute is no longer incorrectly
    frozen.
    ([Pull Request](https://github.com/rails/rails/pull/28729))

Active Job
-----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Removed deprecated support to passing the adapter class to `.queue_adapter`.
    ([commit](https://github.com/rails/rails/commit/d1fc0a5eb286600abf8505516897b96c2f1ef3f6))

*   Removed deprecated `#original_exception` in `ActiveJob::DeserializationError`.
    ([commit](https://github.com/rails/rails/commit/d861a1fcf8401a173876489d8cee1ede1cecde3b))

### Notable changes

*   Added declarative exception handling via `ActiveJob::Base.retry_on` and `ActiveJob::Base.discard_on`.
    ([Pull Request](https://github.com/rails/rails/pull/25991))

*   Yield the job instance so you have access to things like `job.arguments` on
    the custom logic after retries fail.
    ([commit](https://github.com/rails/rails/commit/a1e4c197cb12fef66530a2edfaeda75566088d1f))

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Removed the `ActiveSupport::Concurrency::Latch` class.
    ([Commit](https://github.com/rails/rails/commit/0d7bd2031b4054fbdeab0a00dd58b1b08fb7fea6))

*   Removed `halt_callback_chains_on_return_false`.
    ([Commit](https://github.com/rails/rails/commit/4e63ce53fc25c3bc15c5ebf54bab54fa847ee02a))

*   Removed deprecated behavior that halts callbacks when the return is false.
    ([Commit](https://github.com/rails/rails/commit/3a25cdca3e0d29ee2040931d0cb6c275d612dffe))

### Deprecations

*   The top level `HashWithIndifferentAccess` class has been softly deprecated
    in favor of the `ActiveSupport::HashWithIndifferentAccess` one.
    ([Pull Request](https://github.com/rails/rails/pull/28157))

*   Deprecated passing string to `:if` and `:unless` conditional options on `set_callback` and `skip_callback`.
    ([Commit](https://github.com/rails/rails/commit/0952552))

### Notable changes

*   Fixed duration parsing and traveling to make it consistent across DST changes.
    ([Commit](https://github.com/rails/rails/commit/8931916f4a1c1d8e70c06063ba63928c5c7eab1e),
    [Pull Request](https://github.com/rails/rails/pull/26597))

*   Updated Unicode to version 9.0.0.
    ([Pull Request](https://github.com/rails/rails/pull/27822))

*   Add Duration#before and #after as aliases for #ago and #since.
    ([Pull Request](https://github.com/rails/rails/pull/27721))

*   Added `Module#delegate_missing_to` to delegate method calls not
    defined for the current object to a proxy object.
    ([Pull Request](https://github.com/rails/rails/pull/23930))

*   Added `Date#all_day` which returns a range representing the whole day
    of the current date & time.
    ([Pull Request](https://github.com/rails/rails/pull/24930))

*   Introduced the `assert_changes` and `assert_no_changes` methods for tests.
    ([Pull Request](https://github.com/rails/rails/pull/25393))

*   The `travel` and `travel_to` methods now raise on nested calls.
    ([Pull Request](https://github.com/rails/rails/pull/24890))

*   Update `DateTime#change` to support usec and nsec.
    ([Pull Request](https://github.com/rails/rails/pull/28242))

Credits
-------

See the
[full list of contributors to Rails](https://contributors.rubyonrails.org/) for
the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/5-1-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/5-1-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/5-1-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/5-1-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/5-1-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/5-1-stable/activerecord/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/5-1-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/5-1-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/5-1-stable/activejob/CHANGELOG.md
