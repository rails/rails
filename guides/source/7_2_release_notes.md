**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 7.2 Release Notes
===============================

Highlights in Rails 7.2:

--------------------------------------------------------------------------------

Upgrading to Rails 7.2
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 7.1 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 7.2. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-7-1-to-rails-7-2)
guide.

Major Features
--------------

### `ActiveModel::Base` class

Base provides subclasses with an Active Record-inspired interface to execute
code with familiar methods like `.create`, `#save`, and `#update`. It includes
the `ActiveModel::API` module transitively through the `ActiveModel::Model`
module, so it's designed to integrate with Action Pack and Action View out of
the box.

Similar to the convention for applications to define an
`ApplicationRecord` that inherits `ActiveRecord::Base`, it's
also conventional for applications to define an `ApplicationModel`
that inherits from Base:

```ruby
# app/models/application_model.rb

class ApplicationModel < ActiveModel::Base
end
```

Unlike other facets of Active Model, `ActiveModel::Base` is a Class instead of a
Module. Once classes have inherited from `ActiveModel::Base`, they only need to
define a `#save!` method. For example, consider a `Session` model responsible
for authenticating a `User` with `email` and `password` credentials:

```ruby
# app/models/session.rb

class Session < ApplicationModel
  attr_accessor :email, :password, :request

  validates :email, :password, presence: true

  def save!
    if (user = User.authenticate_by(email: email, password: password))
      request.cookies[:signed_user_id] = user.signed_id
    else
      errors.add(:base, :invalid)

      raise ActiveModel::ValidationError.new(self)
    end
  end
end
```

NOTE: This implementation is intended for demonstration purposes only, and
is not meant to be used in a real application.

By defining `#save!`, the `Session` class gains access to other methods provided
by `ActiveModel::Base`, like `create!` and `create`, `update!` and `update`,
`persisted?` and `new_model?`, and all of the other utilities provided by
`ActiveModel::Model`, `ActiveModel::API`, and `ActiveModel::Conversion`.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

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

### Deprecations

### Notable changes

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

### Deprecations

### Notable changes

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

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

### Deprecations

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
