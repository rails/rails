# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AudioTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @blob = create_file_blob filename: "audio.mp3"
  end

  test "blob" do
    assert_dom_equal %(<audio src="#{polymorphic_url @blob}" />), audio_tag(@blob)
  end

  test "attachment" do
    attachment = ActiveStorage::Attachment.new(blob: @blob)
    assert_dom_equal %(<audio src="#{polymorphic_url attachment}" />), audio_tag(attachment)
  end

  test "error when attachment's empty" do
    @user = User.create!(name: "DHH")

    assert_not_predicate @user.name_pronunciation_audio, :attached?
    assert_raises(ArgumentError) { audio_tag(@user.name_pronunciation_audio) }
  end

  test "error when object can't be resolved into URL" do
    unresolvable_object = ActionView::Helpers::AssetTagHelper
    assert_raises(ArgumentError) { audio_tag(unresolvable_object) }
  end
end
