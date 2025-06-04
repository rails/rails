*   The Trix dependency is now satisfied by a gem, `action_text-trix`, rather than vendored
    files. This allows applications to bump Trix versions independently of Rails
    releases. Effectively this also upgrades Trix to `>= 2.1.15`.

    *Mike Dalessio*

*   Change `ActionText::RichText#embeds` assignment from `before_save` to `before_validation`

    *Sean Doyle*

*   Add support for `locals` parameter in `ActionText::Content#to_s` method.

    This allows passing local variables when rendering ActionText content.

    ```ruby
    # Before
    content.to_s

    # After
    content.to_s(locals: { user: current_user })
    ```

    *Piotr Paweł Witek*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actiontext/CHANGELOG.md) for previous changes.
