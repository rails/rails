*   Use `Asia/Dubai` for "Abu Dhabi" timezone instead of `Asia/Muscat`

    The "Abu Dhabi" timezone now maps to the canonical `Asia/Dubai` IANA
    identifier instead of `Asia/Muscat`. This improves consistency with
    browser timezone detection and correctly represents Abu Dhabi's
    geographic location in the UAE. Both timezones are functionally
    identical (UTC+04:00, no DST), so this is not a breaking change.

    *Ellin Pino*

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
