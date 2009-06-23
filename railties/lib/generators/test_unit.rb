require 'generators/named_base'

module Rails
  module Generators
    class TestUnit < NamedBase
      protected
        def self.base_name
          'test_unit'
        end
    end
  end
end
