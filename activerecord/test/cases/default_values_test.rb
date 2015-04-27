require 'cases/helper'

module ActiveRecord
  class Company < ActiveRecord::Base;end

  class DefaultValuesTest < ActiveRecord::TestCase
    test "persists default user value to database" do
      UniverseCompany = Class.new(Company) do
        attribute :rating, :integer, default: 42
      end

      record = UniverseCompany.create!

      assert_equal 42, record.rating

      record.reload
      assert_equal 42, record.rating

      assert_equal 42, UniverseCompany.last.rating
    end

    test "persists default column value to database" do
      data = Company.create!

      assert_equal 1, data.rating

      data.reload
      assert_equal 1, data.rating
    end
  end
end
