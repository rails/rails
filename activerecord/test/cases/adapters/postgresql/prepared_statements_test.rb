require "cases/helper"
require "models/computer"
require "models/developer"

class PreparedStatementsTest < ActiveRecord::PostgreSQLTestCase
  fixtures :developers

  def setup
    @default_prepared_statements = ActiveRecord::Base.connection.instance_variable_get("@prepared_statements")
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", false)
  end

  def teardown
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", @default_prepared_statements)
  end

  def test_nothing_raised_with_falsy_prepared_statements
    assert_nothing_raised do
      Developer.where(id: 1)
    end
  end
end
