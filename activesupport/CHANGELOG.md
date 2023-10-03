*   Implement `HashWithIndifferentAccess#to_proc`.

    Previously, calling `#to_proc` on `HashWithIndifferentAccess` object used inherited `#to_proc`
    method from the `Hash` class, which was not able to access values using indifferent keys.

    *fatkodima*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activesupport/CHANGELOG.md) for previous changes.
