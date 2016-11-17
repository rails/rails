require "cases/helper"
require "models/developer"
require "models/computer"

class PreparedStatementsTest < ActiveRecord::Mysql2TestCase
  fixtures :developers

  def setup
    @default_prepared_statements = ActiveRecord::Base.connection.instance_variable_get("@prepared_statements")
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", true)
  end

  def teardown
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", @default_prepared_statements)
  end

  def test_nothing_raised_with_falsy_prepared_statements
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", false)
    assert_nothing_raised do
      Developer.first #With Binds
      Developer.count #Without Binds
    end
  end

  def test_nothing_raised_with_prepared_statements
    ActiveRecord::Base.connection.instance_variable_set("@prepared_statements", true)
    assert_nothing_raised do
      Developer.first #With Binds
      Developer.count #Without Binds
    end
  end
end
