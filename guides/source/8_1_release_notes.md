**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 8.1 Release Notes
===============================

Highlights in Rails 8.1:

* Active Job Continuations.
* Structured Event Reporting.
* Local CI.
* Markdown Rendering.
* Command-line Credentials Fetching.
* Deprecated Associations.
* Registry-Free Kamal Deployments

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the changelogs or check out the [list of
commits](https://github.com/rails/rails/commits/8-1-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 8.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 8.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 8.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-8-0-to-rails-8-1)
guide.

Major Features
--------------

### Active Job Continuations

Long-running jobs can now be broken into discrete steps that allow execution to
continue from the last completed step rather than the beginning after a restart.
This is especially helpful when doing deploys with Kamal, which will only give
job-running containers thirty seconds to shut down by default.

Example:

```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(import_id)
    @import = Import.find(import_id)

    # block format
    step :initialize do
      @import.initialize
    end

    # step with cursor, the cursor is saved when the job is interrupted
    step :process do |step|
      @import.records.find_each(start: step.cursor) do |record|
        record.process
        step.advance! from: record.id
      end
    end

    # method format
    step :finalize
  end

  private
    def finalize
      @import.finalize
    end
end
```

### Structured Event Reporting

The default logger in Rails is great for human consumption, but less ideal for
post-processing. The new Event Reporter provides a unified interface for
producing structured events in Rails applications:

```ruby
Rails.event.notify("user.signup", user_id: 123, email: "user@example.com")
```

It supports adding tags to events:

```ruby
Rails.event.tagged("graphql") do
  # Event includes tags: { graphql: true }
  Rails.event.notify("user.signup", user_id: 123, email: "user@example.com")
end
```

As well as context:

```ruby
# All events will contain context: {request_id: "abc123", shop_id: 456}
Rails.event.set_context(request_id: "abc123", shop_id: 456)
```

Events are emitted to subscribers. Applications register subscribers to
control how events are serialized and emitted. Subscribers must implement
an `#emit` method, which receives the event hash:

```ruby
class LogSubscriber
  def emit(event)
    payload = event[:payload].map { |key, value| "#{key}=#{value}" }.join(" ")
    source_location = event[:source_location]
    log = "[#{event[:name]}] #{payload} at #{source_location[:filepath]}:#{source_location[:lineno]}"
    Rails.logger.info(log)
  end
end
```

### Local CI

Developer machines have gotten incredibly quick with loads of cores, which make
them great local runners of even relatively large test suites.

This makes getting rid of a cloud-setup for all of CI not just feasible but
desirable for many small-to-mid-sized applications, and Rails has therefore
added a default CI declaration DSL, which is defined in `config/ci.rb` and run
by `bin/ci`. It looks like this:

```ruby
CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
```

The optional integration with gh ensures that PRs must be signed off by a
passing CI run in order to be eligible to be merged.

### Markdown Rendering

Markdown has become the lingua franca of AI, and Rails has embraced this
adoption by making it easier to respond to markdown requests and render them
directly:

```ruby
class Page
  def to_markdown
    body
  end
end

class PagesController < ActionController::Base
  def show
    @page = Page.find(params[:id])

    respond_to do |format|
      format.html
      format.md { render markdown: @page }
    end
  end
end
```

### Command-line Credentials Fetching

Kamal can now easily grab its secrets from the encrypted Rails credentials store
for deploys. This makes it a low-fi alternative to external secret stores that
only needs the master key available to work:

```bash
# .kamal/secrets
KAMAL_REGISTRY_PASSWORD=$(rails credentials:fetch kamal.registry_password)
```

### Deprecated Associations

Active Record associations can now be marked as being deprecated:

```ruby
class Author < ApplicationRecord
  has_many :posts, deprecated: true
end
```

With that, usage of the `posts` association will be reported. This includes
explicit API calls like

```ruby
author.posts
author.posts = ...
```

and others, as well as indirect usage like

```ruby
author.preload(:posts)
```

usage via nested attributes, and more.

Three reporting modes are supported (`:warn`, `:raise`, and `:notify`), and
backtraces can be enabled or disabled, though you always get the location of the
reported usage regardless. Defaults are `:warn` mode and disabled backtraces.

### Registry-Free Kamal Deployments

Kamal no longer needs a remote registry, like Docker Hub or GHCR, to do basic deploys. By default, Kamal 2.8 will now use a local registry for simple deploys. For large-scale deploys, you'll still want to use a remote registry, but this makes it easier to get started and see your first Hello World deployment in the wild.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `rails/console/methods.rb` file.

*   Remove deprecated `bin/rake stats` command.

*   Remove deprecated `STATS_DIRECTORIES`.

### Deprecations

### Notable changes

Action Cable
------------

Please refer to the [Changelog][action-cable] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   Remove deprecated support to skipping over leading brackets in parameter names in the parameter parser.

    Before:

    ```ruby
    ActionDispatch::ParamBuilder.from_query_string("[foo]=bar") # => { "foo" => "bar" }
    ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz") # => { "foo" => { "bar" => "baz" } }
    ```

    After:

    ```ruby
    ActionDispatch::ParamBuilder.from_query_string("[foo]=bar") # => { "[foo]" => "bar" }
    ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz") # => { "[foo]" => { "bar" => "baz" } }
    ```

*   Remove deprecated support for using semicolons as a query string separator.

    Before:

    ```ruby
    ActionDispatch::QueryParser.each_pair("foo=bar;baz=quux").to_a
    # => [["foo", "bar"], ["baz", "quux"]]
    ```

    After:

    ```ruby
    ActionDispatch::QueryParser.each_pair("foo=bar;baz=quux").to_a
    # => [["foo", "bar;baz=quux"]]
    ```

*   Remove deprecated support to a route to multiple paths.

### Deprecations

*   Deprecate `Rails.application.config.action_dispatch.ignore_leading_brackets`.

### Notable changes

*   Redirects are now verbose in development for new Rails apps. To enable it in an existing app, add `config.action_dispatch.verbose_redirect_logs = true` to your `config/development.rb` file.

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Remove deprecated `:retries` option for the SQLite3 adapter.

*   Remove deprecated `:unsigned_float` and `:unsigned_decimal` column methods for MySQL.

### Deprecations

*   Deprecate using an [order dependent finder
    method](https://github.com/rails/rails/pull/54608) (e.g. `#first`) without
    an `order`.

*   Deprecate `ActiveRecord::Base.signed_id_verifier_secret` in favor of
    `Rails.application.message_verifiers` (or `Model.signed_id_verifier` if the
    secret is specific to a model).

*   Deprecate using `insert_all`/`upsert_all` with unpersisted records in
    associations.

*   Deprecate usage of `WITH`, `WITH RECURSIVE` and `DISTINCT` with
    `update_all`.

### Notable changes

*   The table columns inside `schema.rb` are [now sorted alphabetically.](https://github.com/rails/rails/pull/53281)

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

*   Remove deprecated `:azure` storage service.

### Deprecations

### Notable changes

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Remove deprecated passing a Time object to `Time#since`.

*   Remove deprecated `Benchmark.ms` method. It is now defined in the `benchmark` gem.

*   Remove deprecated addition for `Time` instances with `ActiveSupport::TimeWithZone`.

*   Remove deprecated support for `to_time` to preserve the system local time. It will now always preserve the receiver
    timezone.

### Deprecations

*   Deprecate `config.active_support.to_time_preserves_timezone`.

*   Deprecate `String#mb_chars` and `ActiveSupport::Multibyte::Chars`.

*   Deprecate `ActiveSupport::Configurable`.

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Remove support to set `ActiveJob::Base.enqueue_after_transaction_commit` to `:never`, `:always` and `:default`.

*   Remove deprecated `Rails.application.config.active_job.enqueue_after_transaction_commit`.

*   Remove deprecated internal `SuckerPunch` adapter in favor of the adapter included with the `sucker_punch` gem.

### Deprecations

*   Custom Active Job serializers must have a public `#klass` method.

*   Deprecate built-in `sidekiq` adapter (now provided by `sidekiq` gem).

### Notable changes

Action Text
----------

Please refer to the [Changelog][action-text] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Mailbox
----------

Please refer to the [Changelog][action-mailbox] for detailed changes.

### Removals

### Deprecations

### Notable changes

Ruby on Rails Guides
--------------------

Please refer to the [Changelog][guides] for detailed changes.

### Notable changes

Credits
-------

See the
[full list of contributors to Rails](https://contributors.rubyonrails.org/)
for the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/main/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/main/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/main/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/main/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/main/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/main/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/main/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/main/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/main/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/main/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/main/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/main/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/main/guides/CHANGELOG.md
