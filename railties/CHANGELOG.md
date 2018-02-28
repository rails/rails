## Rails 6.0.0.alpha (Unreleased) ##

*   Add "rails routes --expanded" option to output routes in expanded mode like
    "psql --expanded". Result looks like:

    ```
    $ rails routes --expanded
    --[ Route 1 ]------------------------------------------------------------
    Prefix            | high_scores
    Verb              | GET
    URI               | /high_scores(.:format)
    Controller#Action | high_scores#index
    --[ Route 2 ]------------------------------------------------------------
    Prefix            | new_high_score
    Verb              | GET
    URI               | /high_scores/new(.:format)
    Controller#Action | high_scores#new
    ```

    *Benoit Tigeot*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/railties/CHANGELOG.md) for previous changes.
