require 'generators/named_base'

module TestUnit
  module Generators
    class Base < Rails::Generators::NamedBase
      protected
        def self.base_name
          'test_unit'
        end
    end
  end
end
