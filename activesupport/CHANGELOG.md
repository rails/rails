*   Make flaky parallel tests easier to diagnose by deterministically assigning
    tests to workers.

    Rails assigns tests to workers in round-robin order so the same `--seed`
    and worker count will result in the same sequence of tests running on each
    worker (whether processes or threads) increasing the odds of reproducing
    test failures caused by test interdependence.

    This can make test runtime slower and spikier when one worker gets most of
    the slow tests. Enable `work_stealing: true` to allow idle workers to steal
    tests from busy workers in deterministic order, smoothing out runtime at the
    cost of less reproductible flaky-test failures.

    *Jeremy Daer*

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
