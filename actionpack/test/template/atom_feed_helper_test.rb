require "#{File.dirname(__FILE__)}/../abstract_unit"

Scroll = Struct.new(:id, :to_param, :title, :body, :updated_at, :created_at)

class ScrollsController < ActionController::Base
  FEEDS = {}
  FEEDS["defaults"] = <<-EOT
        atom_feed do |feed|
          feed.title("My great blog!")
          feed.updated((@scrolls.first.created_at))

          for scroll in @scrolls
            feed.entry(scroll) do |entry|
              entry.title(scroll.title)
              entry.content(scroll.body, :type => 'html')

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
          feed.updated((@scrolls.first.created_at))

          for scroll in @scrolls
            feed.entry(scroll, :url => "/otherstuff/" + scroll.to_param, :updated => Time.utc(2007, 1, scroll.id)) do |entry|
              entry.title(scroll.title)
              entry.content(scroll.body, :type => 'html')

              entry.author do |author|
                author.name("DHH")
              end
            end
          end
        end
    EOT

  def index
    @scrolls = [
      Scroll.new(1, "1", "Hello One", "Something <i>COOL!</i>", Time.utc(2007, 12, 12, 15), Time.utc(2007, 12, 12, 15)),
      Scroll.new(2, "2", "Hello Two", "Something Boring", Time.utc(2007, 12, 12, 15)),
    ]
    
    render :inline => FEEDS[params[:id]], :type => :builder
  end
end

class AtomFeedTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = ScrollsController.new

    @request.host = "www.nextangle.com"
  end
  
  def test_feed_should_use_default_language_if_none_is_given
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_match %r{xml:lang="en-US"}, @response.body
    end
  end
  
  def test_feed_should_include_two_entries
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_select "entry", 2
    end
  end
  
  def test_entry_should_only_use_published_if_created_at_is_present
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_select "published", 1
    end
  end

  def test_entry_with_prefilled_options_should_use_those_instead_of_querying_the_record
    with_restful_routing(:scrolls) do
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