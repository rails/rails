require 'active_record_unit'

class RenderPartialWithRecordIdentificationController < ActionController::Base
  def render_with_has_many_and_belongs_to_association
    @developer = Developer.find(1)
    render :partial => @developer.projects
  end

  def render_with_has_many_association
    @topic = Topic.find(1)
    render :partial => @topic.replies
  end

  def render_with_named_scope
    render :partial => Reply.base
  end

  def render_with_has_many_through_association
    @developer = Developer.find(:first)
    render :partial => @developer.topics
  end

  def render_with_has_one_association
    @company = Company.find(1)
    render :partial => @company.mascot
  end

  def render_with_belongs_to_association
    @reply = Reply.find(1)
    render :partial => @reply.topic
  end

  def render_with_record
    @developer = Developer.find(:first)
    render :partial => @developer
  end

  def render_with_record_collection
    @developers = Developer.find(:all)
    render :partial => @developers
  end

  def render_with_record_collection_and_spacer_template
    @developer = Developer.find(1)
    render :partial => @developer.projects, :spacer_template => 'test/partial_only'
  end
end

class RenderPartialWithRecordIdentificationTest < ActiveRecordTestCase
  tests RenderPartialWithRecordIdentificationController
  fixtures :developers, :projects, :developers_projects, :topics, :replies, :companies, :mascots

  def test_rendering_partial_with_has_many_and_belongs_to_association
    get :render_with_has_many_and_belongs_to_association
    assert_template 'projects/_project'
    assert_equal 'Active RecordActive Controller', @response.body
  end

  def test_rendering_partial_with_has_many_association
    get :render_with_has_many_association
    assert_template 'replies/_reply'
    assert_equal 'Birdman is better!', @response.body
  end

  def test_rendering_partial_with_named_scope
    get :render_with_named_scope
    assert_template 'replies/_reply'
    assert_equal 'Birdman is better!Nuh uh!', @response.body
  end

  def test_render_with_record
    get :render_with_record
    assert_template 'developers/_developer'
    assert_equal 'David', @response.body
  end

  def test_render_with_record_collection
    get :render_with_record_collection
    assert_template 'developers/_developer'
    assert_equal 'DavidJamisfixture_3fixture_4fixture_5fixture_6fixture_7fixture_8fixture_9fixture_10Jamis', @response.body
  end

  def test_render_with_record_collection_and_spacer_template
    get :render_with_record_collection_and_spacer_template
    assert_equal 'Active Recordonly partialActive Controller', @response.body
  end

  def test_rendering_partial_with_has_one_association
    mascot = Company.find(1).mascot
    get :render_with_has_one_association
    assert_template 'mascots/_mascot'
    assert_equal mascot.name, @response.body
  end
end

class RenderPartialWithRecordIdentificationController < ActionController::Base
  def render_with_has_many_and_belongs_to_association
    @developer = Developer.find(1)
    render :partial => @developer.projects
  end

  def render_with_has_many_association
    @topic = Topic.find(1)
    render :partial => @topic.replies
  end

  def render_with_has_many_through_association
    @developer = Developer.find(:first)
    render :partial => @developer.topics
  end

  def render_with_belongs_to_association
    @reply = Reply.find(1)
    render :partial => @reply.topic
  end

  def render_with_record
    @developer = Developer.find(:first)
    render :partial => @developer
  end

  def render_with_record_collection
    @developers = Developer.find(:all)
    render :partial => @developers
  end
end

class Game < Struct.new(:name, :id)
  def to_param
    id.to_s
  end
end

module Fun
  class NestedController < ActionController::Base
    def render_with_record_in_nested_controller
      render :partial => Game.new("Pong")
    end

    def render_with_record_collection_in_nested_controller
      render :partial => [ Game.new("Pong"), Game.new("Tank") ]
    end
  end

  module Serious
    class NestedDeeperController < ActionController::Base
      def render_with_record_in_deeper_nested_controller
        render :partial => Game.new("Chess")
      end

      def render_with_record_collection_in_deeper_nested_controller
        render :partial => [ Game.new("Chess"), Game.new("Sudoku"), Game.new("Solitaire") ]
      end
    end
  end
end

class RenderPartialWithRecordIdentificationAndNestedControllersTest < ActiveRecordTestCase
  tests Fun::NestedController

  def test_render_with_record_in_nested_controller
    get :render_with_record_in_nested_controller
    assert_template 'fun/games/_game'
    assert_equal 'Pong', @response.body
  end

  def test_render_with_record_collection_in_nested_controller
    get :render_with_record_collection_in_nested_controller
    assert_template 'fun/games/_game'
    assert_equal 'PongTank', @response.body
  end
end

class RenderPartialWithRecordIdentificationAndNestedDeeperControllersTest < ActiveRecordTestCase
  tests Fun::Serious::NestedDeeperController

  def test_render_with_record_in_deeper_nested_controller
    get :render_with_record_in_deeper_nested_controller
    assert_template 'fun/serious/games/_game'
    assert_equal 'Chess', @response.body
  end

  def test_render_with_record_collection_in_deeper_nested_controller
    get :render_with_record_collection_in_deeper_nested_controller
    assert_template 'fun/serious/games/_game'
    assert_equal 'ChessSudokuSolitaire', @response.body
  end
end
