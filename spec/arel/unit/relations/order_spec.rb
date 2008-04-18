require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Order do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#initialize' do
      before do
        @another_attribtue = @relation[:name]
      end
      
      it "manufactures nested Order relations if multiple predicates are provided" do
        Order.new(@relation, @predicate, @another_attribute). \
          should == Order.new(Order.new(@relation, @another_attribute), @predicate)
      end
    end
    
    describe '#to_sql' do
      describe "when given an attribute" do
        it "manufactures sql with an order clause populated by the attribute" do
          Order.new(@relation, @attribute).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            ORDER BY `users`.`id`
          ")
        end
      end
      
      describe "when given multiple attributes" do
        before do
          @another_attribute = @relation[:name]
        end
        
        it "manufactures sql with an order clause populated by comma-separated attributes" do
          Order.new(@relation, @attribute, @another_attribute).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            ORDER BY `users`.`id`, `users`.`name`
          ")
        end
      end
      
      describe "when given a string" do
        before do
          @string = "asdf"
        end
        
        it "passes the string through to the order clause" do
          Order.new(@relation, @string).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            ORDER BY asdf
          ")
        end
      end
      
      describe "when ordering an ordered relation" do
        before do
          @ordered_relation = Order.new(@relation, @attribute)
          @another_attribute = @relation[:name]
        end
        
        it "manufactures sql with an order clause populated by comma-separated attributes" do
          Order.new(@ordered_relation, @another_attribute).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            ORDER BY `users`.`id`, `users`.`name`
          ")
        end
      end
    end
  end
end
  