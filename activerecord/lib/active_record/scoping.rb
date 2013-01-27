module ActiveRecord
  module Scoping
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
    end

    module ClassMethods
      def current_scope #:nodoc:
        Thread.current["#{self}_current_scope"]
      end

      def current_scope=(scope) #:nodoc:
        Thread.current["#{self}_current_scope"] = scope
      end
    end

    def populate_with_current_scope_attributes
      return unless self.class.scope_attributes?

      self.class.scope_attributes.each do |att,value|
        send("#{att}=", value) if respond_to?("#{att}=")
      end
    end
  end
end
