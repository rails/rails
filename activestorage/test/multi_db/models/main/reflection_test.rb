# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::MainReflectionTest < ActiveSupport::TestCase
  test "reflecting on a singular attachment" do
    reflection = MainUser.reflect_on_attachment(:avatar)
    assert_equal MainUser, reflection.active_record
    assert_equal :avatar, reflection.name
    assert_equal :has_one_attached, reflection.macro
    assert_equal :purge_later, reflection.options[:dependent]

    reflection = MainUser.reflect_on_attachment(:cover_photo)
    assert_equal :local, reflection.options[:service_name]

    reflection = MainUser.reflect_on_attachment(:avatar_with_variants)
    assert_instance_of Hash, reflection.named_variants
  end

  test "reflection on a singular attachment with the same name as an attachment on another model" do
    reflection = MainGroup.reflect_on_attachment(:avatar)
    assert_equal MainGroup, reflection.active_record
  end

  test "reflecting on a collection attachment" do
    reflection = MainUser.reflect_on_attachment(:highlights)
    assert_equal MainUser, reflection.active_record
    assert_equal :highlights, reflection.name
    assert_equal :has_many_attached, reflection.macro
    assert_equal :purge_later, reflection.options[:dependent]

    reflection = MainUser.reflect_on_attachment(:vlogs)
    assert_equal :local, reflection.options[:service_name]

    reflection = MainUser.reflect_on_attachment(:highlights_with_variants)
    assert_instance_of Hash, reflection.named_variants
  end

  test "reflecting on all attachments" do
    reflections = MainUser.reflect_on_all_attachments.sort_by(&:name)
    assert_equal [ MainUser ], reflections.collect(&:active_record).uniq
    assert_equal %i[ avatar avatar_with_conditional_preprocessed avatar_with_preprocessed avatar_with_variants cover_photo highlights highlights_with_conditional_preprocessed highlights_with_preprocessed highlights_with_variants intro_video name_pronunciation_audio resume resume_with_preprocessing vlogs ], reflections.collect(&:name)
    assert_equal %i[ has_one_attached has_one_attached has_one_attached has_one_attached has_one_attached has_many_attached has_many_attached has_many_attached has_many_attached has_one_attached has_one_attached has_one_attached has_one_attached has_many_attached ], reflections.collect(&:macro)
    assert_equal [ :purge_later, :purge_later, :purge_later, :purge_later, false, :purge_later, :purge_later, :purge_later, :purge_later, :purge_later, :purge_later, :purge_later, :purge_later, false ], reflections.collect { |reflection| reflection.options[:dependent] }
  end
end
