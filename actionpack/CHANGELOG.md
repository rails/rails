## Rails 6.0.0.alpha (Unreleased) ##

*   Add support for automatic nonce generation for Rails UJS

    Because the UJS library creates a script tag to process responses it
    normally requires the script-src attribute of the content security
    policy to include 'unsafe-inline'.

    To work around this we generate a per-request nonce value that is
    embedded in a meta tag in a similar fashion to how CSRF protection
    embeds its token in a meta tag. The UJS library can then read the
    nonce value and set it on the dynamically generated script tag to
    enable it to execute without needing 'unsafe-inline' enabled.

    Nonce generation isn't 100% safe - if your script tag is including
    user generated content in someway then it may be possible to exploit
    an XSS vulnerability which can take advantage of the nonce. It is
    however an improvement on a blanket permission for inline scripts.

    It is also possible to use the nonce within your own script tags by
    using `nonce: true` to set the nonce value on the tag, e.g

        <%= javascript_tag nonce: true do %>
          alert('Hello, World!');
        <% end %>

    Fixes #31689.

    *Andrew White*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*

*   Add alias method `to_hash` to `to_h` for `cookies`.
    Add alias method `to_h` to `to_hash` for `session`.

    *Igor Kasyanchuk*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionpack/CHANGELOG.md) for previous changes.
