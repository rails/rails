# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

class AdapterPreventWritesTest < ActiveRecord::AbstractMysqlTestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_errors_when_an_insert_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      assert_raises(ActiveRecord::ReadOnlyError) do
        @conn.insert("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")
      end
    end
  end

  def test_errors_when_an_update_query_is_called_while_preventing_writes
    @conn.insert("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_writes do
      assert_raises(ActiveRecord::ReadOnlyError) do
        @conn.update("UPDATE `engines` SET `engines`.`car_id` = '9989' WHERE `engines`.`car_id` = '138853948594'")
      end
    end
  end

  def test_errors_when_a_delete_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_writes do
      assert_raises(ActiveRecord::ReadOnlyError) do
        @conn.execute("DELETE FROM `engines` where `engines`.`car_id` = '138853948594'")
      end
    end
  end

  def test_errors_when_a_replace_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_writes do
      assert_raises(ActiveRecord::ReadOnlyError) do
        @conn.execute("REPLACE INTO `engines` SET `engines`.`car_id` = '249823948'")
      end
    end
  end

  def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_writes do
      assert_equal 1, @conn.execute("SELECT `engines`.* FROM `engines` WHERE `engines`.`car_id` = '138853948594'").entries.count
    end
  end

  def test_doesnt_error_when_a_show_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      assert_equal 2, @conn.execute("SHOW FULL FIELDS FROM `engines`").entries.count
    end
  end

  def test_doesnt_error_when_a_set_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      assert_nothing_raised { @conn.execute("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci") }
    end
  end

  def test_doesnt_error_when_a_describe_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      assert_equal 2, @conn.execute("DESCRIBE engines").entries.count
    end
  end

  def test_doesnt_error_when_a_desc_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      assert_equal 2, @conn.execute("DESC engines").entries.count
    end
  end

  def test_doesnt_error_when_a_read_query_with_leading_chars_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    ActiveRecord::Base.while_preventing_writes do
      assert_equal 1, @conn.execute("/*action:index*/(\n( SELECT `engines`.* FROM `engines` WHERE `engines`.`car_id` = '138853948594' ) )").entries.count
    end
  end

  def test_doesnt_error_when_a_use_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      db_name = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").database
      assert_nothing_raised { @conn.execute("USE #{db_name}") }
    end
  end

  def test_doesnt_error_when_a_kill_query_is_called_while_preventing_writes
    ActiveRecord::Base.while_preventing_writes do
      conn_id = @conn.execute("SELECT CONNECTION_ID() as connection_id").to_a[0][0]
      assert_raises(ActiveRecord::QueryCanceled) do
        @conn.execute("KILL QUERY #{conn_id}")
      end
    end
  end

  private
    def with_example_table(definition = "id int auto_increment primary key, number int, data varchar(255)", &block)
      super(@conn, "ex", definition, &block)
    end
end
