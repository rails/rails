*   Fix `ActiveSupport::Duration.build` to support negative values.

    The algorithm to collect the `parts` of the `ActiveSupport::Duration`
    ignored the sign of the `value` and accumulated incorrect part values. This
    impacted `ActiveSupport::Duration#sum` (which is dependent on `parts`) but
    not `ActiveSupport::Duration#eql?` (which is dependent on `value`).

    *Caleb Buxton*, *Braden Staudacher*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md) for previous changes.
