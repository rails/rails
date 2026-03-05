*   Add `group` method to `ActiveSupport::ContinuousIntegration` for parallel step execution.

    Groups collect steps and run them concurrently using a thread pool, reducing CI times
    by running independent checks in parallel. Sub-groups run sequentially within a single
    parallel slot allowing dependent steps to be grouped together.

    ```ruby
    CI.run do
      step "Setup", "bin/setup --skip-server"

      group "Checks", parallel: 2 do
        step "Style: Ruby", "bin/rubocop"
        step "Security: Brakeman", "bin/brakeman --quiet"
        step "Security: Gem audit", "bin/bundler-audit"

        group "Tests" do
          step "Tests: Rails", "bin/rails test"
          step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
        end
      end
    end
    ```

    *Donal McBreen*

*   Introduce `this_week?`, `this_month?`, and `this_year?` methods to Date/Time

    Similar to `today?`, `tomorrow?`, and `yesterday?`, these methods are useful to
    query time instances against the current period.

    ```ruby
    unless post.created_at.this_week?
      link_to "See week recap", week_recap_path(date)
    end
    ```

    *Matheus Richard*

*   Removed the deprecated `ActiveSupport::Multibyte::Chars` class.

    As well as `String#mb_chars`

    *Jean Boussier*

*   Changed `ActiveSupport::EventReporter#subscribe` to only provide the event name during filtering.

    Otherwise the event reporter would need to always build the expensive payload even when there is
    no active subscriber, which is very wasteful.

    *Jean Boussier*

*   Fix inflections to better handle overlapping acronyms.

    ```ruby
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "USD"
      inflect.acronym "USDC"
    end

    "USDC".underscore # => "usdc"
    ```

    *Said Kaldybaev*

*   Add `ActiveSupport::CombinedConfiguration` to offer interchangeable access to configuration provided by
    either ENV or encrypted credentials. Used by Rails to first look at ENV, then look in encrypted credentials,
    but can be configured separately with any number of API-compatible backends in a first-look order.

    The object is inspect safe and will only show keys, not values.

    *DHH*, *Emmanuel Hayford*

*   Add `ActiveSupport::EnvConfiguration` to provide access to ENV variables in a way that's compatible with
    `ActiveSupport::EncryptedConfiguration` and therefore can be used by `ActiveSupport::CombinedConfiguration`.

    The object is inspect safe and will only show keys, not values.

    Examples:

    ```ruby
    conf = ActiveSupport::EnvConfiguration.new
    conf.require(:db_host) # ENV.fetch("DB_HOST")
    conf.require(:aws, :access_key_id) # ENV.fetch("AWS__ACCESS_KEY_ID")
    conf.option(:cache_host) # ENV["CACHE_HOST"]
    conf.option(:cache_host, default: "cache-host-1") # ENV["CACHE_HOST"] || "cache-host-1"
    conf.option(:cache_host, default: -> { "cache-host-1" }) # ENV["CACHE_HOST"] || "cache-host-1"
    ```

    *DHH*, *Emmanuel Hayford*

*   Make flaky parallel tests easier to diagnose by deterministically assigning
    tests to workers.

    Rails assigns tests to workers in round-robin order so the same `--seed`
    and worker count will result in the same sequence of tests running on each
    worker (whether processes or threads) increasing the odds of reproducing
    test failures caused by test interdependence.

    This can make test runtime slower and spikier when one worker gets most of
    the slow tests. Enable `work_stealing: true` to allow idle workers to steal
    tests from busy workers in deterministic order, smoothing out runtime at the
    cost of less reproducible flaky-test failures.

    *Jeremy Daer*

*   Make `ActiveSupport::EventReporter#debug_mode?` true by default to emit debug events
    outside of Rails application contexts.

    *Gannon McGibbon*

*   Add `SecureRandom.base32` for generating case-insensitive keys that are unambiguous to humans.

    *Stanko Krtalic Rusendic & Miha Rekar*

*   Add a fast failure mode to `ActiveSupport::ContinuousIntegration` that stops the rest of
    the run after a step fails. Invoke by running `bin/ci --fail-fast` or `bin/ci -f`.

    *Dennis Paagman*

*   Implement LocalCache strategy on `ActiveSupport::Cache::MemoryStore`. The memory store
    needs to respond to the same interface as other cache stores (e.g. `ActiveSupport::NullStore`).

    *Mikey Gough*

*   Add a detailed failure summary to `ActiveSupport::ContinuousIntegration`.

    *Mike Dalessio*

*   Introduce `ActiveSupport::EventReporter::LogSubscriber` structured event logging.

    ```ruby
    class MyLogSubscriber < ActiveSupport::EventReporter::LogSubscriber
      self.namespace = "test"

      def something(event)
        info { "Event #{event[:name]} emitted." }
      end
    end
    ```

    *Gannon McGibbon*


Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activesupport/CHANGELOG.md) for previous changes.
