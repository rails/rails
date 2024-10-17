# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/with"

class CspHelperWithCspEnabledTest < ActionView::TestCase
  tests ActionView::Helpers::CspHelper

  def content_security_policy_nonce
    "iyhD0Yc0W+c="
  end

  def content_security_policy?
    true
  end

  def test_csp_meta_tag_uses_nonce_attribute_with_helper_nonce_attribute_name_nonce
    ActionView::Helpers::CspHelper.with(csp_meta_tag_nonce_attribute: :nonce) do
      assert_equal "<meta name=\"csp-nonce\" nonce=\"iyhD0Yc0W+c=\" />", csp_meta_tag
    end
  end

  def test_csp_meta_tag_uses_nonce_attribute_with_helper_nonce_attribute_name_content
    ActionView::Helpers::CspHelper.with(csp_meta_tag_nonce_attribute: :content) do
      assert_equal "<meta name=\"csp-nonce\" content=\"iyhD0Yc0W+c=\" />", csp_meta_tag
    end
  end

  def test_csp_meta_tag_with_helper_nonce_attribute_default_setting
    assert_equal "<meta name=\"csp-nonce\" content=\"iyhD0Yc0W+c=\" />", csp_meta_tag
  end

  def test_csp_meta_tag_with_options
    assert_equal "<meta property=\"csp-nonce\" name=\"csp-nonce\" content=\"iyhD0Yc0W+c=\" />", csp_meta_tag(property: "csp-nonce")
  end
end

class CspHelperWithCspDisabledTest < ActionView::TestCase
  tests ActionView::Helpers::CspHelper

  def content_security_policy?
    false
  end

  def test_csp_meta_tag
    assert_nil csp_meta_tag
  end
end
