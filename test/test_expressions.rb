require 'helper'

module Arel
  describe "Expressions" do
    before do
      @table = Table.new(:users)
    end

    describe "average" do
      it "aliases the average as avg_id by default" do
        @table[:score].average.to_sql.must_be_like %{
          AVG("users"."score") AS avg_id
        }
      end

      it "aliases the average as another string" do
        @table[:score].average("my_alias").to_sql.must_be_like %{
          AVG("users"."score") AS my_alias
        }
      end

      it "omits the alias if nil" do
        @table[:score].average(nil).to_sql.must_be_like %{
          AVG("users"."score")
        }
      end
    end
  end
end
