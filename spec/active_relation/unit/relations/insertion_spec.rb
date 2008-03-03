require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Insertion do
    before do
      @relation = Table.new(:users)
    end
  
    describe '#to_sql' do
      it 'manufactures sql inserting the data for one item' do
        Insertion.new(@relation, @relation[:name] => "nick".bind(@relation)).to_sql.should be_like("
          INSERT
          INTO `users`
          (`users`.`name`) VALUES ('nick')
        ")
      end
    end
  end
end