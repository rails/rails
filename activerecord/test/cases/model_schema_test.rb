# frozen_string_literal: true

require "cases/helper"
require "models/minimalistic"

class ModelSchemaTest < ActiveRecord::TestCase
  test "#attributes_of_type returns attribute names for specified type" do
    model = Class.new(Minimalistic) do
      attribute :int, :integer
      attribute :str, :string
    end

    assert_equal [:id, :int].sort, model.attributes_of_type(:integer).sort
    assert_equal [:str], model.attributes_of_type(:string)
    assert_equal [], model.attributes_of_type(:decimal)
  end
end
