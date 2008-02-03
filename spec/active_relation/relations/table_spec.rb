require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Table do
    before do
      @relation = Table.new(:users)
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          @relation[:id].should == Attribute.new(@relation, :id)
          @relation[:does_not_exist].should be_nil
        end
      end

      describe 'when given an', Attribute do
        it "returns the attribute if the attribute is within the relation" do
          @relation[Attribute.new(@relation, :id)].should == Attribute.new(@relation, :id)
          @relation[Attribute.new(another_relation = Table.new(:photos), :id)].should be_nil
        end
      end
      
      describe 'when given an', Expression do
        before do
          @expression = Expression.new(Attribute.new(@relation, :id), "COUNT")
        end
        
        it "returns the Expression if the Expression is within the relation" do
          @relation[@expression].should be_nil
        end
      end
    end
    
    describe '#to_sql' do
      it "manufactures a simple select query" do
        @relation.to_sql.should be_like("""
          SELECT `users`.`name`, `users`.`id`
          FROM `users`
        """)
      end
    end
  
    describe '#attributes' do
      it 'manufactures attributes corresponding to columns in the table' do
        @relation.attributes.should == [
          Attribute.new(@relation, :name),
          Attribute.new(@relation, :id)
        ]
      end
    end
  
    describe '#qualify' do
      it 'manufactures a rename relation with all attribute names qualified' do
        @relation.qualify.should == Rename.new(@relation, @relation[:id] => 'users.id', @relation[:name] => 'users.name')
      end
    end
  end
end