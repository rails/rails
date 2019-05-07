# frozen_string_literal: true

module ActiveSupport
  module IncludeDateTime #:nodoc:
    # Extends the default Range#include? to support
    # Date and DateTime range comparisons.
    #
    #   (Date.today.beginning_of_month..Date.today.end_of_month).include?(Date.today) # => true
    #   (Date.today.beginning_of_month..Date.today.end_of_month).include?(DateTime.now) # => true
    #   (DateTime.now.beginning_of_month..DateTime.now.end_of_month).include?(Date.today) # => true
    #   (DateTime.now.beginning_of_month..DateTime.now.end_of_month).include?(DateTime.now) # => true
    #
    def include?(value)
      if first.is_a?(Date) || first.is_a?(DateTime)
        cover?(value)
      elsif last.is_a?(Date) || last.is_a?(DateTime)
        cover?(value)
      else
        super
      end
    end
  end
end

Range.prepend(ActiveSupport::IncludeDateTime)
