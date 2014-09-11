require "cases/helper"
require "cases/view_test"

if ActiveRecord::Base.connection.supports_materialized_views?
class MaterializedViewTest < ActiveRecord::TestCase
  include ViewBehavior

  private
  def create_view(name, query)
    @connection.execute "CREATE MATERIALIZED VIEW #{name} AS #{query}"
  end

  def drop_view(name)
    @connection.execute "DROP MATERIALIZED VIEW #{name}" if @connection.table_exists? name

  end
end
end
