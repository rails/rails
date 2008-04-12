require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Take do
    before do
      @relation = Table.new(:users)
      @taken = 4
    end

    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Take.new(@relation, @taken).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          LIMIT #{@taken}
        ")
      end
    end
  end
end