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
        @compound_relation.attributes.should == @relation.attributes.collect { |a| a.substitute(@compound_relation) }
      end
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it 'manufactures attributes associated with the compound relation if the symbol names an attribute within the relation' do
          @compound_relation[:id].should == @relation[:id].substitute(@compound_relation)
          @compound_relation[:does_not_exist].should be_nil
        end
      end
      
      describe 'when given an', Attribute do
        it "manufactures a substituted attribute when given an attribute within the relation" do
          @compound_relation[@relation[:id]].should == @relation[:id].substitute(@compound_relation)
          @compound_relation[@compound_relation[:id]].should == @compound_relation[:id]
          pending "test nil"
        end
      end
      
      describe 'when given an', Expression do
        before do
          @nested_expression = Expression.new(Attribute.new(@relation, :id), "COUNT")
          @nested_relation = Aggregation.new(@relation, :expressions => [@nested_expression])
          @unprojected_expression = Expression.new(Attribute.new(@relation, :id), "SUM")
          @compound_relation = ConcreteCompound.new(@nested_relation)
        end
        
        it "manufactures a substituted Expression when given an Expression within the relation" do
          @compound_relation[@nested_expression].should == @nested_relation[@nested_expression].substitute(@compound_relation)
          @compound_relation[@compound_relation[@expression]].should == @compound_relation[@expression]
          @compound_relation[@unprojected_expression].should be_nil
        end
      end
    end
  end
end