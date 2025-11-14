*   Add Hash filtering helpers: `Hash#reject_if_value`, `Hash#select_if_value`,
    `Hash#reject_if_key`, and `Hash#select_if_key`, plus the bang variants
    `reject_if_value!`, `select_if_value!`, `reject_if_key!`, and `select_if_key!`.
    Predicates can be provided as a method name (Symbol/String), a callable, or a block.
    Available via `require "active_support/core_ext/hash/filtering"` or by requiring
    all Hash core extensions.

    ```ruby
    { a: "", b: 1, c: nil }.reject_if_value(:blank?)
    # => { b: 1 }

    { "ax" => 1, "by" => 2 }.select_if_key(:start_with?, "a")
    # => { "ax" => 1 }
    ```

    *Andrei Andriichuk*

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
