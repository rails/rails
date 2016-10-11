require "active_model/type/integer"

module ActiveModel
  module Type
    class UnsignedInteger < Integer # :nodoc:
      def initialize(*)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          #{self.class} is deprecated and will be removed in Rails 5.2.
          Please use #{self.class.superclass} instead.
        MSG
        super
      end
    end
  end
end
