require File.dirname(__FILE__) + '/../active_record_unit'

class RenderPartialWithRecordIdentificationTest < ActiveRecordTestCase
  fixtures :developers, :projects, :developers_projects, :topics, :replies

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
  
  def setup
    @controller = RenderPartialWithRecordIdentificationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end

  def test_rendering_partial_with_has_many_and_belongs_to_association
    get :render_with_has_many_and_belongs_to_association
    assert_template 'projects/_project'
  end
  
  def test_rendering_partial_with_has_many_association
    get :render_with_has_many_association
    assert_template 'replies/_reply'
  end
  
  def test_rendering_partial_with_has_many_association
    get :render_with_has_many_through_association
    assert_template 'topics/_topic'
  end
  
  def test_rendering_partial_with_belongs_to_association
    get :render_with_belongs_to_association
    assert_template 'topics/_topic'
  end
  
  def test_render_with_record
    get :render_with_record
    assert_template 'developers/_developer'
  end
  
  def test_render_with_record_collection
    get :render_with_record_collection
    assert_template 'developers/_developer'
  end
end
