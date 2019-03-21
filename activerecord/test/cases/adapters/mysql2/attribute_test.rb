# frozen_string_literal: true

require "cases/helper"

class Mysql2AttributeTest < ActiveRecord::Mysql2TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  test "precision for :datetime attribute is set to 0 by default" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "defaults"
      attribute :ends_at, :datetime
    end

    assert_equal 0, klass.type_for_attribute(:ends_at).precision
  end

  test "inferred datetime attribute has precision of zero rather than nil" do
    klass = Class.new(ActiveRecord::Base) do
      # this table has a created_at column without fractional second precision
      self.table_name = "ships"
    end

    assert_equal 0, klass.type_for_attribute(:created_at).precision
  end
end
