require "cases/helper"

class DirtyTest < ActiveModel::TestCase
  class DirtyModel
    include ActiveModel::Dirty
    define_attribute_methods [:name]

    def initialize
      super
      @name = nil
    end

    def name
      @name
    end

    def name=(val)
      name_will_change!
      @name = val
    end
  end

  test "changes accessible through both strings and symbols" do
    model = DirtyModel.new
    model.name = "David"
    assert !model.changes[:name].nil?
    assert !model.changes['name'].nil?
  end

end
