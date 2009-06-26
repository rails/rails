require 'generators/named_base'

module TestUnit
  module Generators
    class Base < Rails::Generators::NamedBase
      check_class_collision :suffix => "Test"
    end
  end
end
