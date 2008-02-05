require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Expression do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end
    
    describe Expression::Transformations do
      before do
        @expression = Expression.new(@attribute, "COUNT")
      end
      
      describe '#substitute' do
        it "manufactures an attribute with a substituted relation and self as the ancestor" do
          derived_relation = @relation.select(@relation[:id] == 1)
          @expression.substitute(derived_relation).should == Expression.new(@attribute.substitute(derived_relation), "COUNT", nil, @expression)
        end
        
        it "returns self if the substituting to the same relation" do
          @expression.substitute(@relation).should == @expression
        end
      end
      
      describe '#as' do
        it "manufactures an aliased expression" do
          @expression.as(:foo).should == Expression.new(@attribute, "COUNT", :foo, @expression)
        end
      end
      
      describe '#to_attribute' do
        it "manufactures an attribute with the expression as an ancestor" do
          @expression.to_attribute.should == Attribute.new(@expression.relation, @expression.alias, nil, @expression)
        end
      end
    end
    
    describe '=~' do
      it "obtains if the expressions are identical" do
        Expression.new(@attribute, "COUNT").should =~ Expression.new(@attribute, "COUNT")
      end
      
      it "obtains if the expressions have an overlapping history" do
        Expression.new(@attribute, "COUNT", nil, Expression.new(@attribute, "COUNT")).should =~ Expression.new(@attribute, "COUNT")
        Expression.new(@attribute, "COUNT").should =~ Expression.new(@attribute, "COUNT", nil, Expression.new(@attribute, "COUNT"))  
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with the expression and alias" do
        Expression.new(@attribute, "COUNT", :alias).to_sql.should == "COUNT(`users`.`id`) AS `alias`"
      end
    end
  end
end