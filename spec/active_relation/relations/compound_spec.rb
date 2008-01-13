require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Compound do
  before do
    @relation = ActiveRelation::Relations::Table.new(:users)
    
    class ConcreteCompound < ActiveRelation::Relations::Compound
      def initialize(relation)
        @relation = relation
      end
    end
  end
end