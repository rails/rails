require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe TableRelation do
  before do
    @relation = TableRelation.new(:users)
  end
  
  describe '#to_sql' do
    it "returns a simple SELECT query" do
      @relation.to_sql.should be_like("""
        SELECT `users`.`name`, `users`.`id`
        FROM `users`
      """)
    end
  end
  
  describe '#attributes' do
    it 'manufactures attributes corresponding to columns in the table' do
      pending
    end
  end
  
  describe '#qualify' do
    it 'manufactures a rename relation with all attribute names qualified' do
      @relation.qualify.should == RenameRelation.new(
        RenameRelation.new(@relation, @relation[:id] => 'users.id'), @relation[:name] => 'users.name'
      )
    end
  end
end