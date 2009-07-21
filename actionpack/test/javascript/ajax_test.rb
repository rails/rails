require "abstract_unit"

class AjaxTestCase < ActiveSupport::TestCase
  include ActionView::Helpers::AjaxHelper
  include ActionView::Helpers::TagHelper

  def assert_html(html, matches)
    matches.each do |match|
      assert_match Regexp.new(Regexp.escape(match)), html
    end
  end

  def self.assert_callbacks_work(&blk)
    define_method(:assert_callbacks_work, &blk)

    [:complete, :failure, :success, :interactive, :loaded, :loading, 404].each do |callback|
      test "#{callback} callback" do
        markup = assert_callbacks_work(callback)
        assert_html markup, %W(data-#{callback}-code="undoRequestCompleted\(request\)")
      end
    end
  end
end

class LinkToRemoteTest < AjaxTestCase
  def url_for(hash)
    "/blog/destroy/4"
  end

  def link(options = {})
    link_to_remote("Delete this post", "/blog/destroy/3", options)
  end

  test "with no update" do
    assert_html link, %w(href="/blog/destroy/3" Delete\ this\ post data-remote="true")
  end

  test "basic" do
    assert_html link(:update => "#posts"),
      %w(data-update-success="#posts")
  end

  test "using a url hash" do
    link = link_to_remote("Delete this post", {:controller => :blog}, :update => "#posts")
    assert_html link, %w(href="/blog/destroy/4" data-update-success="#posts")
  end

  test "with :html options" do
    expected = %{<a href="/blog/destroy/3" data-custom="me" data-update-success="#posts">Delete this post</a>}
    assert_equal expected, link(:update => "#posts", :html => {"data-custom" => "me"})
  end

  test "with a hash for :update" do
    link = link(:update => {:success => "#posts", :failure => "#error"})
    assert_match /data-update-success="#posts"/, link
    assert_match /data-update-failure="#error"/, link
  end

  test "with positional parameters" do
    link = link(:position => :top, :update => "#posts")
    assert_match /data\-update\-position="top"/, link
  end

  test "with an optional method" do
    link = link(:method => "delete")
    assert_match /data-method="delete"/, link
  end

  class LegacyLinkToRemoteTest < AjaxTestCase
    include ActionView::Helpers::AjaxHelper::Rails2Compatibility

    def link(options)
      link_to_remote("Delete this post", "/blog/destroy/3", options)
    end

    test "basic link_to_remote with :url =>" do
      expected = %{<a href="/blog/destroy/3" data-update-success="#posts">Delete this post</a>}
      assert_equal expected,
        link_to_remote("Delete this post", :url => "/blog/destroy/3", :update => "#posts")
    end

    assert_callbacks_work do |callback|
      link(callback => "undoRequestCompleted(request)")
    end
  end
end

class ButtonToRemoteTest < AjaxTestCase
  def button(options, html = {})
    button_to_remote("Remote outpost", options, html)
  end

  def url_for(*)
    "/whatnot"
  end
  
  class StandardTest < ButtonToRemoteTest
    test "basic" do
      button = button({:url => {:action => "whatnot"}}, {:class => "fine"})
      [/input/, /class="fine"/, /type="button"/, /value="Remote outpost"/,
       /data-url="\/whatnot"/].each do |match|
         assert_match match, button
      end
    end
  end
  
  class LegacyButtonToRemoteTest < ButtonToRemoteTest
    include ActionView::Helpers::AjaxHelper::Rails2Compatibility
    
    assert_callbacks_work do |callback|
      button(callback => "undoRequestCompleted(request)")
    end
  end

end