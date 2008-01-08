require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe DeletionRelation do
  before do
    @relation = TableRelation.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql deleting the relation' do
      DeletionRelation.new(@relation.select(@relation[:id] == 1)).to_sql.to_s.should == DeleteBuilder.new do
        delete
        from :users
        where do
          equals do
            column :users, :id
            value 1
          end
        end
      end.to_s
    end
  end
end