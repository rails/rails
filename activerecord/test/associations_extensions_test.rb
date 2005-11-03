require 'abstract_unit'
require 'fixtures/project'
require 'fixtures/developer'

class AssociationsExtensionsTest < Test::Unit::TestCase
  fixtures :projects, :developers

  def test_extension_on_habtm
    assert_equal projects(:action_controller), developers(:david).projects.find_most_recent
  end
  
  def test_extension_on_has_many
    assert_equal comments(:more_greetings), posts(:welcome).comments.find_most_recent
  end
end