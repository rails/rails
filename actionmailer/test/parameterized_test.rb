# frozen_string_literal: true

require "abstract_unit"
require "active_job"
require "mailers/params_mailer"

class ParameterizedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class DummyDeliveryJob < ActionMailer::MailDeliveryJob
  end

  setup do
    @previous_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = Logger.new(nil)

    @previous_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test

    @previous_deliver_later_queue_name = ActionMailer::Base.deliver_later_queue_name
    ActionMailer::Base.deliver_later_queue_name = :test_queue

    I18n.backend.store_translations("de", params_mailer: { invitation: { subject: "Einladung" } })

    @mail = ParamsMailer.with(inviter: "david@basecamp.com", invitee: "jason@basecamp.com", locale: :de).invitation
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
    ParamsMailer.deliveries.clear

    ActionMailer::Base.delivery_method = @previous_delivery_method
    ActionMailer::Base.deliver_later_queue_name = @previous_deliver_later_queue_name

    I18n.backend.reload!
  end

  test "parameterized headers" do
    assert_equal(["jason@basecamp.com"], @mail.to)
    assert_equal(["david@basecamp.com"], @mail.from)
    assert_equal('Einladung', @mail.subject)
    assert_equal("So says david@basecamp.com", @mail.body.encoded)
  end

  test "enqueue the email with params" do
    args = [
      "ParamsMailer",
      "invitation",
      "deliver_now",
      params: { inviter: "david@basecamp.com", invitee: "jason@basecamp.com", locale: :de },
      args: [],
    ]
    assert_performed_with(job: ActionMailer::MailDeliveryJob, args: args) do
      @mail.deliver_later
    end
  end

  test "respond_to?" do
    mailer = ParamsMailer.with(inviter: "david@basecamp.com", invitee: "jason@basecamp.com")

    assert_respond_to mailer, :invitation
    assert_not_respond_to mailer, :anything

    invitation = mailer.method(:invitation)
    assert_equal Method, invitation.class

    assert_raises(NameError) do
      invitation = mailer.method(:anything)
    end
  end

  test "should enqueue a parameterized request with the correct delivery job" do
    args = [
      "ParamsMailer",
      "invitation",
      "deliver_now",
      params: { inviter: "david@basecamp.com", invitee: "jason@basecamp.com", locale: :de },
      args: [],
    ]

    with_delivery_job DummyDeliveryJob do
      assert_performed_with(job: DummyDeliveryJob, args: args) do
        @mail.deliver_later
      end
    end
  end

  private
    def with_delivery_job(job)
      old_delivery_job = ParamsMailer.delivery_job
      ParamsMailer.delivery_job = job
      yield
    ensure
      ParamsMailer.delivery_job = old_delivery_job
    end
end
