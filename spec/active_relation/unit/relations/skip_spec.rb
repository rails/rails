require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Skip do
    before do
      @relation = Table.new(:users)
      @skipped = 4
    end

    describe '#qualify' do
      it "descends" do
        Skip.new(@relation, @skipped).qualify.should == Skip.new(@relation, @skipped).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation" do
        Skip.new(@relation, @skipped).descend(&:qualify).should == Skip.new(@relation.descend(&:qualify), @skipped)
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Skip.new(@relation, @skipped).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          OFFSET #{@skipped}
        ")
      end
    end
  end
end