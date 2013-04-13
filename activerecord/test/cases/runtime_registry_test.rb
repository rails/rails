require 'cases/helper'

class RuntimeRegistryTest < ActiveRecord::TestCase
  def setup
    @instance = ActiveRecord::RuntimeRegistry.instance
  end

  def teardown
    # Reset the runtime registry
    Thread.current["ActiveRecord::RuntimeRegistry"] = ActiveRecord::RuntimeRegistry.new
  end

  def test_runtime_registry_stored_as_thread_local
    local_runtime_registry = Thread.current["ActiveRecord::RuntimeRegistry"]

    assert_not_nil local_runtime_registry
    assert_equal @instance, local_runtime_registry
  end

  def test_runtime_registry_variable_handling
    connection = "some_crazy_connection"
    @instance.connection_handler = connection

    assert_not_nil @instance.connection_handler
    assert_not_nil ActiveRecord::RuntimeRegistry.connection_handler
    assert_equal @instance.connection_handler, connection
    assert_equal ActiveRecord::RuntimeRegistry.connection_handler, connection
  end

  def test_saving_and_restoring_variables
    old_connection = "some_old_childhood_friend"
    @instance.connection_handler = old_connection

    assert_equal old_connection, @instance.save(:connection_handler)
    assert_nil @instance.connection_handler

    new_connection = "some_new_friend"
    @instance.connection_handler = new_connection

    assert_equal new_connection, @instance.connection_handler
    assert_equal old_connection, @instance.restore(:connection_handler)
    assert_equal old_connection, @instance.connection_handler
  end

  def test_save_overwrites_previous_saved_value
    old_connection = "I like to move it move it"
    @instance.connection_handler = old_connection
    assert_equal old_connection, @instance.save(:connection_handler)

    new_connection = "It's the eye of the tiger"
    @instance.connection_handler = new_connection
    assert_equal new_connection, @instance.save(:connection_handler)
    assert_nil @instance.connection_handler

    assert_equal new_connection, @instance.restore(:connection_handler)
    assert_equal new_connection, @instance.connection_handler
  end

  def test_restore_without_save_returns_nil
    assert_nil @instance.restore(:connection_handler)

    connection = "Don't stop me now"
    @instance.connection_handler = connection
    assert_nil @instance.restore(:connection_handler)
  end

  def test_available_queries_for_explain_is_an_array_after_save_and_restore
    assert @instance.available_queries_for_explain.kind_of?(Array)
    @instance.save(:available_queries_for_explain)

    assert @instance.available_queries_for_explain.kind_of?(Array)
    @instance.restore(:available_queries_for_explain)

    assert @instance.available_queries_for_explain.kind_of?(Array)
  end
end
