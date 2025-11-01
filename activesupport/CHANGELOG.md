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

*   Add `attempts` parameter to `ActiveSupport::ContinuousIntegration#step` to
    allow retrying flaky CI steps a specified number of times before marking
    them as failed.
    ```ruby
    step "Flaky test", "bin/rails test test/models/flaky_test.rb", attempts: 3
    ```

    *Harsh Deep*


Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activesupport/CHANGELOG.md) for previous changes.
