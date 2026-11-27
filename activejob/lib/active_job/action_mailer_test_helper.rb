# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"

module ActiveJob
  # Provides test helpers for emails enqueued through Active Job.
  # The Active Job railtie adds these methods to ActionMailer::TestHelper.
  # If you use both libraries outside a Rails application, opt in explicitly:
  #
  # ```ruby
  # require "action_mailer"
  # require "active_job"
  #
  # ActionMailer::TestHelper.prepend(ActiveJob::ActionMailerTestHelper)
  # ```
  module ActionMailerTestHelper
    def self.prepended(base) # :nodoc:
      base.include ActiveJob::TestHelper
    end

    def capture_emails(&block) # :nodoc:
      super { deliver_enqueued_emails(&block) }
    end

    # Asserts that the number of emails enqueued for later delivery matches
    # the given number.
    #
    # ```
    # def test_emails
    #   assert_enqueued_emails 0
    #   ContactMailer.welcome.deliver_later
    #   assert_enqueued_emails 1
    #   ContactMailer.welcome.deliver_later
    #   assert_enqueued_emails 2
    # end
    # ```
    #
    # If a block is passed, that block should cause the specified number of
    # emails to be enqueued.
    #
    # ```
    # def test_emails_again
    #   assert_enqueued_emails 1 do
    #     ContactMailer.welcome.deliver_later
    #   end
    #
    #   assert_enqueued_emails 2 do
    #     ContactMailer.welcome.deliver_later
    #     ContactMailer.welcome.deliver_later
    #   end
    # end
    # ```
    def assert_enqueued_emails(number, &block)
      assert_enqueued_jobs(number, only: ->(job) { delivery_job_filter(job) }, &block)
    end

    # Asserts that a specific email has been enqueued, optionally
    # matching arguments and/or params.
    #
    # ```
    # def test_email
    #   ContactMailer.welcome.deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome
    # end
    #
    # def test_email_with_parameters
    #   ContactMailer.with(greeting: "Hello").welcome.deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome, params: { greeting: "Hello" }
    # end
    #
    # def test_email_with_arguments
    #   ContactMailer.welcome("Hello", "Goodbye").deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome, args: ["Hello", "Goodbye"]
    # end
    #
    # def test_email_with_named_arguments
    #   ContactMailer.welcome(greeting: "Hello", farewell: "Goodbye").deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome, args: [{ greeting: "Hello", farewell: "Goodbye" }]
    # end
    #
    # def test_email_with_parameters_and_arguments
    #   ContactMailer.with(greeting: "Hello").welcome("Cheers", "Goodbye").deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome, params: { greeting: "Hello" }, args: ["Cheers", "Goodbye"]
    # end
    #
    # def test_email_with_parameters_and_named_arguments
    #   ContactMailer.with(greeting: "Hello").welcome(farewell: "Goodbye").deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome, params: { greeting: "Hello" }, args: [{farewell: "Goodbye"}]
    # end
    #
    # def test_email_with_parameterized_mailer
    #   ContactMailer.with(greeting: "Hello").welcome.deliver_later
    #   assert_enqueued_email_with ContactMailer.with(greeting: "Hello"), :welcome
    # end
    #
    # def test_email_with_matchers
    #   ContactMailer.with(greeting: "Hello").welcome("Cheers", "Goodbye").deliver_later
    #   assert_enqueued_email_with ContactMailer, :welcome,
    #     params: ->(params) { /hello/i.match?(params[:greeting]) },
    #     args: ->(args) { /cheers/i.match?(args[0]) }
    # end
    # ```
    #
    # If a block is passed, that block should cause the specified email
    # to be enqueued.
    #
    # ```
    # def test_email_in_block
    #   assert_enqueued_email_with ContactMailer, :welcome do
    #     ContactMailer.welcome.deliver_later
    #   end
    # end
    # ```
    def assert_enqueued_email_with(mailer, method, params: nil, args: nil, queue: nil, &block)
      if mailer.is_a? ::ActionMailer::Parameterized::Mailer
        params = mailer.instance_variable_get(:@params)
        mailer = mailer.instance_variable_get(:@mailer)
      end

      args = Array(args) unless args.is_a?(Proc)
      queue ||= mailer.delivery_job.new(mailer.name).queue_name

      expected = ->(job_args) do
        job_kwargs = job_args.extract_options!

        [mailer.to_s, method.to_s, "deliver_now"] == job_args &&
          params === job_kwargs[:params] && args === job_kwargs[:args]
      end

      assert_enqueued_with(job: mailer.delivery_job, args: expected, queue: queue.to_s, &block)
    end

    # Asserts that no emails are enqueued for later delivery.
    #
    # ```
    # def test_no_emails
    #   assert_no_enqueued_emails
    #   ContactMailer.welcome.deliver_later
    #   assert_enqueued_emails 1
    # end
    # ```
    #
    # If a block is provided, it should not cause any emails to be enqueued.
    #
    # ```
    # def test_no_emails
    #   assert_no_enqueued_emails do
    #     # No emails should be enqueued from this block
    #   end
    # end
    # ```
    def assert_no_enqueued_emails(&block)
      assert_enqueued_emails 0, &block
    end

    # Delivers all enqueued emails. If a block is given, delivers all of the emails
    # that were enqueued throughout the duration of the block. If a block is
    # not given, delivers all the enqueued emails up to this point in the test.
    #
    # ```
    # def test_deliver_enqueued_emails
    #   deliver_enqueued_emails do
    #     ContactMailer.welcome.deliver_later
    #   end
    #
    #   assert_emails 1
    # end
    #
    # def test_deliver_enqueued_emails_without_block
    #   ContactMailer.welcome.deliver_later
    #
    #   deliver_enqueued_emails
    #
    #   assert_emails 1
    # end
    # ```
    #
    # If the `:queue` option is specified,
    # then only the email(s) enqueued to a specific queue will be performed.
    #
    # ```
    # def test_deliver_enqueued_emails_with_queue
    #   deliver_enqueued_emails queue: :external_mailers do
    #     CustomerMailer.deliver_later_queue_name = :external_mailers
    #     CustomerMailer.welcome.deliver_later # will be performed
    #     EmployeeMailer.deliver_later_queue_name = :internal_mailers
    #     EmployeeMailer.welcome.deliver_later # will not be performed
    #   end
    #
    #   assert_emails 1
    # end
    # ```
    #
    # If the `:at` option is specified, then only delivers emails enqueued to deliver
    # immediately or before the given time.
    def deliver_enqueued_emails(queue: nil, at: nil, &block)
      perform_enqueued_jobs(only: ->(job) { delivery_job_filter(job) }, queue: queue, at: at, &block)
    end

    private
      def delivery_job_filter(job)
        job_class = job.is_a?(Hash) ? job.fetch(:job) : job.class

        ::ActionMailer::Base.descendants.map(&:delivery_job).include?(job_class)
      end
  end
end
