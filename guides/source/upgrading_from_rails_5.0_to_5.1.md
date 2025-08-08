**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Upgrading from Rails 5.0 to Rails 5.1
=====================================

This guide provides steps to be followed when you upgrade your applications from
Rails 5.0 to Rails 5.1. These steps are also available in individual release
guides.

--------------------------------------------------------------------------------

Key Changes
-----------

For more information on changes made to Rails 5.1 please see the [release
notes](5_1_release_notes.html).

### Top-level `HashWithIndifferentAccess` is soft-deprecated

If your application uses the top-level `HashWithIndifferentAccess` class, you
should slowly move your code to instead use
`ActiveSupport::HashWithIndifferentAccess`.

It is only soft-deprecated, which means that your code will not break at the
moment and no deprecation warning will be displayed, but this constant will be
removed in the future.

Also, if you have pretty old YAML documents containing dumps of such objects,
you may need to load and dump them again to make sure that they reference the
right constant, and that loading them won't break in the future.

### `application.secrets` now loaded with all keys as symbols

If your application stores nested configuration in `config/secrets.yml`, all
keys are now loaded as symbols, so access using strings should be changed.

From:

```ruby
Rails.application.secrets[:smtp_settings]["address"]
```

To:

```ruby
Rails.application.secrets[:smtp_settings][:address]
```

### Removed deprecated support to `:text` and `:nothing` in `render`

If your controllers are using `render :text`, they will no longer work. The new
method of rendering text with MIME type of `text/plain` is to use `render
:plain`.

Similarly, `render :nothing` is also removed and you should use the `head`
method to send responses that contain only headers. For example, `head :ok`
sends a 200 response with no body to render.

### Removed deprecated support of `redirect_to :back`

In Rails 5.0, `redirect_to :back` was deprecated. In Rails 5.1, it was removed
completely.

As an alternative, use `redirect_back`. It's important to note that
`redirect_back` also takes a `fallback_location` option which will be used in
case the `HTTP_REFERER` is missing.

```ruby
redirect_back(fallback_location: root_path)
```