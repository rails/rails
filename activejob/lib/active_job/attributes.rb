# frozen_string_literal: true

# :markup: markdown
require "active_model"

module ActiveJob
  # Active Job \Attributes
  # ======================
  #
  # The Attributes module provides typed attributes for jobs using the
  # [Active Model Attributes API](rdoc-ref:ActiveModel::Attributes). Declared
  # attributes are automatically serialized with the job data and restored when
  # the job is deserialized. If that fails, for example because a record was
  # deleted, the error is raised when the job is performed instead, so it can
  # be handled with `retry_on`, `discard_on` or `rescue_from`.
  #
  # This is especially useful with ActiveJob::Continuation, where a job may be
  # interrupted and resumed multiple times and you need to persist attributes
  # across steps until the job finishes.
  #
  # ```
  # class SubmitEnrollmentJob < ApplicationJob
  #   include ActiveJob::Continuable
  #
  #   attribute :payment_token, :string
  #   attribute :billing_profile_id, :integer
  #
  #   def perform(enrollment)
  #     step :tokenize_payment_instrument do
  #       self.payment_token = PaymentGateway.tokenize(enrollment.user.payment_instrument)
  #     end
  #
  #     step :create_billing_profile do
  #       self.billing_profile_id = BillingProfileApi.create(customer_id: enrollment.user_id)
  #     end
  #
  #     step :submit_enrollment do
  #       submission_id = EnrollmentApi.submit(enrollment, payment_token, billing_profile_id)
  #       enrollment.update!(status: 'processing', submission_id: submission_id)
  #     end
  #   end
  # end
  # ```
  #
  # Attributes also work without Continuation, persisting across retries.
  #
  # Attributes support all built-in Active Model types, see `ActiveModel::Attributes`
  # for details. For custom types attribute values must be serializable
  # as Active Job arguments. See `ActiveJob::Arguments` for the full list of
  # supported types.
  module Attributes
    extend ActiveSupport::Concern
    include ActiveModel::Attributes

    def serialize # :nodoc:
      super.merge("attributes" => serialize_attribute_values)
    end

    def deserialize(job_data) # :nodoc:
      super
      @serialized_attribute_values = job_data["attributes"]

      begin
        deserialize_attribute_values
      rescue DeserializationError
        # Raised again from perform_now, where the job's rescue handlers can handle it.
      end
    end

    private
      def deserialize_arguments_if_needed
        super
        deserialize_attribute_values
      end

      def serialize_attribute_values
        return @serialized_attribute_values if @serialized_attribute_values

        values = {}
        self.class.attribute_names.each do |name|
          values[name] = @attributes.fetch_value(name)
        end
        Arguments.serialize([values]).first
      end

      def deserialize_attribute_values
        return unless @serialized_attribute_values

        values = Arguments.deserialize([@serialized_attribute_values]).first
        values.each do |name, value|
          name = name.to_s
          @attributes.write_cast_value(name, value) if self.class.attribute_types.key?(name)
        end
        @serialized_attribute_values = nil
      end
  end
end
