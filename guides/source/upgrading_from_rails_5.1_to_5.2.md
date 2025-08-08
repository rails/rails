**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 5.1 to Rails 5.2
=====================================

This guide provides steps to be followed when you upgrade your applications from
Rails 5.1 to Rails 5.2. These steps are also available in individual release
guides.

--------------------------------------------------------------------------------

Key Changes
-----------

For more information on changes made to Rails 5.2 please see the [release
notes](5_2_release_notes.html).

### Bootsnap

Rails 5.2 adds bootsnap gem in the [newly generated app's
Gemfile](https://github.com/rails/rails/pull/29313). The `app:update` command
sets it up in `boot.rb`. If you want to use it, then add it in the Gemfile:

```ruby
# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false
```

Otherwise change the `boot.rb` to not use bootsnap.

### Expiry in signed or encrypted cookie is now embedded in the cookies values

To improve security, Rails now embeds the expiry information also in encrypted
or signed cookies value.

This new embedded information makes those cookies incompatible with versions of
Rails older than 5.2.

If you require your cookies to be read by 5.1 and older, or you are still
validating your 5.2 deploy and want to allow you to rollback set
`Rails.application.config.action_dispatch.use_authenticated_cookie_encryption`
to `false`.