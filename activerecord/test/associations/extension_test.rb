require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/project'
require 'fixtures/developer'

class AssociationsExtensionsTest < Test::Unit::TestCase
  fixtures :projects, :developers, :developers_projects, :comments, :posts

  def test_extension_on_has_many
    assert_equal comments(:more_greetings), posts(:welcome).comments.find_most_recent
  end
  
  def test_extension_on_habtm
    assert_equal projects(:action_controller), developers(:david).projects.find_most_recent
  end

  def test_named_extension_on_habtm
    assert_equal projects(:action_controller), developers(:david).projects_extended_by_name.find_most_recent
  end

  def test_named_two_extensions_on_habtm
    assert_equal projects(:action_controller), developers(:david).projects_extended_by_name_twice.find_most_recent
    assert_equal projects(:active_record), developers(:david).projects_extended_by_name_twice.find_least_recent
  end

  def test_named_extension_and_block_on_habtm
    assert_equal projects(:action_controller), developers(:david).projects_extended_by_name_and_block.find_most_recent
    assert_equal projects(:active_record), developers(:david).projects_extended_by_name_and_block.find_least_recent
  end

  def test_marshalling_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects.find_most_recent

    david = Marshal.load(Marshal.dump(david))
    assert_equal projects(:action_controller), david.projects.find_most_recent
  end

  def test_marshalling_named_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent

    david = Marshal.load(Marshal.dump(david))
    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent
  end
end