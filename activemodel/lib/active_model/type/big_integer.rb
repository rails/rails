# frozen_string_literal: true

require_relative "integer"

module ActiveModel
  module Type
    class BigInteger < Integer # :nodoc:
      def initialize(*)
        ActiveSupport::Deprecation.warn \
          "#{self.class} is deprecated and will be removed in Rails 6.0. " \
          "Please use #{self.class.superclass} instead."
        super
      end
    end
  end
end
