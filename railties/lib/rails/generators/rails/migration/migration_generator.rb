module Rails
  module Generators
    class MigrationGenerator < NamedBase #metagenerator
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
      hook_for :orm, :required => true
    end
  end
end
