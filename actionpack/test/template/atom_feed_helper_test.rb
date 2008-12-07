require 'abstract_unit'

Scroll = Struct.new(:id, :to_param, :title, :body, :updated_at, :created_at)

class ScrollsController < ActionController::Base
  FEEDS = {}
  FEEDS["defaults"] = <<-EOT
        atom_feed(:schema_date => '2008') do |feed|
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
    FEEDS["xml_block"] = <<-EOT
        atom_feed do |feed|
          feed.title("My great blog!")
          feed.updated((@scrolls.first.created_at))

          feed.author do |author|
            author.name("DHH")
          end

          for scroll in @scrolls
            feed.entry(scroll, :url => "/otherstuff/" + scroll.to_param, :updated => Time.utc(2007, 1, scroll.id)) do |entry|
              entry.title(scroll.title)
              entry.content(scroll.body, :type => 'html')
            end
          end
        end
    EOT
    FEEDS["feed_with_atomPub_namespace"] = <<-EOT
        atom_feed({'xmlns:app' => 'http://www.w3.org/2007/app',
                 'xmlns:openSearch' => 'http://a9.com/-/spec/opensearch/1.1/'}) do |feed|
          feed.title("My great blog!")
          feed.updated((@scrolls.first.created_at))

          for scroll in @scrolls
            feed.entry(scroll) do |entry|
              entry.title(scroll.title)
              entry.content(scroll.body, :type => 'html')
              entry.tag!('app:edited', Time.now)

              entry.author do |author|
                author.name("DHH")
              end
            end
          end
        end
    EOT
    FEEDS["feed_with_overridden_ids"] = <<-EOT
        atom_feed({:id => 'tag:test.rubyonrails.org,2008:test/'}) do |feed|
          feed.title("My great blog!")
          feed.updated((@scrolls.first.created_at))

          for scroll in @scrolls
            feed.entry(scroll, :id => "tag:test.rubyonrails.org,2008:"+scroll.id.to_s) do |entry|
              entry.title(scroll.title)
              entry.content(scroll.body, :type => 'html')
              entry.tag!('app:edited', Time.now)

              entry.author do |author|
                author.name("DHH")
              end
            end
          end
        end
    EOT
  FEEDS["feed_with_xml_processing_instructions"] = <<-EOT
        atom_feed(:schema_date => '2008',
          :instruct => {'xml-stylesheet' => { :href=> 't.css', :type => 'text/css' }}) do |feed|
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
  FEEDS["feed_with_xml_processing_instructions_duplicate_targets"] = <<-EOT
        atom_feed(:schema_date => '2008',
          :instruct => {'target1' => [{ :a => '1', :b => '2' }, { :c => '3', :d => '4' }]}) do |feed|
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
    FEEDS["feed_with_xhtml_content"] = <<-'EOT'
        atom_feed do |feed|
          feed.title("My great blog!")
          feed.updated((@scrolls.first.created_at))

          for scroll in @scrolls
            feed.entry(scroll) do |entry|
              entry.title(scroll.title)
              entry.summary(:type => 'xhtml') do |xhtml|
                xhtml.p "before #{scroll.id}"
                xhtml.p {xhtml << scroll.body}
                xhtml.p "after #{scroll.id}"
              end
              entry.tag!('app:edited', Time.now)

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

  protected

  def rescue_action(e)
    raise(e)
  end
end

class AtomFeedTest < ActionController::TestCase
  tests ScrollsController

  def setup
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

  def test_self_url_should_default_to_current_request_url
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_select "link[rel=self][href=http://www.nextangle.com/scrolls?id=defaults]"
    end
  end

  def test_feed_id_should_be_a_valid_tag
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_select "id", :text => "tag:www.nextangle.com,2008:/scrolls?id=defaults"
    end
  end

  def test_entry_id_should_be_a_valid_tag
    with_restful_routing(:scrolls) do
      get :index, :id => "defaults"
      assert_select "entry id", :text => "tag:www.nextangle.com,2008:Scroll/1"
      assert_select "entry id", :text => "tag:www.nextangle.com,2008:Scroll/2"
    end
  end

  def test_feed_should_allow_nested_xml_blocks
    with_restful_routing(:scrolls) do
      get :index, :id => "xml_block"
      assert_select "author name", :text => "DHH"
    end
  end

  def test_feed_should_include_atomPub_namespace
    with_restful_routing(:scrolls) do
      get :index, :id => "feed_with_atomPub_namespace"
      assert_match %r{xml:lang="en-US"}, @response.body
      assert_match %r{xmlns="http://www.w3.org/2005/Atom"}, @response.body
      assert_match %r{xmlns:app="http://www.w3.org/2007/app"}, @response.body
    end
  end

  def test_feed_should_allow_overriding_ids
    with_restful_routing(:scrolls) do
      get :index, :id => "feed_with_overridden_ids"
      assert_select "id", :text => "tag:test.rubyonrails.org,2008:test/"
      assert_select "entry id", :text => "tag:test.rubyonrails.org,2008:1"
      assert_select "entry id", :text => "tag:test.rubyonrails.org,2008:2"
    end
  end

  def test_feed_xml_processing_instructions
    with_restful_routing(:scrolls) do
      get :index, :id => 'feed_with_xml_processing_instructions'
      assert_match %r{<\?xml-stylesheet [^\?]*type="text/css"}, @response.body
      assert_match %r{<\?xml-stylesheet [^\?]*href="t.css"}, @response.body
    end
  end

  def test_feed_xml_processing_instructions_duplicate_targets
    with_restful_routing(:scrolls) do
      get :index, :id => 'feed_with_xml_processing_instructions_duplicate_targets'
      assert_match %r{<\?target1 (a="1" b="2"|b="2" a="1")\?>}, @response.body
      assert_match %r{<\?target1 (c="3" d="4"|d="4" c="3")\?>}, @response.body
    end
  end

  def test_feed_xhtml
    with_restful_routing(:scrolls) do
      get :index, :id => "feed_with_xhtml_content"
      assert_match %r{xmlns="http://www.w3.org/1999/xhtml"}, @response.body
      assert_select "summary div p", :text => "Something Boring"
      assert_select "summary div p", :text => "after 2"
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
