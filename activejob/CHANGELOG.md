*   Add `ActiveJob::Attributes` for declaring typed attributes that persist across
    job serialization and deserialization. It is included by `ActiveJob::Continuable`
    but can also be used standalone.

    It uses the Active Model Attributes API to define typed, defaulted
    attributes on jobs. Attribute values are automatically included in the
    serialized job data and restored on deserialization, eliminating the need
    to manually override `serialize` and `deserialize`.

    This is especially useful with `ActiveJob::Continuable`, where a job may be
    interrupted and resumed and attributes are preserved across resumptions.

    ```ruby
    class SubmitEnrollmentJob < ApplicationJob
      include ActiveJob::Continuable

      attribute :payment_token, :string
      attribute :billing_profile_id, :integer

      def perform(enrollment)
        step(:tokenize_payment_instrument) do
          self.payment_token = PaymentGateway.tokenize(enrollment.user.payment_instrument)
        end

        step(:create_billing_profile) do
          self.billing_profile_id = BillingProfileApi.create(customer_id: enrollment.user_id)
        end

        step(:submit_enrollment) do
          submission_id = EnrollmentApi.submit(enrollment, billing_profile_id)
          enrollment.update!(status: 'processing', submission_id: submission_id)
        end
      end
    end
    ```

    *Bart de Water*

*   Deprecate built-in `queue_classic` Active Job adapter.

    *Harun Sabljaković, Wojciech Wnętrzak*

*   Allow `retry_on` `wait` procs to accept the error as a second argument.

    Procs with arity 1 continue to receive only the execution count.

    ```ruby
    class RemoteServiceJob < ActiveJob::Base
      retry_on CustomError, wait: ->(executions, error) { error.retry_after || executions * 2 }

      def perform
        # ...
      end
    end
    ```

    *JP Camara*

*   Deprecate built-in `resque` adapter.

    If you're using this adapter, upgrade to `resque` 3.0 or later to use the `resque` gem's adapter.

    *zzak, Wojciech Wnętrzak*

*   Remove deprecated `sidekiq` Active Job adapter.

    The adapter is available in the `sidekiq` gem.

    *Wojciech Wnętrzak*

*   Deprecate built-in `delayed_job` adapter.

    If you're using this adapter, upgrade to `delayed_job` 4.2.0 or later to use the `delayed_job` gem's adapter.

    *Dino Maric, David Genord II, Wojciech Wnętrzak*

*   Deprecate built-in `backburner` adapter.

    *Dino Maric, Nathan Esquenazi, Earlopain*

*   Jobs are now enqueued after transaction commit.

    This fixes that jobs would surprisingly run against uncommitted and
    rolled-back records.

    New Rails 8.2 apps (and apps upgrading to `config.load_defaults "8.2"`)
    have `config.active_job.enqueue_after_transaction_commit = true` by default.
    Uncomment the setting in `config/initializers/new_framework_defaults_8_2.rb`
    to opt in.

    *mugitti9*

*   Un-deprecate the global `config.active_job.enqueue_after_transaction_commit`
    toggle for app-wide overrides. It was deprecated in Rails 8.0 (when the
    symbol values were removed) and made non-functional in 8.1. It now works
    as a boolean config again.

    *Jeremy Daer*

*   Deprecate built-in `sneakers` adapter.

    *Dino Maric*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
