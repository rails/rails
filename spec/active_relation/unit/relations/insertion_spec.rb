require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Insertion do
    before do
      @relation = Table.new(:users)
      @insertion = Insertion.new(@relation, @relation[:name] => "nick".bind(@relation))
    end
  
    describe '#to_sql' do
      it 'manufactures sql inserting the data for one item' do
        @insertion.to_sql.should be_like("
          INSERT
          INTO `users`
          (`users`.`name`) VALUES ('nick')
        ")
      end
    end
    
    describe '#call' do
      it 'executes an insert on the connection' do
        mock(connection = Object.new).insert(@insertion.to_sql)
        @insertion.call(connection)
      end
    end
  end
end