*   Add a `fetch_multi` method to the cache stores. The method provides
    an easy to use API for fetching multiple values from the cache.

    Example:

        # Calculating scores is expensive, so we only do it for posts
        # that have been updated. Cache keys are automatically extracted
        # from objects that define a #cache_key method.
        scores = Rails.cache.fetch_multi(*posts) do |post|
          calculate_score(post)
        end

    *Daniel Schierbeck*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activesupport/CHANGELOG.md) for previous changes.
