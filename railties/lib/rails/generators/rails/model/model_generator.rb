module Rails
  module Generators
    class ModelGenerator < NamedBase #metagenerator
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"
      hook_for :orm, :required => true
    end
  end
end
