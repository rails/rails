require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Selection do
    before do
      @relation = Table.new(:users)
      @predicate = Equality.new(@relation[:id], 1)
    end
  
    describe '#initialize' do
      it "manufactures nested selection relations if multiple predicates are provided" do
        @predicate2 = LessThan.new(@relation[:age], 2)
        Selection.new(@relation, @predicate, @predicate2). \
          should == Selection.new(Selection.new(@relation, @predicate2), @predicate)
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and predicates" do
        Selection.new(@relation, @predicate).qualify. \
          should == Selection.new(@relation.qualify, @predicate.qualify)
      end
    end
  
    describe '#to_sql' do
      it "manufactures sql with where clause conditions" do
        Selection.new(@relation, @predicate).to_sql.should be_like("""
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          WHERE `users`.`id` = 1
        """)
      end
    
      it "allows arbitrary sql" do
        Selection.new(@relation, "asdf").to_sql.should be_like("""
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          WHERE asdf
        """)
      end
    end
  end
end