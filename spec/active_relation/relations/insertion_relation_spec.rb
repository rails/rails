require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe InsertionRelation do
  before do
    @relation = TableRelation.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql inserting the data for one item' do
      InsertionRelation.new(@relation, @relation[:name] => "nick").to_sql.should be_like("""
        INSERT
        INTO `users`
        (`users`.`name`) VALUES ('nick')
      """)
    end
    
    it 'manufactures sql inserting the data for multiple items' do
      nested_insertion = InsertionRelation.new(@relation, @relation[:name] => "cobra")
      InsertionRelation.new(nested_insertion, nested_insertion[:name] => "commander").to_sql.should be_like("""
        INSERT
        INTO `users`
        (`users`.`name`) VALUES ('cobra'), ('commander')
      """)
    end
  end
end