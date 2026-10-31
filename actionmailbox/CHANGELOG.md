*   Load Action Mailbox's extensions to the Mail gem with `ActionMailbox::InboundEmail`.

    Requiring Action Mailbox no longer loads the Mail gem and its address parser, which made
    up about 40 ms of booting a new application in development and of every `bin/rails`
    command. Code that uses the extensions, like `Mail::Message#recipients`, outside of Action
    Mailbox needs to require `action_mailbox/mail_ext`.

    *Lawrence Lin*

*   Return `422 Unprocessable Content` for malformed Mailgun, Postmark, and SendGrid raw email parameters.

    *Andrii Furmanets*

*   Return `422 Unprocessable Content` for malformed Mailgun and Postmark original recipient parameters.

    *Andrii Furmanets*

*   Return `401 Unauthorized` for malformed Mailgun signatures.

    *Andrii Furmanets*

*   Return `422 Unprocessable Content` for Mandrill inbound events that are missing a raw message.

    *Andrii Furmanets*

*   Return `422 Unprocessable Content` for Mandrill events payloads that don't parse to a JSON array of objects.

    Previously, valid JSON of the wrong shape (e.g. `null`, a scalar, an object, or an array containing non-objects)
    raised an unhandled `NoMethodError` and resulted in a 500. This now matches the existing behavior for invalid JSON.

    *Nesan Vettivel*

*   Return `422 Unprocessable Content` for malformed SendGrid envelopes.

    *Andrii Furmanets*

*   Deprecate `Mail::Address.wrap` because it isn't used.

    *Gannon McGibbon*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionmailbox/CHANGELOG.md) for previous changes.
