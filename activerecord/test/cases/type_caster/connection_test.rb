# frozen_string_literal: true

require "cases/helper"
require "models/developer"

module ActiveRecord
  module TypeCaster
    class ConnectionTest < ActiveSupport::TestCase
      test "#type_for_attribute is not aware of custom types" do
        type_caster = Connection.new(AttributedDeveloper, "developers")

        type = type_caster.type_for_attribute(:name)

        assert_not_equal DeveloperName, type.class
        assert_equal ActiveRecord::Type::String, type.class
      end
    end
  end
end
