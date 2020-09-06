# frozen_string_literal: true

require 'cases/helper'

class LintTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class CompliantModel
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def persisted?() false end

    def errors
      Hash.new([])
    end
  end

  def setup
    @model = CompliantModel.new
  end
end
