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
