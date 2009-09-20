require 'spec_helper'

module Arel
  describe Expression do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#to_sql' do
      it "manufactures sql with the expression and alias" do
        sql = Count.new(@attribute, :alias).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{COUNT(`users`.`id`) AS `alias`})
        end

        adapter_is_not :mysql do
          sql.should be_like(%Q{COUNT("users"."id") AS "alias"})
        end
      end
    end
  end
end
