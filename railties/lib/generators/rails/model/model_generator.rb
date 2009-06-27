module Rails
  module Generators
    class ModelGenerator < NamedBase
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type, field:type"
      invoke_for :orm, :test_framework
    end
  end
end
