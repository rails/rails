# frozen_string_literal: true

module ActionView
  # = Action View CSS Helper
  module Helpers #:nodoc:
    module CssHelper

      # helper method to assign conditional CSS classes.
      def css_classes(*classes)
        classes.map do |css_class|
          if css_class.is_a? Hash
            css_class.find_all(&:last).map { |c| c.first.to_s.dasherize }
          else
            css_class.to_s.dasherize
          end
        end.flatten.join(' ')
      end
    end
  end
end
