module ActiveRelation
  module Relations
    class Rename < Compound
      attr_reader :schmattribute, :rename
  
      def initialize(relation, renames)
        @schmattribute, @rename = renames.shift
        @relation = renames.empty?? relation : Rename.new(relation, renames)
      end
  
      def ==(other)
        relation == other.relation and schmattribute == other.schmattribute and self.rename == other.rename
      end
  
      def attributes
        relation.attributes.collect { |a| substitute(a) }
      end
  
      def qualify
        Rename.new(relation.qualify, schmattribute.qualify => self.rename)
      end
  
      protected
      def attribute(name)
        case
        when name == self.rename then schmattribute.as(self.rename)
        when relation[name] == schmattribute then nil
        else relation[name]
        end
      end
  
      private
      def substitute(a)
        a == schmattribute ? a.as(self.rename) : a
      end
    end
  end
end