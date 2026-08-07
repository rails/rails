# frozen_string_literal: true

require "helper"

class ProtectRetryArgumentsTest < ActiveSupport::TestCase
  test "protect_retry_arguments defaults to false" do
    assert_equal false, ActiveJob::Base.protect_retry_arguments
  end

  test "protect_retry_arguments prevents mutations when enabled" do
    job_class = Class.new(ActiveJob::Base) do
      self.protect_retry_arguments = true

      def perform(data)
        data[:mutated] = true
      end
    end

    data = { original: "value" }
    job = job_class.new(data)
    job.send(:_perform_job)

    # With protection enabled, original data should not be mutated
    assert_equal false, data.key?(:mutated)
  end

  test "protect_retry_arguments allows mutations when disabled" do
    job_class = Class.new(ActiveJob::Base) do
      self.protect_retry_arguments = false

      def perform(data)
        data[:mutated] = true
      end
    end

    data = { original: "value" }
    job = job_class.new(data)
    job.send(:_perform_job)

    # Without protection, original data should be mutated
    assert_equal true, data.key?(:mutated)
  end

  test "protect_retry_arguments can be set per job class" do
    protected_job = Class.new(ActiveJob::Base) do
      self.protect_retry_arguments = true

      def perform(data)
        data[:processed] = true
      end
    end

    unprotected_job = Class.new(ActiveJob::Base) do
      self.protect_retry_arguments = false

      def perform(data)
        data[:processed] = true
      end
    end

    protected_data = { value: "test" }
    protected_job.new(protected_data).send(:_perform_job)

    unprotected_data = { value: "test" }
    unprotected_job.new(unprotected_data).send(:_perform_job)

    # Protected job should not mutate original data
    assert_equal false, protected_data.key?(:processed)

    # Unprotected job should mutate original data
    assert_equal true, unprotected_data.key?(:processed)
  end
end
