module Rails
  module Generators
    class MigrationGenerator < NamedBase
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type field:type"
      hook_for :orm
    end
  end
end
