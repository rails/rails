# frozen_string_literal: true

#
#  This file has two suites of tests:
#  - A unit test suite for SanitizeHelper behavior
#  - An integration test suite to verify basic expectations for each supported sanitizer vendor
#

require "abstract_unit"

#
#  Unit test SanitizeHelper behavior. We use a mock vendor to ensure we're testing behavior that is
#  independent of sanitizer vendors.
#
class SanitizeHelperTest < ActionView::TestCase
  tests ActionView::Helpers::SanitizeHelper

  def setup
    super
    @saved_vendor = ActionView::Helpers::SanitizeHelper.sanitizer_vendor
    @mock_vendor = ActionView::Helpers::SanitizeHelper.sanitizer_vendor = new_mock_vendor
  end

  def teardown
    ActionView::Helpers::SanitizeHelper.sanitizer_vendor = @saved_vendor
    super
  end

  test "sanitizer_vendor module attribute and class method" do
    assert_equal(@mock_vendor, ActionView::Helpers::SanitizeHelper.sanitizer_vendor)
    assert_equal(@mock_vendor, self.class.sanitizer_vendor)

    vendor2 = ActionView::Helpers::SanitizeHelper.sanitizer_vendor = new_mock_vendor

    assert_equal(vendor2, ActionView::Helpers::SanitizeHelper.sanitizer_vendor)
    assert_equal(vendor2, self.class.sanitizer_vendor)
  end

  test "full_sanitizer is memoized" do
    result1 = self.class.full_sanitizer
    result2 = self.class.full_sanitizer

    assert_same(result1, result2)
  end

  test "link_sanitizer is memoized" do
    result1 = self.class.link_sanitizer
    result2 = self.class.link_sanitizer

    assert_same(result1, result2)
  end

  test "safe_list_sanitizer is memoized" do
    result1 = self.class.safe_list_sanitizer
    result2 = self.class.safe_list_sanitizer

    assert_same(result1, result2)
  end

  test "full_sanitizer is settable" do
    saved_sanitizer = self.class.full_sanitizer

    mock_sanitizer = @mock_vendor.new_mock_sanitizer("walrus")
    self.class.full_sanitizer = mock_sanitizer

    assert_equal(mock_sanitizer, self.class.full_sanitizer)
  ensure
    self.class.full_sanitizer = saved_sanitizer
  end

  test "link_sanitizer is settable" do
    saved_sanitizer = self.class.link_sanitizer

    mock_sanitizer = @mock_vendor.new_mock_sanitizer("walrus")
    self.class.link_sanitizer = mock_sanitizer

    assert_equal(mock_sanitizer, self.class.link_sanitizer)
  ensure
    self.class.link_sanitizer = saved_sanitizer
  end

  test "safe_list_sanitizer is settable" do
    saved_sanitizer = self.class.safe_list_sanitizer

    mock_sanitizer = @mock_vendor.new_mock_sanitizer("walrus")
    self.class.safe_list_sanitizer = mock_sanitizer

    assert_equal(mock_sanitizer, self.class.safe_list_sanitizer)
  ensure
    self.class.safe_list_sanitizer = saved_sanitizer
  end

  test "full_sanitizer returns an instance of the class returned by vendor full_sanitizer" do
    assert_equal("full_sanitizer", self.class.full_sanitizer.injected_name)
  end

  test "link_sanitizer returns an instance of the class returned by vendor link_sanitizer" do
    assert_equal("link_sanitizer", self.class.link_sanitizer.injected_name)
  end

  test "safe_list_sanitizer returns an instance of the class returned by vendor safe_list_sanitizer" do
    assert_equal("safe_list_sanitizer", self.class.safe_list_sanitizer.injected_name)
  end

  test "sanitize calls sanitize on the safe_list_sanitizer" do
    assert_equal(
      "safe_list_sanitizer#sanitize / asdf / {}",
      self.sanitize("asdf"),
    )
    assert_equal(
      "safe_list_sanitizer#sanitize / asdf / #{{ tags: ["a", "b"] }}",
      self.sanitize("asdf", tags: ["a", "b"]),
    )
    assert_predicate(self.sanitize("asdf"), :html_safe?)
  end

  test "sanitize_css calls sanitize_css on the safe_list_sanitizer" do
    assert_equal("safe_list_sanitizer#sanitize_css / asdf", self.sanitize_css("asdf"))
  end

  test "strip_tags calls sanitize on the full_sanitizer" do
    assert_equal(
      "full_sanitizer#sanitize / asdf / {}",
      self.strip_tags("asdf"),
    )
    assert_predicate(self.strip_tags("asdf"), :html_safe?)
  end

  test "strip_links calls sanitize on the link_sanitizer" do
    assert_equal(
      "link_sanitizer#sanitize / asdf / {}",
      self.strip_links("asdf"),
    )
    assert_not_predicate(self.strip_links("asdf"), :html_safe?)
  end

  private
    def new_mock_vendor
      Class.new do
        class << self
          def full_sanitizer
            new_mock_sanitizer("full_sanitizer")
          end

          def link_sanitizer
            new_mock_sanitizer("link_sanitizer")
          end

          def safe_list_sanitizer
            new_mock_sanitizer("safe_list_sanitizer").tap do |sanitizer|
              sanitizer.class_eval do
                def sanitize_css(style)
                  "safe_list_sanitizer#sanitize_css / #{style}"
                end
              end
            end
          end

          def new_mock_sanitizer(injected_name)
            Class.new do
              define_method :injected_name do
                injected_name
              end

              def sanitize(html, options = {})
                "#{injected_name}#sanitize / #{html} / #{options}"
              end
            end
          end
        end
      end
    end
end

#
#  Test suite for interactions with each supported sanitizer vendor. Exercise the basic API and
#  behavior of the vendor and its sanitizers.
#
#  We don't want to do exhaustive HTML sanitization testing here. Let's assume it's already being
#  done upstream by the vendor.
#
#  Note that Rails::Html::Sanitizer and Rails::HTML4::Sanitizer are identical vendors (but aren't
#  the same class). Eventually we will move away from using Rails::Html (a.k.a Rails::HTML), but
#  for now we should make sure everything works as expected by testing it.
#
module SanitizeHelperVendorTests
  def setup
    super
    @saved_vendor = ActionView::Helpers::SanitizeHelper.sanitizer_vendor
    ActionView::Helpers::SanitizeHelper.sanitizer_vendor = vendor

    @subject_class = Class.new do
      include ActionView::Helpers::SanitizeHelper
    end
    @subject = @subject_class.new
  end

  def teardown
    ActionView::Helpers::SanitizeHelper.sanitizer_vendor = @saved_vendor
    super
  end

  def test_full_sanitizer_returns_a_sanitizer
    sanitizer = @subject_class.full_sanitizer

    assert_equal(vendor.full_sanitizer, sanitizer.class)
    assert_respond_to(sanitizer, :sanitize)
  end

  def test_link_sanitizer_returns_a_sanitizer
    sanitizer = @subject_class.link_sanitizer

    assert_equal(vendor.link_sanitizer, sanitizer.class)
    assert_respond_to(sanitizer, :sanitize)
  end

  def test_safe_list_sanitizer_returns_a_sanitizer
    sanitizer = @subject_class.safe_list_sanitizer

    assert_equal(vendor.safe_list_sanitizer, sanitizer.class)
    assert_respond_to(sanitizer, :sanitize)
  end

  def test_full_sanitizer_is_settable
    @subject_class.full_sanitizer = :mock
    result = @subject_class.full_sanitizer

    assert_same(:mock, result)
  end

  def test_link_sanitizer_is_settable
    @subject_class.link_sanitizer = :mock
    result = @subject_class.link_sanitizer

    assert_same(:mock, result)
  end

  def test_safe_list_sanitizer_is_settable
    @subject_class.safe_list_sanitizer = :mock
    result = @subject_class.safe_list_sanitizer

    assert_same(:mock, result)
  end

  def test_deprecated_methods_are_supported
    assert_respond_to(vendor, :white_list_sanitizer)
  end

  def test_sanitized_allowed_tags_returns_a_string_collection
    result = @subject_class.sanitized_allowed_tags

    assert_kind_of(Enumerable, result)
    assert_kind_of(String, result.first)
  end

  def test_sanitized_allowed_attributes_returns_a_string_collection
    result = @subject_class.sanitized_allowed_attributes

    assert_kind_of(Enumerable, result)
    assert_kind_of(String, result.first)
  end

  def test_sanitized_allowed_tags_is_settable
    saved_value = @subject_class.sanitized_allowed_tags
    @subject_class.sanitized_allowed_tags = ["a", "b"]
    result = @subject_class.sanitized_allowed_tags

    assert_equal(["a", "b"], result)
  ensure
    # We need to undo this because allowed tags and attributes are stored as globals in class
    # attributes on Rails::HTML*::SafeListSanitizer.
    @subject_class.sanitized_allowed_tags = saved_value
  end

  def test_sanitized_allowed_attributes_is_settable
    saved_value = @subject_class.sanitized_allowed_attributes
    @subject_class.sanitized_allowed_attributes = ["a", "b"]
    result = @subject_class.sanitized_allowed_attributes

    assert_equal(["a", "b"], result)
  ensure
    # We need to undo this because allowed tags and attributes are stored as globals in class
    # attributes on Rails::HTML*::SafeListSanitizer.
    @subject_class.sanitized_allowed_attributes = saved_value
  end

  def test_sanitize
    input = %(<div><script>alert(1);</script><a href="http://www.example.com/">Example</a> of a fragment</div>)
    result = @subject.sanitize(input)

    assert_not_includes(result, "script")
  end

  def test_sanitize_with_tags_option
    input = %(<b>bold</b> <i>italic</i> <div>hello</div>)

    assert_equal("<b>bold</b> <i>italic</i> hello", @subject.sanitize(input, tags: %w(b i)))
    assert_equal("bold italic <div>hello</div>", @subject.sanitize(input, tags: %w(div)))
  end

  def test_sanitize_with_attributes_option
    input = %(<div a="1" b="2" c="3">hello</div>)

    assert_equal(%(<div a="1" b="2">hello</div>), @subject.sanitize(input, attributes: %w(a b)))
    assert_equal(%(<div b="2" c="3">hello</div>), @subject.sanitize(input, attributes: %w(b c)))
  end

  def test_sanitize_with_loofah_scrubber_option
    input = %(<div>hello</div>)
    scrubber = Loofah::Scrubber.new do |node|
      node.content = "scrubbed"
    end

    assert_equal(%(<div>scrubbed</div>), @subject.sanitize(input, scrubber: scrubber))
  end

  def test_sanitize_with_custom_scrubber_option
    scrubber = Class.new(Rails::HTML::PermitScrubber) do
      def initialize
        super
        self.tags = ["div"]
      end
    end.new

    input = %(<div>hello</div><p>world</p>)

    assert_equal(%(<div>hello</div>world), @subject.sanitize(input, scrubber: scrubber))
  end

  def test_sanitize_css
    input = %(width: 100%; background-image:url("http://www.example.com/"); height: 100%;)
    result = @subject.sanitize_css(input)

    assert_not_includes(result, "background-image")
    assert_includes(result, "width")
    assert_includes(result, "height")
  end

  def test_strip_tags
    input = %(<div><a href="http://www.example.com/">Example</a> of a fragment</div>)
    result = @subject.strip_tags(input)

    assert_equal("Example of a fragment", result)
  end

  def test_strip_links
    input = %(<div><a href="http://www.example.com/">Example</a> of a fragment</div>)
    result = @subject.strip_links(input)

    assert_equal("<div>Example of a fragment</div>", result)
  end

  def test_we_get_the_expected_HTML_parser
    # see https://html.spec.whatwg.org/multipage/parsing.html#misnested-tags:-b-i-/b-/i
    input = %(<p>1<b>2<i>3</b>4</i>5</p>)
    scrubber = Loofah::Scrubber.new { |_| } # no-op, we're checking the underlying parser here

    expected = if vendor == Rails::Html::Sanitizer || vendor == Rails::HTML4::Sanitizer
      if RUBY_ENGINE == "jruby"
        "<p>1<b>2<i>3</i></b><i>4</i>5</p>" # nekohtml parser
      else
        "<p>1<b>2<i>3</i></b>45</p>" # libxml2 html4 parser
      end
    elsif vendor == Rails::HTML5::Sanitizer
      "<p>1<b>2<i>3</i></b><i>4</i>5</p>" # libgumbo html5 parser
    else
      flunk "Unknown vendor #{vendor}"
    end

    assert_equal(expected, @subject.sanitize(input, scrubber: scrubber))
  end
end

class SanitizeHelperVendorHtmlTest < ActiveSupport::TestCase
  include SanitizeHelperVendorTests

  def vendor
    Rails::Html::Sanitizer
  end
end

class SanitizeHelperVendorHTML4Test < ActiveSupport::TestCase
  include SanitizeHelperVendorTests

  def vendor
    Rails::HTML4::Sanitizer
  end
end

class SanitizeHelperVendorHTML5Test < ActiveSupport::TestCase
  include SanitizeHelperVendorTests

  def vendor
    Rails::HTML5::Sanitizer
  end
end if Rails::HTML::Sanitizer.html5_support?
