require File.dirname(__FILE__) + '/../active_record_unit'

class PaginationTest < ActiveRecordTestCase
  fixtures :topics, :replies, :developers, :projects, :developers_projects
  
  class PaginationController < ActionController::Base
    self.template_root = "#{File.dirname(__FILE__)}/../fixtures/"

    around_filter :silence_deprecation_warnings
    
    def simple_paginate
      @topic_pages, @topics = paginate(:topics)
      render :nothing => true
    end
    
    def paginate_with_per_page
      @topic_pages, @topics = paginate(:topics, :per_page => 1)
      render :nothing => true
    end
    
    def paginate_with_order
      @topic_pages, @topics = paginate(:topics, :order => 'created_at asc')
      render :nothing => true
    end
    
    def paginate_with_order_by
      @topic_pages, @topics = paginate(:topics, :order_by => 'created_at asc')
      render :nothing => true
    end
    
    def paginate_with_include_and_order
      @topic_pages, @topics = paginate(:topics, :include => :replies, :order => 'replies.created_at asc, topics.created_at asc')
      render :nothing => true
    end
    
    def paginate_with_conditions
      @topic_pages, @topics = paginate(:topics, :conditions => ["created_at > ?", 30.minutes.ago])
      render :nothing => true
    end
    
    def paginate_with_class_name
      @developer_pages, @developers = paginate(:developers, :class_name => "DeVeLoPeR")
      render :nothing => true
    end
    
    def paginate_with_singular_name
      @developer_pages, @developers = paginate()
      render :nothing => true
    end
    
    def paginate_with_joins
      @developer_pages, @developers = paginate(:developers, 
                                             :joins => 'LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id',
                                             :conditions => 'project_id=1')        
      render :nothing => true
    end
    
    def paginate_with_join
      @developer_pages, @developers = paginate(:developers, 
                                             :join => 'LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id',
                                             :conditions => 'project_id=1')        
      render :nothing => true
    end
     
    def paginate_with_join_and_count
      @developer_pages, @developers = paginate(:developers, 
                                             :join => 'd LEFT JOIN developers_projects ON d.id = developers_projects.developer_id',
                                             :conditions => 'project_id=1',
                                             :count => "d.id")        
      render :nothing => true
    end


    def silence_deprecation_warnings
      ActiveSupport::Deprecation.silence do
        yield
      end
    end
    
    def rescue_errors(e) raise e end

    def rescue_action(e) raise end
    
  end
  
  def setup
    @controller = PaginationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end

  # Single Action Pagination Tests

  def test_simple_paginate
    get :simple_paginate
    assert_equal 1, assigns(:topic_pages).page_count
    assert_equal 3, assigns(:topics).size
  end
  
  def test_paginate_with_per_page
    get :paginate_with_per_page
    assert_equal 1, assigns(:topics).size
    assert_equal 3, assigns(:topic_pages).page_count
  end
  
  def test_paginate_with_order
    get :paginate_with_order
    expected = [topics(:futurama),
               topics(:harvey_birdman),
               topics(:rails)]
    assert_equal expected, assigns(:topics)
    assert_equal 1, assigns(:topic_pages).page_count
  end
  
  def test_paginate_with_order_by
    get :paginate_with_order
    expected = assigns(:topics)
    get :paginate_with_order_by
    assert_equal expected, assigns(:topics)  
    assert_equal 1, assigns(:topic_pages).page_count    
  end
  
  def test_paginate_with_conditions
    get :paginate_with_conditions
    expected = [topics(:rails)]
    assert_equal expected, assigns(:topics)
    assert_equal 1, assigns(:topic_pages).page_count
  end
  
  def test_paginate_with_class_name
    get :paginate_with_class_name
    
    assert assigns(:developers).size > 0
    assert_equal DeVeLoPeR, assigns(:developers).first.class
  end
      
  def test_paginate_with_joins
    get :paginate_with_joins
    assert_equal 2, assigns(:developers).size
    developer_names = assigns(:developers).map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end
  
  def test_paginate_with_join_and_conditions
    get :paginate_with_joins
    expected = assigns(:developers)
    get :paginate_with_join
    assert_equal expected, assigns(:developers)
  end
  
  def test_paginate_with_join_and_count
    get :paginate_with_joins
    expected = assigns(:developers)
    get :paginate_with_join_and_count
    assert_equal expected, assigns(:developers)
  end
  
  def test_paginate_with_include_and_order
    get :paginate_with_include_and_order
    expected = Topic.find(:all, :include => 'replies', :order => 'replies.created_at asc, topics.created_at asc', :limit => 10)
    assert_equal expected, assigns(:topics)
  end
end
