module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Range #:nodoc:
      # Getting dates in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :db => Proc.new { |start, stop| "BETWEEN '#{start.to_s(:db)}' AND '#{stop.to_s(:db)}'" }
        }

        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :to_default_s, :to_s
            alias_method :to_s, :to_formatted_s
          end
        end

        def to_formatted_s(format = :default)
          DATE_FORMATS[format] ? DATE_FORMATS[format].call(first, last) : to_default_s   
        end
      end
    end
  end
end
