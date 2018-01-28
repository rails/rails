# frozen_string_literal: true

module ActiveRecord
  class Relation
    class WhereClauseFactory # :nodoc:
      DOT = ".".freeze

      class ArelClause
        def initialize(arel_node)
          @arel_node = arel_node
        end

        def references
          []
        end

        def predicates
          [@arel_node]
        end
      end

      class ArrayClause
        def initialize(where_array, klass)
          @where_array = where_array
          @klass = klass
        end

        def references
          []
        end

        def predicates
          [@klass.sanitize_sql(@where_array)]
        end
      end

      class HashClause
        def initialize(where_hash, klass, predicate_builder)
          @where_hash = where_hash
          @klass = klass
          @predicate_builder = predicate_builder
        end

        def references
          attributes.select { |_, v| Hash === v }.keys
        end

        def predicates
          @predicate_builder.build_from_hash(attributes)
        end

        private

          def attributes
            @attributes ||= build_attributes_from_where_hash
          end

          def build_attributes_from_where_hash
            attributes = @predicate_builder.resolve_column_aliases(@where_hash)
            attributes = @klass.send(:expand_hash_conditions_for_aggregates, attributes)
            attributes.stringify_keys!

            convert_dot_notation_to_hash!(attributes)
          end

          def convert_dot_notation_to_hash!(attributes)
            dot_notation = attributes.select do |k, v|
              k.include?(DOT) && !v.is_a?(Hash)
            end

            dot_notation.each_key do |key|
              table_name, column_name = key.split(DOT)
              value = attributes.delete(key)
              attributes[table_name] ||= {}

              attributes[table_name] = attributes[table_name].merge(column_name => value)
            end

            attributes
          end
      end

      def initialize(klass, predicate_builder)
        @klass = klass
        @predicate_builder = predicate_builder
      end

      def build(opts, other)
        clause =
          case opts
          when String, Array
            all_opts = other.empty? ? opts : ([opts] + other)
            ArrayClause.new(all_opts, @klass)
          when Hash
            HashClause.new(opts, @klass, @predicate_builder)
          when Arel::Nodes::Node
            ArelClause.new(opts)
          else
            raise ArgumentError, "Unsupported argument type: #{opts} (#{opts.class})"
          end

        [WhereClause.new(clause.predicates), clause.references]
      end
    end
  end
end
