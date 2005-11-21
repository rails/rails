require File.dirname(__FILE__) + '/../../inflector' unless defined? Inflector
module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Integer #:nodoc:
      module Inflections
        # 1.ordinalize  # => "1st"
        # 3.ordinalize  # => "3rd"
        # 10.ordinalize # => "10th"
        def ordinalize
          Inflector.ordinalize(self)
        end
      end
    end
  end
end
