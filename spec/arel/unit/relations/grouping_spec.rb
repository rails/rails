require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Grouping do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end
    
    describe '#to_sql' do
      describe 'when given a predicate' do
        it "manufactures sql with where clause conditions" do
          Grouping.new(@relation, @attribute).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            GROUP BY `users`.`id`
          ")
        end
      end
      
      describe 'when given a string' do
        it "passes the string through to the where clause" do
          pending 'it should not quote the group clause'
          Grouping.new(@relation, 'asdf').to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            GROUP BY asdf
          ")
        end
      end
    end
  end
end