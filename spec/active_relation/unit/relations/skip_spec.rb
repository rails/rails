require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Skip do
    before do
      @relation = Table.new(:users)
      @skipped = 4
    end

    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        Skip.new(@relation, @skipped).to_s.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
          OFFSET #{@skipped}
        ")
      end
    end
  end
end