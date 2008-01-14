require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Compound do
    before do
      @relation = Table.new(:users)
    
      class ConcreteCompound < Compound
        def initialize(relation)
          @relation = relation
        end
      end
    end
  end
end