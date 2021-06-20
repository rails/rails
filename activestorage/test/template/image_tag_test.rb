# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ImageTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "blob" do
    assert_dom_equal %(<img src="#{polymorphic_url @blob}" />), image_tag(@blob)
  end

  test "variant" do
    variant = @blob.variant(resize_to_limit: [100, 100])
    assert_dom_equal %(<img src="#{polymorphic_url variant}" />), image_tag(variant)
  end

  test "preview" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    preview = blob.preview(resize_to_limit: [100, 100])
    assert_dom_equal %(<img src="#{polymorphic_url preview}" />), image_tag(preview)
  end

  test "attachment" do
    attachment = ActiveStorage::Attachment.new(blob: @blob)
    assert_dom_equal %(<img src="#{polymorphic_url attachment}" />), image_tag(attachment)
  end

  test "error when attachment's empty" do
    @user = User.create!(name: "DHH")

    assert_not_predicate @user.avatar, :attached?
    assert_raises(ArgumentError) { image_tag(@user.avatar) }
  end

  test "error when object can't be resolved into URL" do
    unresolvable_object = ActionView::Helpers::AssetTagHelper
    assert_raises(ArgumentError) { image_tag(unresolvable_object) }
  end

  test "blob is resized if automatic resizing is enabled" do
    with_automatic_resizing_of_active_storage_images do
      variant = @blob.variant(resize_to_limit: [200, nil])
      assert_dom_equal %(<img width="100" src="#{polymorphic_url variant}" />), image_tag(@blob, width: 100)

      variant = @blob.variant(resize_to_limit: [nil, 200])
      assert_dom_equal %(<img height="100" src="#{polymorphic_url variant}" />), image_tag(@blob, height: 100)
    end
  end

  test "attachment is resized if automatic resizing is enabled" do
    with_automatic_resizing_of_active_storage_images do
      attachment = ActiveStorage::Attachment.new(blob: @blob)

      variant = @blob.variant(resize_to_limit: [200, nil])
      assert_dom_equal %(<img width="100" src="#{polymorphic_url variant}" />), image_tag(attachment, width: 100)

      variant = @blob.variant(resize_to_limit: [nil, 200])
      assert_dom_equal %(<img height="100" src="#{polymorphic_url variant}" />), image_tag(attachment, height: 100)
    end
  end

  test "variant is not resized if automatic resizing is enabled" do
    with_automatic_resizing_of_active_storage_images do
      variant = @blob.variant(resize: "200x200")

      assert_dom_equal %(<img src="#{polymorphic_url variant}" width="100" />), image_tag(variant, width: 100)
      assert_dom_equal %(<img src="#{polymorphic_url variant}" height="100" />), image_tag(variant, height: 100)
    end
  end

  test "source is not resized if its not variable" do
    with_automatic_resizing_of_active_storage_images do
      assert_dom_equal %(<img src="https://rubyonrails.org/images/imagine.png" width="100" />), image_tag("https://rubyonrails.org/images/imagine.png", width: 100)

      invariable = create_file_blob filename: "icon.svg"
      assert_dom_equal %(<img src="#{polymorphic_url invariable}" width="100" />), image_tag(invariable, width: 100)
    end
  end

  test "source is resized using the size attribute" do
    with_automatic_resizing_of_active_storage_images do
      variant = @blob.variant(resize_to_limit: [200, 200])
      assert_dom_equal %(<img src="#{polymorphic_url variant}" width="100" height="100" />), image_tag(@blob, size: 100)
    end
  end

  test "source is resized if attributes are strings" do
    with_automatic_resizing_of_active_storage_images do
      variant = @blob.variant(resize_to_limit: [200, 200])
      assert_dom_equal %(<img src="#{polymorphic_url variant}" width="100" height="100" />), image_tag(@blob, size: "100")

      variant = @blob.variant(resize_to_limit: [200, nil])
      assert_dom_equal %(<img src="#{polymorphic_url variant}" width="100" />), image_tag(@blob, width: "100")

      variant = @blob.variant(resize_to_limit: [nil, 200])
      assert_dom_equal %(<img src="#{polymorphic_url variant}" height="100" />), image_tag(@blob, height: "100")
    end
  end

  test "source is not resized if attributes are percentages" do
    with_automatic_resizing_of_active_storage_images do
      assert_dom_equal %(<img src="#{polymorphic_url @blob}" width="100%" />), image_tag(@blob, width: "100%")
      assert_dom_equal %(<img src="#{polymorphic_url @blob}" height="100%" />), image_tag(@blob, height: "100%")
    end
  end

  private
    def with_automatic_resizing_of_active_storage_images
      original_resize_active_storage_images = ActionView::Helpers::AssetTagHelper.resize_active_storage_images
      ActionView::Helpers::AssetTagHelper.resize_active_storage_images = true

      yield
    ensure
      ActionView::Helpers::AssetTagHelper.resize_active_storage_images = original_resize_active_storage_images
    end
end
