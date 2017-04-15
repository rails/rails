**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

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
fixes and changes, please refer to the change logs or check out the [list of
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

Rails 5.1 will allow managing JavaScript dependencies
from NPM via Yarn. This will make it easy to use libraries like React, VueJS
or any other library from NPM world. The Yarn support is integrated with
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

You can still use the jQuery version if needed, but it is no longer required by default.

### System tests

[Pull Request](https://github.com/rails/rails/pull/26703)

Rails 5.1 has baked-in support for writing Capybara tests, in the form of
System tests. You need no longer worry about configuring Capybara and
database cleaning strategies for such tests. Rails 5.1 provides a wrapper
for running tests in Chrome with additional features such as failure
screenshots.

### Encrypted secrets

[Pull Request](https://github.com/rails/rails/pull/28038)

Rails will now allow management of application secrets in a secure way,
building on top of the [sekrets](https://github.com/ahoward/sekrets) gem.

Run `bin/rails secrets:setup` to setup a new encrypted secrets file. This will
also generate a master key, which must be stored outside of the repository. The
secrets themselves can then be safely checked into the revision control system,
in an encrypted form.

Secrets will be decrypted in production, using a key stored either in the
`RAILS_MASTER_KEY` environment variable, or in a key file.

### Parameterized mailers

[Pull Request](https://github.com/rails/rails/pull/27825)

Allows specifying common params used for all methods in a mailer class
to share instance variables, headers and other common setup.

``` ruby
class InvitationsMailer < ApplicationMailer

  before_action { @inviter, @invitee = params[:inviter], params[:invitee] }
  before_action { @account = params[:inviter].account }

  def account_invitation
    mail subject: "#{@inviter.name} invited you to their Basecamp (#{@account.name})"
  end

  def project_invitation
    @project    = params[:project]
    @summarizer = ProjectInvitationSummarizer.new(@project.bucket)

    mail subject: "#{@inviter.name.familiar} added you to a project in Basecamp (#{@account.name})"
  end
end

InvitationsMailer.with(inviter: person_a, invitee: person_b).account_invitation.deliver_later
```

### Direct & resolved routes

[Pull Request](https://github.com/rails/rails/pull/23138)

Rails 5.1 has added two new methods, `resolve` and `direct`, to the routing
DSL.

The `resolve` method allows customizing polymorphic mapping of models.

``` ruby
resource :basket

resolve("Basket") { [:basket] }
```

``` erb
<%= form_for @basket do |form| %>
  <!-- basket form -->
<% end %>
```

This will generate the singular URL `/basket` instead of the usual `/baskets/:id`.

The `direct` method allows creation of custom URL helpers.

``` ruby
direct(:homepage) { "http://www.rubyonrails.org" }

>> homepage_url
=> "http://www.rubyonrails.org"
```

The return value of the block must be a valid argument for the `url_for`
method. So, you can pass a valid string URL, Hash, Array, an
Active Model instance, or an Active Model class.

``` ruby
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
can generate form tags based on URLs, scopes or models.

``` erb
# Using just a URL:

<%= form_with url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>

# =>
<form action="/posts" method="post" data-remote="true">
  <input type="text" name="title">
</form>

# Adding a scope prefixes the input field names:

<%= form_with scope: :post, url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>
# =>
<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>

# Using a model infers both the URL and scope:

<%= form_with model: Post.new do |form| %>
  <%= form.text_field :title %>
<% end %>
# =>
<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>

# An existing model makes an update form and fills out field values:

<%= form_with model: Post.first do |form| %>
  <%= form.text_field :title %>
<% end %>
# =>
<form action="/posts/1" method="post" data-remote="true">
  <input type="hidden" name="_method" value="patch">
  <input type="text" name="post[title]" value="<the title of the post>">
</form>
```

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Cable
-----------

Please refer to the [Changelog][action-cable] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Added support for `channel_prefix` to Redis and evented Redis adapters
    in `cable.yml` to avoid name collisions when using the same Redis server
    with multiple applications.
    ([Pull Request](https://github.com/rails/rails/pull/27425))

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action View
-------------

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

### Deprecations

### Notable changes

*   Skipped comments in the output of `mysqldump` command by default.
    ([Pull Request](https://github.com/rails/rails/pull/23301))

*   Fixed `ActiveRecord::Relation#count` to use Ruby's `Enumerable#count` for counting
    records when a block is passed as argument instead of silently ignoring the
    passed block.
    ([Pull Request](https://github.com/rails/rails/pull/24203))

*   Pass `"-v ON_ERROR_STOP=1"` flag with `psql` command to not suppress SQL errors.
    ([Pull Request](https://github.com/rails/rails/pull/24773))

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Job
-----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

### Deprecations

### Notable changes

*   Added `Module#delegate_missing_to` to delegate method calls not
    defined for the current object to a proxy object.
    ([Pull Request](https://github.com/rails/rails/pull/23930))

*   Added `Date#all_day` which returns a range representing the whole day
    of the current date & time.
    ([Pull Request](https://github.com/rails/rails/pull/24930))

Credits
-------

See the
[full list of contributors to Rails](http://contributors.rubyonrails.org/) for
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
