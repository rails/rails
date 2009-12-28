require 'spec_helper'

module Arel
  describe Having do
    before do
      @relation = Table.new(:developers)
    end

    describe '#to_sql' do
      describe 'when given a predicate' do
        it "manufactures sql with where clause conditions" do
          sql = @relation.group(@relation[:department]).having("MIN(salary) > 1000").to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `developers`.`id`, `developers`.`name`, `developers`.`salary`, `developers`.`department`
              FROM `developers`
              GROUP BY `developers`.`department`
              HAVING MIN(salary) > 1000
            })
          end

          adapter_is_not :mysql do
            sql.should be_like(%Q{
              SELECT "developers"."id", "developers"."name", "developers"."salary", "developers"."department"
              FROM "developers"
              GROUP BY "developers"."department"
              HAVING MIN(salary) > 1000
            })
          end
        end
      end
    end
  end
end

