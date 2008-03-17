require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Order do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#qualify' do
      it "descends" do
        Order.new(@relation, @attribute).qualify. \
          should == Order.new(@relation, @attribute).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes a block over the relation and attributes" do
        Order.new(@relation, @attribute).descend(&:qualify). \
          should == Order.new(@relation.descend(&:qualify), @attribute.qualify)
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
          @string = "asdf".bind(@relation)
        end
        
        it "passes the string through to the order clause" do
          Order.new(@relation, @string).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            ORDER BY asdf
          ")
        end
      end
    end
  end
end
  