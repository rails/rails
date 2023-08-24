**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 7.1 Release Notes
===============================

Highlights in Rails 7.1:

--------------------------------------------------------------------------------

Upgrading to Rails 7.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 7.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 7.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-7-0-to-rails-7-1)
guide.

Major Features
--------------

### Generate Dockerfiles for new Rails applications

[Default Docker support](https://github.com/rails/rails/pull/46762) to new rails applications.
When generating a new application, Rails will now include Docker-related files in the application.

These files serve as a foundational setup for deploying your Rails application in a
production environment using Docker. It's important to note that these files are not
meant for development purposes.

Here's a quick example of how to build and run your Rails app using these Docker files:

```bash
docker build -t app .
docker volume create app-storage
docker run --rm -it -v app-storage:/rails/storage -p 3000:3000 --env RAILS_MASTER_KEY=<your-config-master-key> app
```

You can also start a console or runner from this Docker image:

```bash
docker run --rm -it -v app-storage:/rails/storage --env RAILS_MASTER_KEY=<your-config-master-key> app console
```

For those looking to create a multi-platform image (e.g., Apple Silicon for AMD or Intel deployment),
and push it to Docker Hub, follow these steps:

```bash
docker login -u <your-user>
docker buildx create --use
docker buildx build --push --platform=linux/amd64,linux/arm64 -t <your-user/image-name> .
```

This enhancement simplifies the deployment process, providing a convenient starting point for
getting your Rails application up and running in a production environment.

### Add `ActiveRecord::Base.normalizes`

TODO: Add description https://github.com/rails/rails/pull/43945

### Add `ActiveRecord::Base.generates_token_for`

TODO: Add description https://github.com/rails/rails/pull/44189

### Add `perform_all_later`` to enqueue multiple jobs at once

TODO: Add description https://github.com/rails/rails/pull/46603

### Composite primary keys

TODO: Add description

### Introduce adapter for Trilogy

TODO: Add description https://github.com/rails/rails/pull/47880

### Add `ActiveSupport::MessagePack`

TODO: Add description https://github.com/rails/rails/pull/47770

### Introduce `config.autoload_lib`

TODO: Add description https://github.com/rails/rails/pull/48572

### Active Record API for general async queries

TODO: Add description https://github.com/rails/rails/pull/44446

### Allow templates to set strict `locals`.

TODO: https://github.com/rails/rails/pull/45602

### Add Rails.application.deprecators

TODO: https://github.com/rails/rails/pull/46049

### Support pattern matching for JSON `response.parsed_body`

When `ActionDispatch::IntegrationTest` tests blocks invoke
`response.parsed_body` for JSON responses, their payloads will be available with
indifferent access. This enables integration with [Ruby's Pattern
Matching][pattern-matching], and built-in [Minitest support for pattern
matching][minitest-pattern-matching]:

```ruby
get "/posts.json"

response.content_type         # => "application/json; charset=utf-8"
response.parsed_body.class    # => Array
response.parsed_body          # => [{"id"=>42, "title"=>"Title"},...

assert_pattern { response.parsed_body => [{ id: 42 }] }

get "/posts/42.json"

response.content_type         # => "application/json; charset=utf-8"
response.parsed_body.class    # => ActiveSupport::HashWithIndifferentAccess
response.parsed_body          # => {"id"=>42, "title"=>"Title"}

assert_pattern { response.parsed_body => [{ title: /title/i }] }
```

[pattern-matching]: https://docs.ruby-lang.org/en/master/syntax/pattern_matching_rdoc.html
[minitest-pattern-matching]: https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-assert_pattern

### Extend `response.parsed_body` to parse HTML with Nokogiri

[Extend the `ActionDispatch::Testing` module][#47144] to support parsing the
value of an HTML `response.body` into a `Nokogiri::HTML5::Document` instance:

```ruby
get "/posts"

response.content_type         # => "text/html; charset=utf-8"
response.parsed_body.class    # => Nokogiri::HTML5::Document
response.parsed_body.to_html  # => "<!DOCTYPE html>\n<html>\n..."
```

Newly added [Nokogiri support for pattern matching][nokogiri-pattern-matching],
along with built-in [Minitest support for pattern
matching][minitest-pattern-matching] presents opportunities to make test
assertions about the structure and content of the HTML response:

```ruby
get "/posts"

html = response.parsed_body # => <html>
                            #      <head></head>
                            #        <body>
                            #          <main><h1>Some main content</h1></main>
                            #        </body>
                            #     </html>

assert_pattern { html.at("main") => { content: "Some main content" } }
assert_pattern { html.at("main") => { content: /content/ } }
assert_pattern { html.at("main") => { children: [{ name: "h1", content: /content/ }] } }
```

[#47144]: https://github.com/rails/rails/pull/47144
[nokogiri-pattern-matching]: https://nokogiri.org/rdoc/Nokogiri/XML/Attr.html#method-i-deconstruct_keys
[minitest-pattern-matching]: https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-assert_pattern

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `bin/rails secrets:setup` command.

### Deprecations

*   Deprecated usage of `Rails.application.secrets`.

*   Deprecated `secrets:show` and `secrets:edit` commands in favor of `credentials`.

### Notable changes

*   Add `sandbox_by_default` option to start rails console in sandbox mode by default.

*   Add new syntax for support filtering tests by line ranges.

*   Add `DATABASE` option that enables the specification of the target database when executing the
    `rails railties:install:migrations` command to copy migrations.

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

*   Remove deprecated behavior on `Request#content_type`

*   Remove deprecated ability to assign a single value to `config.action_dispatch.trusted_proxies`.

*   Remove deprecated `poltergeist` and `webkit` (capybara-webkit) driver registration for system testing.

### Deprecations

*   Deprecate `config.action_dispatch.return_only_request_media_type_on_content_type`.

*   Deprecate `AbstractController::Helpers::MissingHelperError`

*   Deprecate `ActionDispatch::IllegalStateError`.

### Notable changes

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated constant `ActionView::Path`.

*   Remove deprecated support to passing instance variables as locals to partials.

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

*   Remove support for `ActiveRecord.legacy_connection_handling`.

*   Remove deprecated `ActiveRecord::Base` config accessors

* Remove support for `:include_replicas` on `configs_for`. Use `:include_hidden` instead.

*   Remove deprecated `config.active_record.partial_writes`.

*   Remove deprecated `Tasks::DatabaseTasks.schema_file_type`.

### Deprecations

### Notable changes

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

*   Remove deprecated invalid default content types in Active Storage configurations.

*   Remove deprecated `ActiveStorage::Current#host` and `ActiveStorage::Current#host=` methods.

*   Remove deprecated behavior when assigning to a collection of attachments. Instead of appending to the collection,
    the collection is now replaced.

*   Remove deprecated `purge` and `purge_later` methods from the attachments association.

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

*   Remove deprecated override of `Enumerable#sum`.

*   Remove deprecated `ActiveSupport::PerThreadRegistry`.

*   Remove deprecated option to passing a format to `#to_s` in `Array`, `Range`, `Date`, `DateTime`, `Time`,
    `BigDecimal`, `Float` and, `Integer`.

*   Remove deprecated override of `ActiveSupport::TimeWithZone.name`.

*   Remove deprecated `active_support/core_ext/uri` file.

*   Remove deprecated `active_support/core_ext/range/include_time_with_zone` file.

*   Remove implicit conversion of objects into `String` by `ActiveSupport::SafeBuffer`.

*   Remove deprecated support to generate incorrect RFC 4122 UUIDs when providing a namespace ID that is not one of the
    constants defined on `Digest::UUID`.

### Deprecations

*   Deprecate `config.active_support.disable_to_s_conversion`.

*   Deprecate `config.active_support.remove_deprecated_time_with_zone_name`.

*   Deprecate `config.active_support.use_rfc4122_namespaced_uuids`.

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

### Deprecations

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
