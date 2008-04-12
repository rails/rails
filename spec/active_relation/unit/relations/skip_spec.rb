require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Skip do
    before do
      @relation = Table.new(:users)
      @skip = 4
    end

    describe '#qualify' do
      it "descends" do
        Skip.new(@relation, @skip).qualify.should == Skip.new(@relation, @skip).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation" do
        Skip.new(@relation, @skip).descend(&:qualify).should == Skip.new(@relation.descend(&:qualify), @skip)
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Skip.new(@relation, @skip).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          OFFSET #{@skip}
        ")
      end
    end
  end
end