# frozen_string_literal: true

require 'abstract_unit'
require 'active_job'
require 'mailers/params_mailer'
require 'mailers/delayed_mailer'

class LegacyDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class LegacyDeliveryJob < ActionMailer::DeliveryJob
  end

  class LegacyArgumentDeliveryJob < ActiveJob::Base
    def perform(mailer, mail_method, delivery_method, *args)
    end
  end

  class NewArgumentDeliveryJob < ActiveJob::Base
    def perform(mailer, mail_method, delivery_method, args:)
    end
  end

  class KeyRestArgumentJob < ActiveJob::Base
    def perform(mailer, mail_method, delivery_method, **kwargs)
    end
  end

  setup do
    @previous_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = Logger.new(nil)

    @previous_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test

    @previous_deliver_later_queue_name = ActionMailer::Base.deliver_later_queue_name
    ActionMailer::Base.deliver_later_queue_name = :test_queue
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
    ParamsMailer.deliveries.clear

    ActionMailer::Base.delivery_method = @previous_delivery_method
    ActionMailer::Base.deliver_later_queue_name = @previous_deliver_later_queue_name
  end

  test 'should send parameterized mail correctly' do
    mail = ParamsMailer.with(inviter: 'david@basecamp.com', invitee: 'jason@basecamp.com').invitation
    args = [
      'ParamsMailer',
      'invitation',
      'deliver_now',
      { inviter: 'david@basecamp.com', invitee: 'jason@basecamp.com' },
    ]

    with_delivery_job(LegacyDeliveryJob) do
      assert_deprecated do
        assert_performed_with(job: ActionMailer::Parameterized::DeliveryJob, args: args) do
          mail.deliver_later
        end
      end
    end
  end

  test 'should send mail correctly' do
    mail = DelayedMailer.test_message(1, 2, 3)
    args = [
      'DelayedMailer',
      'test_message',
      'deliver_now',
      1,
      2,
      3,
    ]

    with_delivery_job(LegacyDeliveryJob) do
      assert_deprecated do
        assert_performed_with(job: LegacyDeliveryJob, args: args) do
          mail.deliver_later
        end
      end
    end
  end

  test 'triggers a deprecation warning when a delivery job use legacy arguments' do
    with_delivery_job(LegacyArgumentDeliveryJob) do
      assert_deprecated('Action Mailer will pass the mail arguments inside the `:args` keyword argument') do
        perform_enqueued_jobs do
          DelayedMailer.test_message(1, 2, 3).deliver_later
        end
      end
    end
  end

  test 'does not trigger a deprecation warning when a delivery job use a required `args` kwargs' do
    with_delivery_job(NewArgumentDeliveryJob) do
      assert_not_deprecated do
        perform_enqueued_jobs do
          DelayedMailer.test_message(1, 2, 3).deliver_later
        end
      end
    end
  end

  test 'does not trigger a deprecation warning when a delivery job use a keyrest argument' do
    with_delivery_job(KeyRestArgumentJob) do
      assert_not_deprecated do
        perform_enqueued_jobs do
          DelayedMailer.test_message(1, 2, 3).deliver_later
        end
      end
    end
  end

  private
    def with_delivery_job(job)
      old_params_delivery_job = ParamsMailer.delivery_job
      old_regular_delivery_job = DelayedMailer.delivery_job
      ParamsMailer.delivery_job = job
      DelayedMailer.delivery_job = job
      yield
    ensure
      ParamsMailer.delivery_job = old_params_delivery_job
      DelayedMailer.delivery_job = old_regular_delivery_job
    end
end
