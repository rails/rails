require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/project'
require 'models/developer'
require 'models/company_in_module'

class AssociationsExtensionsTest < ActiveRecord::TestCase
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

  def test_extension_with_scopes
    assert_equal comments(:greetings), posts(:welcome).comments.offset(1).find_most_recent
    assert_equal comments(:greetings), posts(:welcome).comments.not_again.find_most_recent
  end

  def test_marshalling_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects.find_most_recent

    marshalled = Marshal.dump(david)
    david      = Marshal.load(marshalled)

    assert_equal projects(:action_controller), david.projects.find_most_recent
  end

  def test_marshalling_named_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent

    marshalled = Marshal.dump(david)
    david      = Marshal.load(marshalled)

    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent
  end

  def test_extension_name
    assert_equal 'DeveloperAssociationNameAssociationExtension', extension_name(Developer)
    assert_equal 'MyApplication::Business::DeveloperAssociationNameAssociationExtension', extension_name(MyApplication::Business::Developer)
    assert_equal 'MyApplication::Business::DeveloperAssociationNameAssociationExtension', extension_name(MyApplication::Business::Developer)
  end

  def test_proxy_association_after_scoped
    post = posts(:welcome)
    assert_equal post.association(:comments), post.comments.the_association
    assert_equal post.association(:comments), post.comments.where('1=1').the_association
  end

  private

    def extension_name(model)
      builder = ActiveRecord::Associations::Builder::HasMany.new(model, :association_name, nil, {}) { }
      builder.send(:wrap_block_extension)
      builder.extension_module.name
    end
end
