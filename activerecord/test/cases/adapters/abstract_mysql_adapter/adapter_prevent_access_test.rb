# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

class AdapterPreventAccessTest < ActiveRecord::AbstractMysqlTestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_error_when_a_query_is_called_while_preventing_access
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_access do
      assert_raises(ActiveRecord::PreventedAccessError) do
        @conn.execute("SELECT `engines`.* FROM `engines` WHERE `engines`.`car_id` = '138853948594'")
      end
    end
  end
end
