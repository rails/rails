# frozen_string_literal: true

module ActiveRecord
  class PreventedAccessError < ActiveRecordError # :nodoc:
  end

  # = Active Record Access Prevention
  module AccessPrevention
    extend ActiveSupport::Concern

    thread_mattr_accessor :enabled, instance_accessor: false, default: false

    module ClassMethods
      # Lets you prevent database access from ActiveRecord for the duration of
      # a block.
      #
      # ==== Examples
      #   ActiveRecord::Base.while_preventing_access do
      #     Project.first  # raises an exception
      #   end
      #
      def while_preventing_access(&block)
        previous_enabled = preventing_access?
        AccessPrevention.enabled = true
        yield
      ensure
        AccessPrevention.enabled = previous_enabled
      end

      # Determines whether access is currently being prevented.
      #
      # Returns the value of +enabled+.
      def preventing_access?
        AccessPrevention.enabled
      end
    end
  end
end
