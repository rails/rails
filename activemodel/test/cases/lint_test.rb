require "cases/helper"

class LintTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests

  class CompliantModel
    extend ActiveModel::Naming

    def to_model
      self
    end

    def to_key
      new_record? ? nil : [id]
    end

    def to_param
      return nil if to_key.nil?
      # some default for CPKs, real implementations will differ
      to_key.length > 1 ? to_key.join('-') : to_key.first.to_s
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
