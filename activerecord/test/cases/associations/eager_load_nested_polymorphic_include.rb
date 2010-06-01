require 'cases/helper'
require 'models/tee'
require 'models/tie'
require 'models/polymorphic_design'
require 'models/polymorphic_price'

class EagerLoadNestedPolymorphicIncludeTest < ActiveRecord::TestCase
  fixtures :tees, :ties, :polymorphic_designs, :polymorphic_prices

  def test_eager_load_polymorphic_has_one_nested_under_polymorphic_belongs_to
    designs = PolymorphicDesign.scoped(:include => {:designable => :polymorphic_price})

    associated_price_ids = designs.map{|design| design.designable.polymorphic_price.id}
    expected_price_ids = [1, 2, 3, 4]

    assert expected_price_ids.all?{|expected_id| associated_price_ids.include?(expected_id)},
      "Expected associated prices to be #{expected_price_ids.inspect} but they were #{associated_price_ids.sort.inspect}"
  end
end
