require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Range do
    before do
      @relation = Table.new(:users)
      @range = 4..9
    end

    describe '#qualify' do
      it "descends" do
        Range.new(@relation, @range).qualify.should == Range.new(@relation, @range).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation" do
        Range.new(@relation, @range).descend(&:qualify).should == Range.new(@relation.descend(&:qualify), @range)
      end
    end
    
    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        range_size = @range.last - @range.first + 1
        range_start = @range.first
        Range.new(@relation, @range).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          LIMIT #{range_size}
          OFFSET #{range_start}
        ")
      end
    end
  end
end