require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Table do
    before do
      @relation = Table.new(:users)
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
        pending
      end
    end
  
    describe '#qualify' do
      it 'manufactures a rename relation with all attribute names qualified' do
        @relation.qualify.should == Rename.new(
          Rename.new(@relation, @relation[:id] => 'users.id'), @relation[:name] => 'users.name'
        )
      end
    end
  end
end