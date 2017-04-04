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

ToDo

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

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

Action View
-------------

Please refer to the [Changelog][action-view] for detailed changes.

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

Active Job
-----------

Please refer to the [Changelog][active-job] for detailed changes.

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

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
