require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Table do
    before do
      @table = Table.new(:users)
      @relation2 = Table.new(:photos)
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          @table[:id].should == Attribute.new(@table, :id)
          @table[:does_not_exist].should be_nil
        end
      end

      describe 'when given an', Attribute do
        it "returns the attribute if the attribute is within the relation" do
          @table[@table[:id]].should == @table[:id]
        end
        
        it "returns nil if the attribtue is not within the relation" do
          another_relation = Table.new(:photos)
          @table[another_relation[:id]].should be_nil
        end
      end
      
      describe 'when given an', Expression do
        before do
          @expression = Expression.new(Attribute.new(@table, :id), "COUNT")
        end
        
        it "returns the Expression if the Expression is within the relation" do
          @table[@expression].should be_nil
        end
      end
    end
    
    describe '#to_sql' do
      it "manufactures a simple select query" do
        @table.to_sql.should be_like("""
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
        """)
      end
    end
    
    describe '#prefix_for' do
      it "returns the table name" do
        @table.prefix_for(Attribute.new(@table, :id)).should == :users
      end
    end
    
    describe '#aliased_prefix_for' do
      it "returns the table name" do
        @table.aliased_prefix_for(Attribute.new(@table, :id)).should == :users
      end
    end
  
    describe '#attributes' do
      it 'manufactures attributes corresponding to columns in the table' do
        @table.attributes.should == [
          Attribute.new(@table, :id),
          Attribute.new(@table, :name)
        ]
      end
    end
  
    describe '#qualify' do
      it 'manufactures a rename relation with all attribute names qualified' do
        @table.qualify.should == Rename.new(@table, @table[:name] => 'users.name', @table[:id] => 'users.id')
      end
    end
  end
end