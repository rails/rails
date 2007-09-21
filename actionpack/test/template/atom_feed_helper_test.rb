require "#{File.dirname(__FILE__)}/../abstract_unit"

Post = Struct.new(:id, :to_param, :title, :body, :updated_at, :created_at)

class PostsController < ActionController::Base
  FEEDS = {}
  FEEDS["defaults"] = <<-EOT
        atom_feed do |feed|
          feed.title("My great blog!")
          feed.updated((@posts.first.created_at))

          for post in @posts
            feed.entry(post) do |entry|
              entry.title(post.title)
              entry.content(post.body, :type => 'html')

              entry.author do |author|
                author.name("DHH")
              end
            end
          end
        end
    EOT
    FEEDS["entry_options"] = <<-EOT
        atom_feed do |feed|
          feed.title("My great blog!")
          feed.updated((@posts.first.created_at))

          for post in @posts
            feed.entry(post, :url => "/otherstuff/" + post.to_param, :updated => Time.utc(2007, 1, post.id)) do |entry|
              entry.title(post.title)
              entry.content(post.body, :type => 'html')

              entry.author do |author|
                author.name("DHH")
              end
            end
          end
        end
    EOT

  def index
    @posts = [
      Post.new(1, "1", "Hello One", "Something <i>COOL!</i>", Time.utc(2007, 12, 12, 15), Time.utc(2007, 12, 12, 15)),
      Post.new(2, "2", "Hello Two", "Something Boring", Time.utc(2007, 12, 12, 15)),
    ]
    
    render :inline => FEEDS[params[:id]], :type => :builder
  end
end

class RenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = PostsController.new

    @request.host = "www.nextangle.com"
  end
  
  def test_feed_should_use_default_language_if_none_is_given
    with_restful_routing(:posts) do
      get :index, :id => "defaults"
      assert_match %r{xml:lang="en-US"}, @response.body
    end
  end
  
  def test_feed_should_include_two_entries
    with_restful_routing(:posts) do
      get :index, :id => "defaults"
      assert_select "entry", 2
    end
  end
  
  def test_entry_should_only_use_published_if_created_at_is_present
    with_restful_routing(:posts) do
      get :index, :id => "defaults"
      assert_select "published", 1
    end
  end

  def test_entry_with_prefilled_options_should_use_those_instead_of_querying_the_record
    with_restful_routing(:posts) do
      get :index, :id => "entry_options"

      assert_select "updated", Time.utc(2007, 1, 1).xmlschema
      assert_select "updated", Time.utc(2007, 1, 2).xmlschema
    end
  end


  private
    def with_restful_routing(resources)
      with_routing do |set|
        set.draw do |map|
          map.resources(resources)
        end
        yield
      end
    end
end