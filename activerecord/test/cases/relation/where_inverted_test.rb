require "cases/helper"
require "models/cake_designer"
require "models/drink_designer"
require "models/chef"

module ActiveRecord
  class WhereInvertedTest < ActiveRecord::TestCase
    test "test inverted with polymorphic value" do
      chef1 = Chef.create!
      chef2 = Chef.create!
      chef3 = Chef.create!

      cake_designer = CakeDesigner.create!(chef: chef1)
      CakeDesigner.create!(chef: chef2)
      DrinkDesigner.create!(chef: chef3)

      chefs = Chef.where.not(employable: cake_designer)

      assert_not_includes chefs, chef1
      assert_includes chefs, chef2
      assert_includes chefs, chef3
    end

    test "test inverted with array of polymorphic values of different type" do
      chef1 = Chef.create!
      chef2 = Chef.create!
      chef3 = Chef.create!
      chef4 = Chef.create!

      cake_designer = CakeDesigner.create!(chef: chef1)
      drink_designer = DrinkDesigner.create!(chef: chef2)
      CakeDesigner.create!(chef: chef3)
      DrinkDesigner.create!(chef: chef4)

      chefs = Chef.where.not(employable: [cake_designer, drink_designer])

      assert_not_includes chefs, chef1
      assert_not_includes chefs, chef2
      assert_includes chefs, chef3
      assert_includes chefs, chef4
    end

    test "test inverted with array of polymorphic values of the same type" do
      chef1 = Chef.create!
      chef2 = Chef.create!
      chef3 = Chef.create!
      chef4 = Chef.create!

      cake_designer1 = CakeDesigner.create!(chef: chef1)
      cake_designer2 = CakeDesigner.create!(chef: chef2)
      CakeDesigner.create!(chef: chef3)
      DrinkDesigner.create!(chef: chef4)

      chefs = Chef.where.not(employable: [cake_designer1, cake_designer2])

      assert_not_includes chefs, chef1
      assert_not_includes chefs, chef2
      assert_includes chefs, chef3
      assert_includes chefs, chef4
    end

    test "test inverted with array of polymorphic values of different and the same types" do
      chef1 = Chef.create!
      chef2 = Chef.create!
      chef3 = Chef.create!
      chef4 = Chef.create!

      cake_designer1 = CakeDesigner.create!(chef: chef1)
      cake_designer2 = CakeDesigner.create!(chef: chef2)
      drink_designer = DrinkDesigner.create!(chef: chef3)
      DrinkDesigner.create!(chef: chef4)

      chefs = Chef.where.not(employable: [cake_designer1, cake_designer2, drink_designer])

      assert_not_includes chefs, chef1
      assert_not_includes chefs, chef2
      assert_not_includes chefs, chef3
      assert_includes chefs, chef4
    end
  end
end
