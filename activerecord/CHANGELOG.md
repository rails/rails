*   Deprecate the `:required` option for `belongs_to` associations.

    The `:required` option for `belongs_to` associations is deprecated and will be removed in Rails 7.3. The `:optional` option should be used instead.

    The global configuration option `config.active_record.belongs_to_required_by_default` and the per model configuration attribute `#belongs_to_required_by_default` have also been deprecated and will be removed in Rails 7.3.

    *Joshua Young*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
