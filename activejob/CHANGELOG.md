*   Accept a block for `ActiveJob::ConfiguredJob#perform_later`.

    This was inconsistent with a regular `ActiveJob::Base#perform_later`.

    *fatkodima*

*   Raise a more specific error during deserialization when a previously serialized job class is now unknown.

    `ActiveJob::UnknownJobClassError` will be raised instead of a more generic
    `NameError` to make it easily possible for adapters to tell if the `NameError`
    was raised during job execution or deserialization.

    *Earlopain*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activejob/CHANGELOG.md) for previous changes.
