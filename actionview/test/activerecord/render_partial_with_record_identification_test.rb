# frozen_string_literal: true

require "active_record_unit"

class RenderPartialWithRecordIdentificationController < ActionController::Base
  ROUTES = test_routes do
    get :render_with_record_collection, to: "render_partial_with_record_identification#render_with_record_collection"
    get :render_with_scope, to: "render_partial_with_record_identification#render_with_scope"
    get :render_with_record, to: "render_partial_with_record_identification#render_with_record"
    get :render_with_has_many_association, to: "render_partial_with_record_identification#render_with_has_many_association"
    get :render_with_has_many_and_belongs_to_association, to: "render_partial_with_record_identification#render_with_has_many_and_belongs_to_association"
    get :render_with_has_one_association, to: "render_partial_with_record_identification#render_with_has_one_association"
    get :render_with_record_collection_and_spacer_template, to: "render_partial_with_record_identification#render_with_record_collection_and_spacer_template"
  end

  def render_with_has_many_and_belongs_to_association
    @developer = Developer.find(1)
    render partial: @developer.projects
  end

  def render_with_has_many_association
    @topic = Topic.find(1)
    render partial: @topic.replies
  end

  def render_with_scope
    render partial: Reply.base
  end

  def render_with_has_one_association
    @company = Company.find(1)
    render partial: @company.mascot
  end

  def render_with_record
    @developer = Developer.first
    render partial: @developer
  end

  def render_with_record_collection
    @developers = Developer.all
    render partial: @developers
  end

  def render_with_record_collection_and_spacer_template
    @developer = Developer.find(1)
    render partial: @developer.projects, spacer_template: "test/partial_only"
  end
end

class RenderPartialWithRecordIdentificationTest < ActiveRecordTestCase
  tests RenderPartialWithRecordIdentificationController
  fixtures :developers, :projects, :developers_projects, :topics, :replies, :companies, :mascots

  def test_rendering_partial_with_has_many_and_belongs_to_association
    get :render_with_has_many_and_belongs_to_association
    assert_equal Developer.find(1).projects.map(&:name).join, @response.body
  end

  def test_rendering_partial_with_has_many_association
    get :render_with_has_many_association
    assert_equal "Birdman is better!", @response.body
  end

  def test_rendering_partial_with_scope
    get :render_with_scope
    assert_equal "Birdman is better!Nuh uh!", @response.body
  end

  def test_render_with_record
    get :render_with_record
    assert_equal "David", @response.body
  end

  def test_render_with_record_collection
    get :render_with_record_collection
    assert_equal "DavidJamisfixture_3fixture_4fixture_5fixture_6fixture_7fixture_8fixture_9fixture_10Jamis", @response.body
  end

  def test_render_with_record_collection_and_spacer_template
    get :render_with_record_collection_and_spacer_template
    assert_equal Developer.find(1).projects.map(&:name).join("only partial"), @response.body
  end

  def test_rendering_partial_with_has_one_association
    mascot = Company.find(1).mascot
    get :render_with_has_one_association
    assert_equal mascot.name, @response.body
  end
end

Game = Struct.new(:name, :id) do
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  def to_param
    id.to_s
  end
end

module Fun
  class NestedController < ActionController::Base
    ROUTES = test_routes do
      get :render_with_record_in_nested_controller, to: "fun/nested#render_with_record_in_nested_controller"
      get :render_with_record_collection_in_nested_controller, to: "fun/nested#render_with_record_collection_in_nested_controller"
    end

    def render_with_record_in_nested_controller
      render partial: Game.new("Pong")
    end

    def render_with_record_collection_in_nested_controller
      render partial: [ Game.new("Pong"), Game.new("Tank") ]
    end
  end

  module Serious
    class NestedDeeperController < ActionController::Base
      ROUTES = test_routes do
        get :render_with_record_in_deeper_nested_controller, to: "fun/serious/nested_deeper#render_with_record_in_deeper_nested_controller"
        get :render_with_record_collection_in_deeper_nested_controller, to: "fun/serious/nested_deeper#render_with_record_collection_in_deeper_nested_controller"
      end

      def render_with_record_in_deeper_nested_controller
        render partial: Game.new("Chess")
      end

      def render_with_record_collection_in_deeper_nested_controller
        render partial: [ Game.new("Chess"), Game.new("Sudoku"), Game.new("Solitaire") ]
      end
    end
  end
end

class RenderPartialWithRecordIdentificationAndNestedControllersTest < ActiveRecordTestCase
  tests Fun::NestedController

  def test_render_with_record_in_nested_controller
    get :render_with_record_in_nested_controller
    assert_equal "Fun Pong\n", @response.body
  end

  def test_render_with_record_collection_in_nested_controller
    get :render_with_record_collection_in_nested_controller
    assert_equal "Fun Pong\nFun Tank\n", @response.body
  end
end

class RenderPartialWithRecordIdentificationAndNestedControllersWithoutPrefixTest < ActiveRecordTestCase
  tests Fun::NestedController

  def test_render_with_record_in_nested_controller
    old_config = ActionView::Base.prefix_partial_path_with_controller_namespace
    ActionView::Base.prefix_partial_path_with_controller_namespace = false

    get :render_with_record_in_nested_controller
    assert_equal "Just Pong\n", @response.body
  ensure
    ActionView::Base.prefix_partial_path_with_controller_namespace = old_config
  end

  def test_render_with_record_collection_in_nested_controller
    old_config = ActionView::Base.prefix_partial_path_with_controller_namespace
    ActionView::Base.prefix_partial_path_with_controller_namespace = false

    get :render_with_record_collection_in_nested_controller
    assert_equal "Just Pong\nJust Tank\n", @response.body
  ensure
    ActionView::Base.prefix_partial_path_with_controller_namespace = old_config
  end
end

class RenderPartialWithRecordIdentificationAndNestedDeeperControllersTest < ActiveRecordTestCase
  tests Fun::Serious::NestedDeeperController

  def test_render_with_record_in_deeper_nested_controller
    get :render_with_record_in_deeper_nested_controller
    assert_equal "Serious Chess\n", @response.body
  end

  def test_render_with_record_collection_in_deeper_nested_controller
    get :render_with_record_collection_in_deeper_nested_controller
    assert_equal "Serious Chess\nSerious Sudoku\nSerious Solitaire\n", @response.body
  end
end

class RenderPartialWithRecordIdentificationAndNestedDeeperControllersWithoutPrefixTest < ActiveRecordTestCase
  tests Fun::Serious::NestedDeeperController

  def test_render_with_record_in_deeper_nested_controller
    old_config = ActionView::Base.prefix_partial_path_with_controller_namespace
    ActionView::Base.prefix_partial_path_with_controller_namespace = false

    get :render_with_record_in_deeper_nested_controller
    assert_equal "Just Chess\n", @response.body
  ensure
    ActionView::Base.prefix_partial_path_with_controller_namespace = old_config
  end

  def test_render_with_record_collection_in_deeper_nested_controller
    old_config = ActionView::Base.prefix_partial_path_with_controller_namespace
    ActionView::Base.prefix_partial_path_with_controller_namespace = false

    get :render_with_record_collection_in_deeper_nested_controller
    assert_equal "Just Chess\nJust Sudoku\nJust Solitaire\n", @response.body
  ensure
    ActionView::Base.prefix_partial_path_with_controller_namespace = old_config
  end
end
