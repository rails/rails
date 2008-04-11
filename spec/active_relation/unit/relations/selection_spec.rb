require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Selection do
    before do
      @relation = Table.new(:users)
      @predicate = @relation[:id].eq(1)
    end
  
    describe '#initialize' do
      before do
        @another_predicate = @relation[:name].lt(2)
      end
      
      it "manufactures nested selection relations if multiple predicates are provided" do
        Selection.new(@relation, @predicate, @another_predicate). \
          should == Selection.new(Selection.new(@relation, @another_predicate), @predicate)
      end
    end
  
    describe '#qualify' do
      it "descends" do
        Selection.new(@relation, @predicate).qualify. \
          should == Selection.new(@relation, @predicate).descend(&:qualify)
      end
    end

    describe '#descend' do
      before do
        @selection = Selection.new(@relation, @predicate)
      end
      
      it "distributes a block over the relation and predicates" do
        @selection.descend(&:qualify). \
          should == Selection.new(@selection.relation.descend(&:qualify), @selection.predicate.qualify)
      end
    end
  
    describe '#to_sql' do
      describe 'when given a predicate' do
        it "manufactures sql with where clause conditions" do
          Selection.new(@relation, @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            WHERE `users`.`id` = 1
          ")
        end
      end
      
      describe 'when given a string' do
        before do
          @string = "asdf"
        end
        
        it "passes the string through to the where clause" do
          Selection.new(@relation, @string).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            WHERE asdf
          ")
        end
      end
    end
  end
end