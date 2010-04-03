module Arel
  module Relation
    attr_reader :count

    def session
      Session.new
    end

    def call
      engine.read(self)
    end

    def bind(relation)
      self
    end

    module Enumerable
      include ::Enumerable

      def each(&block)
        session.read(self).each(&block)
      end

      def first
        session.read(self).first
      end
    end
    include Enumerable

    module Operable
      def join(other_relation = nil, join_class = InnerJoin)
        case other_relation
        when String
          StringJoin.new(self, other_relation)
        when Relation
          JoinOperation.new(join_class, self, other_relation)
        else
          self
        end
      end

      def outer_join(other_relation = nil)
        join(other_relation, OuterJoin)
      end

      [:where, :project, :order, :take, :skip, :group, :from, :having].each do |operation_name|
        class_eval <<-OPERATION, __FILE__, __LINE__
          def #{operation_name}(*arguments, &block)
            arguments.all?(&:blank?) && !block_given?? self : #{operation_name.to_s.classify}.new(self, *arguments, &block)
          end
        OPERATION
      end

      def lock(locking = nil)
        Lock.new(self, locking)
      end

      def alias
        Alias.new(self)
      end

      module Writable
        def insert(record)
          session.create Insert.new(self, record)
        end

        def update(assignments)
          session.update Update.new(self, assignments)
        end

        def delete
          session.delete Deletion.new(self)
        end
      end
      include Writable

      JoinOperation = Struct.new(:join_class, :relation1, :relation2) do
        def on(*predicates)
          join_class.new(relation1, relation2, *predicates)
        end
      end
    end
    include Operable

    module AttributeAccessable
      def [](index)
        attributes[index]
      end

      def find_attribute_matching_name(name)
        attributes.detect { |a| a.named?(name) } || Attribute.new(self, name)
      end

      def find_attribute_matching_attribute(attribute)
        matching_attributes(attribute).max do |a1, a2|
          (a1.original_attribute / attribute) <=> (a2.original_attribute / attribute)
        end
      end

      def position_of(attribute)
        (@position_of ||= Hash.new do |h, attribute|
          h[attribute] = attributes.index(self[attribute])
        end)[attribute]
      end

      private
      def matching_attributes(attribute)
        (@matching_attributes ||= attributes.inject({}) do |hash, a|
          (hash[a.is_a?(Value) ? a.value : a.root] ||= []) << a
          hash
        end)[attribute.root] || []
      end

      def has_attribute?(attribute)
        !matching_attributes(attribute).empty?
      end
    end
    include AttributeAccessable

    module DefaultOperations
      def attributes;             Header.new  end
      def projections;            []          end
      def wheres;                 []          end
      def orders;                 []          end
      def inserts;                []          end
      def groupings;              []          end
      def havings;                []          end
      def joins(formatter = nil); nil         end # FIXME
      def taken;                  nil         end
      def skipped;                nil         end
      def sources;                []          end
      def locked;                 []          end
    end
    include DefaultOperations
  end
end
