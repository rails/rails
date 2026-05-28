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
