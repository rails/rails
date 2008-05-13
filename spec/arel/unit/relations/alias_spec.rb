require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Alias do
    before do
      @relation = Table.new(:users)
    end
    
    describe '==' do
      it "obtains if the objects are the same" do
        Alias.new(@relation).should_not == Alias.new(@relation)
        (aliaz = Alias.new(@relation)).should == aliaz
      end
      
      it '' do
        @relation.select(@relation[:id].eq(1)).to_sql.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          WHERE
            `users`.`id` = 1
        ")
      end
    end
  end
end