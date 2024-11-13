*   Reload virtual columns on update in PostgreSQL

    Automatically reload virtual columns on `update` when using PostgreSQL. This is done by issuing a single
    UPDATE query that includes a RETURNING clause.

    Given a `Post` model represented by the following schema:

    ```ruby
    create_table :posts do |t|
      t.integer :upvotes_count
      t.integer :downvotes_count
      t.virtual :total_votes_count, type: :integer, as: "upvotes_count + downvotes_count", stored: true
    end
    ```

    `total_votes_count` will reflect the sum of upvotes and downvotes after `update` is successfully called.
    Prior to this change calling `reload` would have been necessary to obtain the new value calculated by
    the database.

    ```ruby
    post = Post.find(1)
    post.update(upvotes_count: 2, downvotes_count: 2)
    # Calling `post.reload` no longer necessary
    post.total_votes => 4
    ```

    *Alex Baldwin*

*   Add support for enabling or disabling transactional tests per database.

    A test class can now override the default `use_transactional_tests` setting
    for individual databases, which can be useful if some databases need their
    current state to be accessible to an external process while tests are running.

    ```ruby
    class MostlyTransactionalTest < ActiveSupport::TestCase
      self.use_transactional_tests = true
      skip_transactional_tests_for_database :shared
    end
    ```

    *Matthew Cheetham*, *Morgan Mareve*

*   Cast `query_cache` value when using URL configuration.

    *zzak*

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
