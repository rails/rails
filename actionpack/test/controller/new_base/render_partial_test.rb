require 'abstract_unit'

module RenderPartial

  class BasicController < ActionController::Base

    self.view_paths = [ActionView::FixtureResolver.new(
      "render_partial/basic/_basic.html.erb"      => "BasicPartial!",
      "render_partial/basic/basic.html.erb"       => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'basic' %><%= @test_unchanged %>",
      "render_partial/basic/with_json.html.erb"   => "<%= render :partial => 'with_json', :formats => [:json] %>",
      "render_partial/basic/_with_json.json.erb"  => "<%= render :partial => 'final', :formats => [:json] %>",
      "render_partial/basic/_final.json.erb"      => "{ final: json }",
      "render_partial/basic/overridden.html.erb"  => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'overridden' %><%= @test_unchanged %>",
      "render_partial/basic/_overridden.html.erb" => "ParentPartial!",
      "render_partial/child/_overridden.html.erb" => "OverriddenPartial!",
      "render_partial/basic/hierarhical.html.erb"               => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'subfolder/hierarhical' %><%= @test_unchanged %>",
      "render_partial/basic/subfolder/_hierarhical.html.erb"    => "SubfolderBasicHierarhicalPartial!",
      "render_partial/basic/hierarhical_with_child.html.erb"               => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'subfolder/hierarhical_with_child' %><%= @test_unchanged %>",
      "render_partial/child/subfolder/_hierarhical_with_child.html.erb"    => "SubfolderBasicHierarhicalWithChildPartial!",
      "render_partial/child/absolute.html.erb"               => "<%= @test_unchanged = 'goodbye' %><%= render :partial => '/render_partial/shared/absolute_partial' %><%= @test_unchanged %>",
      "render_partial/shared/_absolute_partial.html.erb"    => "AbsolutePartial!"
    )]

    def html_with_json_inside_json
      render :action => "with_json"
    end

    def changing
      @test_unchanged = 'hello'
      render :action => "basic"
    end

    def overridden
      @test_unchanged = 'hello'
    end
  end

  class ChildController < BasicController; end

  class TestPartial < Rack::TestCase
    testing BasicController

    test "rendering a partial in ActionView doesn't pull the ivars again from the controller" do
      get :changing
      assert_response("goodbyeBasicPartial!goodbye")
    end

    test "rendering a template with renders another partial with other format that renders other partial in the same format" do
      get :html_with_json_inside_json
      assert_content_type "text/html; charset=utf-8"
      assert_response "{ final: json }"
    end
  end

  class TestInheritedPartial < Rack::TestCase
    testing ChildController

    test "partial from parent controller gets picked if missing in child one" do
      get :changing
      assert_response("goodbyeBasicPartial!goodbye")
    end

    test "partial from child controller gets picked" do
      get :overridden
      assert_response("goodbyeOverriddenPartial!goodbye")
    end

    test "partial from contoller from subfolder gets picked" do
      get :hierarhical
      assert_response("goodbyeSubfolderBasicHierarhicalPartial!goodbye")
    end

    test "partial from child contoller from subfolder gets picked" do
      get :hierarhical_with_child
      assert_response("goodbyeSubfolderBasicHierarhicalWithChildPartial!goodbye")
    end

    test "partial with absolute path gets picked" do
      get :absolute
      assert_response("goodbyeAbsolutePartial!goodbye")
    end

  end

end
