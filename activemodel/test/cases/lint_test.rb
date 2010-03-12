require 'cases/helper'

class LintTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class CompliantModel
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def valid?()      true end
    def persisted?() false end

    def errors
      obj = Object.new
      def obj.[](key)         [] end
      def obj.full_messages() [] end
      obj
    end
  end

  def setup
    @model = CompliantModel.new
  end
end
