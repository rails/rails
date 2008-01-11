require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Insertion do
  before do
    @relation = ActiveRelation::Relations::Table.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql inserting the data for one item' do
      ActiveRelation::Relations::Insertion.new(@relation, @relation[:name] => "nick").to_sql.should be_like("""
        INSERT
        INTO `users`
        (`users`.`name`) VALUES ('nick')
      """)
    end
    
    it 'manufactures sql inserting the data for multiple items' do
      nested_insertion = ActiveRelation::Relations::Insertion.new(@relation, @relation[:name] => "cobra")
      ActiveRelation::Relations::Insertion.new(nested_insertion, nested_insertion[:name] => "commander").to_sql.should be_like("""
        INSERT
        INTO `users`
        (`users`.`name`) VALUES ('cobra'), ('commander')
      """)
    end
  end
end