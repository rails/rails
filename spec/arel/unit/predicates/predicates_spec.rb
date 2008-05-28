require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Predicate do
    before do
      @relation = Table.new(:users)
      @attribute1 = @relation[:id]
      @attribute2 = @relation[:name]
      @operand1 = Equality.new(@attribute1, 1)
      @operand2 = Equality.new(@attribute2, "name")
    end
    
    describe "when being combined with another predicate with AND logic" do
      describe "#to_sql" do
        it "manufactures sql with an AND operation" do
          @operand1.and(@operand2).to_sql.should be_like("
            (`users`.`id` = 1 AND `users`.`name` = 'name')
          ")
        end
      end
    end
    
    describe "when being combined with another predicate with OR logic" do
      describe "#to_sql" do
        it "manufactures sql with an OR operation" do
          @operand1.or(@operand2).to_sql.should be_like("
            (`users`.`id` = 1 OR `users`.`name` = 'name')
          ")
        end
      end
    end
  end
end