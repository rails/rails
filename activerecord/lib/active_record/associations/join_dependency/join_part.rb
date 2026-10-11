# frozen_string_literal: true

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      # A JoinPart represents a part of a JoinDependency. It is inherited
      # by JoinBase and JoinAssociation. A JoinBase represents the Active Record which
      # everything else is being joined onto. A JoinAssociation represents an association which
      # is joining to the base. A JoinAssociation may result in more than one actual join
      # operations (for example a has_and_belongs_to_many JoinAssociation would result in
      # two; one for the join table and one for the target table).
      class JoinPart # :nodoc:
        include Enumerable

        # The Active Record class which this join part is associated 'about'; for a JoinBase
        # this is the actual base model, for a JoinAssociation this is the target model of the
        # association.
        attr_reader :base_klass, :children

        delegate :table_name, :column_names, :primary_key, :attribute_types, to: :base_klass

        def initialize(base_klass, children)
          @base_klass = base_klass
          @children = children
        end

        def match?(other)
          self.class == other.class
        end

        def each(&block)
          yield self
          children.each { |child| child.each(&block) }
        end

        def each_children(&block)
          children.each do |child|
            yield self, child
            child.each_children(&block)
          end
        end

        # An Arel::Table for the active_record
        def table
          raise NotImplementedError
        end

        def instantiate(row, column_types = {}, &block)
          base_klass.instantiate(row, column_types, &block)
        end
      end
    end
  end
end
