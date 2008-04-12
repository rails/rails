require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Take do
    before do
      @relation = Table.new(:users)
      @take = 4
    end

    describe '#qualify' do
      it "descends" do
        Take.new(@relation, @take).qualify.should == Take.new(@relation, @take).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation" do
        Take.new(@relation, @take).descend(&:qualify).should == Take.new(@relation.descend(&:qualify), @take)
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Take.new(@relation, @take).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          LIMIT #{@take}
        ")
      end
    end
  end
end