require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Compound do
    before do
      class ConcreteCompound < Compound
        def initialize(relation)
          @relation = relation
        end
      end
      @relation = Table.new(:users)
      @compound_relation = ConcreteCompound.new(@relation)
    end
    
    describe '#attributes' do
      it 'manufactures attributes associated with the compound relation' do
        @compound_relation.attributes.should == @relation.attributes.collect { |a| Attribute.new(@compound_relation, a.name) }
      end
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it 'manufactures attributes associated with the compound relation if the symbol names an attribute within the relation' do
          @compound_relation[:id].relation.should == @compound_relation
          @compound_relation[:does_not_exist].should be_nil
        end
      end
      
      describe 'when given an', Attribute do
        it "manufactures a substituted attribute when given an attribute within the relation" do
          @compound_relation[Attribute.new(@relation, :id)].should == Attribute.new(@compound_relation, :id)
          @compound_relation[Attribute.new(@compound_relation, :id)].should == Attribute.new(@compound_relation, :id)
          @compound_relation[Attribute.new(another_relation = Table.new(:photos), :id)].should be_nil
        end
      end
      
      describe 'when given an', Expression do
        before do
          @nested_expression = Expression.new(Attribute.new(@relation, :id), "COUNT")
          @unprojected_expression = Expression.new(Attribute.new(@relation, :id), "SUM")
          @compound_relation = ConcreteCompound.new(Aggregation.new(@relation, :expressions => [@nested_expression]))
        end
        
        it "manufactures a substituted Expression when given an Expression within the relation" do
          @compound_relation[@nested_expression].should == @nested_expression.substitute(@compound_relation)
          @compound_relation[@compound_relation[@expression]].should == @compound_relation[@expression]
          @compound_relation[@unprojected_expression].should be_nil
        end
      end
    end
  end
end