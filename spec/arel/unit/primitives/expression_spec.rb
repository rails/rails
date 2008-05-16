require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Expression do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end
    
    describe Expression::Transformations do
      before do
        @expression = Expression.new(@attribute, "COUNT")
      end
      
      describe '#bind' do
        it "manufactures an attribute with a rebound relation and self as the ancestor" do
          pending
          derived_relation = @relation.select(@relation[:id].eq(1))
          @expression.bind(derived_relation).should == Expression.new(@attribute.bind(derived_relation), "COUNT", nil, @expression)
        end
        
        it "returns self if the substituting to the same relation" do
          @expression.bind(@relation).should == @expression
        end
      end
      
      describe '#as' do
        it "manufactures an aliased expression" do
          @expression.as(:alias).should == Expression.new(@attribute, "COUNT", :alias, @expression)
        end
      end
      
      describe '#to_attribute' do
        it "manufactures an attribute with the expression as an ancestor" do
          @expression.to_attribute.should == Attribute.new(@expression.relation, @expression.alias, :ancestor => @expression)
        end
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with the expression and alias" do
        Expression.new(@attribute, "COUNT", :alias).to_sql.should == "COUNT(`users`.`id`) AS `alias`"
      end
    end
  end
end