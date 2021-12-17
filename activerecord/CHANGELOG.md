*   Fix autosave associations when saving new records with validate: false.

    When saving a new record autosave wasn't considering the reflection
    validate option and always validating the association even when the
    default value of validate was false or it was set explicit to false.

    When `autosave: true` the option was being respected, but when it
    wasn't the association was always being validated disregarding the
    value set to `validate`.

    *Marcelo Lauxen*

*   Add `authenticate_by` when using `has_secure_password`.

    `authenticate_by` is intended to replace code like the following, which
    returns early when a user with a matching email is not found:

    ```ruby
    User.find_by(email: "...")&.authenticate("...")
    ```

    Such code is vulnerable to timing-based enumeration attacks, wherein an
    attacker can determine if a user account with a given email exists. After
    confirming that an account exists, the attacker can try passwords associated
    with that email address from other leaked databases, in case the user
    re-used a password across multiple sites (a common practice). Additionally,
    knowing an account email address allows the attacker to attempt a targeted
    phishing ("spear phishing") attack.

    `authenticate_by` addresses the vulnerability by taking the same amount of
    time regardless of whether a user with a matching email is found:

    ```ruby
    User.authenticate_by(email: "...", password: "...")
    ```

    *Jonathan Hefner*


Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activerecord/CHANGELOG.md) for previous changes.
