# frozen_string_literal: true

require "test_helper"

class ActiveStorage::ReflectionTest < ActiveSupport::TestCase
  test "reflecting on a singular attachment" do
    reflection = User.reflect_on_attachment(:avatar)
    assert_equal User, reflection.active_record
    assert_equal :avatar, reflection.name
    assert_equal :has_one_attached, reflection.macro
    assert_equal :purge_later, reflection.options[:dependent]

    reflection = User.reflect_on_attachment(:cover_photo)
    assert_equal :local, reflection.options[:service_name]
  end

  test "reflection on a singular attachment with the same name as an attachment on another model" do
    reflection = Group.reflect_on_attachment(:avatar)
    assert_equal Group, reflection.active_record
  end

  test "reflecting on a collection attachment" do
    reflection = User.reflect_on_attachment(:highlights)
    assert_equal User, reflection.active_record
    assert_equal :highlights, reflection.name
    assert_equal :has_many_attached, reflection.macro
    assert_equal :purge_later, reflection.options[:dependent]

    reflection = User.reflect_on_attachment(:vlogs)
    assert_equal :local, reflection.options[:service_name]
  end

  test "reflecting on all attachments" do
    reflections = User.reflect_on_all_attachments.sort_by(&:name)
    assert_equal [ User ], reflections.collect(&:active_record).uniq
    assert_equal %i[ avatar cover_photo highlights vlogs ], reflections.collect(&:name)
    assert_equal %i[ has_one_attached has_one_attached has_many_attached has_many_attached ], reflections.collect(&:macro)
    assert_equal [ :purge_later, false, :purge_later, false ], reflections.collect { |reflection| reflection.options[:dependent] }
  end
end
