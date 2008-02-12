require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Order do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#qualify' do
      it "distributes over the relation and attributes" do
        Order.new(@relation, @attribute).qualify. \
          should == Order.new(@relation.qualify, @attribute.qualify)
      end
    end
  
    describe '#to_sql' do
      it "manufactures sql with an order clause" do
        Order.new(@relation, @attribute).to_sql.should be_like("""
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          ORDER BY `users`.`id`
        """)
      end
    end
  end
end
  