require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe InsertionRelation do
  before do
    @relation = TableRelation.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql inserting the data for one item' do
      InsertionRelation.new(@relation, @relation[:name] => "nick").to_sql.should == InsertBuilder.new do
        insert
        into :users
        columns do
          column :users, :name
        end
        values do
          row "nick"
        end
      end
    end
    
    it 'manufactures sql inserting the data for multiple items' do
      nested_insertion = InsertionRelation.new(@relation, @relation[:name] => "cobra")
      InsertionRelation.new(nested_insertion, nested_insertion[:name] => "commander").to_sql.to_s.should == InsertBuilder.new do
        insert
        into :users
        columns do
          column :users, :name
        end
        values do
          row "cobra"
          row "commander"
        end
      end.to_s
    end
  end
end