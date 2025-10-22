*   Add `Date.upcoming` method to find the next occurrence of a specific month and day.

    Returns the upcoming date for the specified month and day. If the date has already
    passed this year, returns the date for next year. Handles edge cases like leap years
    properly (e.g., Feb 29 in non-leap years will find the next leap year).

    ```ruby
    Date.upcoming(month: 12, day: 25)  # => Date for next Christmas (Dec 25)
    Date.upcoming(month: 1, day: 1)    # => Date for next New Year's Day (Jan 1)
    Date.upcoming(month: 2, day: 29)   # => Date for next Feb 29 (finds next leap year if needed)
    ```

    *Victor Cobos*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activesupport/CHANGELOG.md) for previous changes.
