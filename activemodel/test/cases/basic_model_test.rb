require 'cases/helper'

class ModelTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class BasicModel
    include ActiveModel::BasicModel
    attr_accessor :attr
  end

  def setup
    @model = BasicModel.new
  end
end
