# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/project"
require "models/developer"
require "models/computer"
require "models/company_in_module"

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

  def test_extension_with_dirty_target
    comment = posts(:welcome).comments.build(body: "New comment")
    assert_equal comment, posts(:welcome).comments.with_content("New comment")
  end

  def test_marshalling_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects.find_most_recent

    marshalled = Marshal.dump(david)

    # Marshaling an association shouldn't make it unusable by wiping its reflection.
    assert_not_nil david.association(:projects).reflection

    david_too = Marshal.load(marshalled)
    assert_equal projects(:action_controller), david_too.projects.find_most_recent
  end

  def test_marshalling_named_extensions
    david = developers(:david)
    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent

    marshalled = Marshal.dump(david)
    david      = Marshal.load(marshalled)

    assert_equal projects(:action_controller), david.projects_extended_by_name.find_most_recent
  end

  def test_extension_name
    extend!(Developer)
    extend!(MyApplication::Business::Developer)

    assert Object.const_get "DeveloperAssociationNameAssociationExtension"
    assert MyApplication::Business.const_get "DeveloperAssociationNameAssociationExtension"
  end

  def test_proxy_association_after_scoped
    post = posts(:welcome)
    assert_equal post.association(:comments), post.comments.the_association
    assert_equal post.association(:comments), post.comments.where("1=1").the_association
  end

  def test_association_with_default_scope
    assert_raises OopsError do
      posts(:welcome).comments.destroy_all
    end
  end

  private

    def extend!(model)
      ActiveRecord::Associations::Builder::HasMany.define_extensions(model, :association_name) { }
    end
end
