require "cases/helper"

class LintTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class CompliantModel
    extend ActiveModel::Naming

    def to_model
      self
    end

    def key
      new_record? ? nil : [1]
    end

    def to_param
      key ? key.first.to_s : nil
    end

    def valid?()      true end
    def new_record?() true end
    def destroyed?()  true end

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
