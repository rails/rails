require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module Etags
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "etags/basic/base.html.erb" => "Hello from without_layout.html.erb",
      "layouts/etags.html.erb"    => "teh <%= yield %> tagz"
    )]

    def without_layout
      render :action => "base"
    end

    def with_layout
      render :action => "base", :layout => "etags"
    end
  end

  class EtagTest < SimpleRouteCase
    describe "Rendering without any special etag options returns an etag that is an MD5 hash of its text"

    test "an action without a layout" do
      get "/etags/basic/without_layout"

      body = "Hello from without_layout.html.erb"
      assert_body body
      assert_header "Etag", etag_for(body)
      assert_status 200
    end

    test "an action with a layout" do
      get "/etags/basic/with_layout"

      body = "teh Hello from without_layout.html.erb tagz"
      assert_body body
      assert_header "Etag", etag_for(body)
      assert_status 200      
    end

    private

    def etag_for(text)
      %("#{Digest::MD5.hexdigest(text)}")
    end
  end
end