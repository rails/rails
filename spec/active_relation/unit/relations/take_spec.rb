require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Take do
    before do
      @relation = Table.new(:users)
      @takene = 4
    end

    describe '#qualify' do
      it "descends" do
        Take.new(@relation, @takene).qualify.should == Take.new(@relation, @takene).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation" do
        Take.new(@relation, @takene).descend(&:qualify).should == Take.new(@relation.descend(&:qualify), @takene)
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Take.new(@relation, @takene).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          LIMIT #{@takene}
        ")
      end
    end
  end
end