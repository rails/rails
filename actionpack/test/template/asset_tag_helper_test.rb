require 'abstract_unit'

class AssetTagHelperTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  def setup
    super
    silence_warnings do
      ActionView::Helpers::AssetTagHelper.send(
        :const_set,
        :JAVASCRIPTS_DIR,
        File.dirname(__FILE__) + "/../fixtures/public/javascripts"
      )

      ActionView::Helpers::AssetTagHelper.send(
        :const_set,
        :STYLESHEETS_DIR,
        File.dirname(__FILE__) + "/../fixtures/public/stylesheets"
      )

      ActionView::Helpers::AssetTagHelper.send(
        :const_set,
        :ASSETS_DIR,
        File.dirname(__FILE__) + "/../fixtures/public"
      )
    end

    @controller = Class.new do
      attr_accessor :request
      def url_for(*args) "http://www.example.com" end
    end.new

    @request = Class.new do
      def protocol() 'http://' end
      def ssl?() false end
      def host_with_port() 'localhost' end
    end.new

    @controller.request = @request

    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  def teardown
    ActionController::Base.perform_caching = false
    ActionController::Base.asset_host = nil
    ENV.delete('RAILS_ASSET_ID')
  end

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss)) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag(:xml)) => %(<link href="http://www.example.com" rel="alternate" title="XML" type="application/xml" />),
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, "http://localhost/feed")) => %(<link href="http://localhost/feed" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(nil, {}, {:type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="" type="text/html" />),
    %(auto_discovery_link_tag(nil, {}, {:title => "No stream.. really", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="No stream.. really" type="text/html" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="text/html" />),
    %(auto_discovery_link_tag(:atom, {}, {:rel => "Not so alternate"})) => %(<link href="http://www.example.com" rel="Not so alternate" title="ATOM" type="application/atom+xml" />),
  }

  JavascriptPathToTag = {
    %(javascript_path("xmlhr")) => %(/javascripts/xmlhr.js),
    %(javascript_path("super/xmlhr")) => %(/javascripts/super/xmlhr.js),
    %(javascript_path("/super/xmlhr.js")) => %(/super/xmlhr.js)
  }

  PathToJavascriptToTag = {
    %(path_to_javascript("xmlhr")) => %(/javascripts/xmlhr.js),
    %(path_to_javascript("super/xmlhr")) => %(/javascripts/super/xmlhr.js),
    %(path_to_javascript("/super/xmlhr.js")) => %(/super/xmlhr.js)
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("bank")) => %(<script src="/javascripts/bank.js" type="text/javascript"></script>),
    %(javascript_include_tag("bank.js")) => %(<script src="/javascripts/bank.js" type="text/javascript"></script>),
    %(javascript_include_tag("bank", :lang => "vbscript")) => %(<script lang="vbscript" src="/javascripts/bank.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script src="/javascripts/common.javascript" type="text/javascript"></script>\n<script src="/elsewhere/cools.js" type="text/javascript"></script>),
    %(javascript_include_tag(:defaults)) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>),
    %(javascript_include_tag(:all)) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
    %(javascript_include_tag(:all, :recursive => true)) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/subdir/subdir.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
    %(javascript_include_tag(:defaults, "bank")) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>),
    %(javascript_include_tag("bank", :defaults)) => %(<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>),

    %(javascript_include_tag("http://example.com/all")) => %(<script src="http://example.com/all" type="text/javascript"></script>),
    %(javascript_include_tag("http://example.com/all.js")) => %(<script src="http://example.com/all.js" type="text/javascript"></script>),
  }

  StylePathToTag = {
    %(stylesheet_path("bank")) => %(/stylesheets/bank.css),
    %(stylesheet_path("bank.css")) => %(/stylesheets/bank.css),
    %(stylesheet_path('subdir/subdir')) => %(/stylesheets/subdir/subdir.css),
    %(stylesheet_path('/subdir/subdir.css')) => %(/subdir/subdir.css)
  }

  PathToStyleToTag = {
    %(path_to_stylesheet("style")) => %(/stylesheets/style.css),
    %(path_to_stylesheet("style.css")) => %(/stylesheets/style.css),
    %(path_to_stylesheet('dir/file')) => %(/stylesheets/dir/file.css),
    %(path_to_stylesheet('/dir/file.rcss')) => %(/dir/file.rcss)
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("bank")) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("bank.css")) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("/elsewhere/file")) => %(<link href="/elsewhere/file.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("subdir/subdir")) => %(<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("bank", :media => "all")) => %(<link href="/stylesheets/bank.css" media="all" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag(:all)) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag(:all, :recursive => true)) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag(:all, :media => "all")) => %(<link href="/stylesheets/bank.css" media="all" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="all" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="all" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("random.styles", "/elsewhere/file")) => %(<link href="/stylesheets/random.styles" media="screen" rel="stylesheet" type="text/css" />\n<link href="/elsewhere/file.css" media="screen" rel="stylesheet" type="text/css" />),

    %(stylesheet_link_tag("http://www.example.com/styles/style")) => %(<link href="http://www.example.com/styles/style" media="screen" rel="stylesheet" type="text/css" />),
    %(stylesheet_link_tag("http://www.example.com/styles/style.css")) => %(<link href="http://www.example.com/styles/style.css" media="screen" rel="stylesheet" type="text/css" />),
  }

  ImagePathToTag = {
    %(image_path("xml"))          => %(/images/xml),
    %(image_path("xml.png"))      => %(/images/xml.png),
    %(image_path("dir/xml.png"))  => %(/images/dir/xml.png),
    %(image_path("/dir/xml.png")) => %(/dir/xml.png)
  }

  PathToImageToTag = {
    %(path_to_image("xml"))          => %(/images/xml),
    %(path_to_image("xml.png"))      => %(/images/xml.png),
    %(path_to_image("dir/xml.png"))  => %(/images/dir/xml.png),
    %(path_to_image("/dir/xml.png")) => %(/dir/xml.png)
  }

  ImageLinkToTag = {
    %(image_tag("xml.png")) => %(<img alt="Xml" src="/images/xml.png" />),
    %(image_tag("..jpg")) => %(<img alt="" src="/images/..jpg" />),
    %(image_tag("rss.gif", :alt => "rss syndication")) => %(<img alt="rss syndication" src="/images/rss.gif" />),
    %(image_tag("gold.png", :size => "45x70")) => %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />),
    %(image_tag("gold.png", "size" => "45x70")) => %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />),
    %(image_tag("error.png", "size" => "45")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("error.png", "size" => "45 x 70")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("error.png", "size" => "x")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("http://www.rubyonrails.com/images/rails.png")) => %(<img alt="Rails" src="http://www.rubyonrails.com/images/rails.png" />),
    %(image_tag("mouse.png", :mouseover => "/images/mouse_over.png")) => %(<img alt="Mouse" onmouseover="this.src='/images/mouse_over.png'" onmouseout="this.src='/images/mouse.png'" src="/images/mouse.png" />),
    %(image_tag("mouse.png", :mouseover => image_path("mouse_over.png"))) => %(<img alt="Mouse" onmouseover="this.src='/images/mouse_over.png'" onmouseout="this.src='/images/mouse.png'" src="/images/mouse.png" />)
  }

  VideoPathToTag = {
    %(video_path("xml"))          => %(/videos/xml),
    %(video_path("xml.ogg"))      => %(/videos/xml.ogg),
    %(video_path("dir/xml.ogg"))  => %(/videos/dir/xml.ogg),
    %(video_path("/dir/xml.ogg")) => %(/dir/xml.ogg)
  }

  PathToVideoToTag = {
    %(path_to_video("xml"))          => %(/videos/xml),
    %(path_to_video("xml.ogg"))      => %(/videos/xml.ogg),
    %(path_to_video("dir/xml.ogg"))  => %(/videos/dir/xml.ogg),
    %(path_to_video("/dir/xml.ogg")) => %(/dir/xml.ogg)
  }

  VideoLinkToTag = {
    %(video_tag("xml.ogg")) => %(<video src="/videos/xml.ogg" />),
    %(video_tag("rss.m4v", :autoplay => true, :controls => true)) => %(<video autoplay="autoplay" controls="controls" src="/videos/rss.m4v" />),
    %(video_tag("rss.m4v", :autobuffer => true)) => %(<video autobuffer="autobuffer" src="/videos/rss.m4v" />),
    %(video_tag("gold.m4v", :size => "160x120")) => %(<video height="120" src="/videos/gold.m4v" width="160" />),
    %(video_tag("gold.m4v", "size" => "320x240")) => %(<video height="240" src="/videos/gold.m4v" width="320" />),
    %(video_tag("trailer.ogg", :poster => "screenshot.png")) => %(<video poster="/images/screenshot.png" src="/videos/trailer.ogg" />),
    %(video_tag("error.avi", "size" => "100")) => %(<video src="/videos/error.avi" />),
    %(video_tag("error.avi", "size" => "100 x 100")) => %(<video src="/videos/error.avi" />),
    %(video_tag("error.avi", "size" => "x")) => %(<video src="/videos/error.avi" />),
    %(video_tag("http://media.rubyonrails.org/video/rails_blog_2.mov")) => %(<video src="http://media.rubyonrails.org/video/rails_blog_2.mov" />),
    %(video_tag(["multiple.ogg", "multiple.avi"])) => %(<video><source src="multiple.ogg" /><source src="multiple.avi" /></video>),
    %(video_tag(["multiple.ogg", "multiple.avi"], :size => "160x120", :controls => true)) => %(<video controls="controls" height="120" width="160"><source src="multiple.ogg" /><source src="multiple.avi" /></video>)
  }

 AudioPathToTag = {
    %(audio_path("xml"))          => %(/audios/xml),
    %(audio_path("xml.wav"))      => %(/audios/xml.wav),
    %(audio_path("dir/xml.wav"))  => %(/audios/dir/xml.wav),
    %(audio_path("/dir/xml.wav")) => %(/dir/xml.wav)
  }

  PathToAudioToTag = {
    %(path_to_audio("xml"))          => %(/audios/xml),
    %(path_to_audio("xml.wav"))      => %(/audios/xml.wav),
    %(path_to_audio("dir/xml.wav"))  => %(/audios/dir/xml.wav),
    %(path_to_audio("/dir/xml.wav")) => %(/dir/xml.wav)
  }

  AudioLinkToTag = {
    %(audio_tag("xml.wav")) => %(<audio src="/audios/xml.wav" />),
    %(audio_tag("rss.wav", :autoplay => true, :controls => true)) => %(<audio autoplay="autoplay" controls="controls" src="/audios/rss.wav" />),
    %(audio_tag("http://media.rubyonrails.org/audio/rails_blog_2.mov")) => %(<audio src="http://media.rubyonrails.org/audio/rails_blog_2.mov" />),
  }

  def test_auto_discovery_link_tag
    AutoDiscoveryToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_javascript_alias_for_javascript_path
    PathToJavascriptToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include_tag_with_blank_asset_id
    ENV["RAILS_ASSET_ID"] = ""
    JavascriptIncludeToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include_tag_with_missing_source
    assert_raise(Errno::ENOENT) {
      javascript_include_tag('missing_security_guard')
    }

    assert_raise(Errno::ENOENT) {
      javascript_include_tag(:defaults, 'missing_security_guard')
    }

    assert_nothing_raised {
      javascript_include_tag('http://example.com/css/missing_security_guard')
    }
  end

  def test_javascript_include_tag_with_given_asset_id
    ENV["RAILS_ASSET_ID"] = "1"
    assert_dom_equal(%(<script src="/javascripts/prototype.js?1" type="text/javascript"></script>\n<script src="/javascripts/effects.js?1" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js?1" type="text/javascript"></script>\n<script src="/javascripts/controls.js?1" type="text/javascript"></script>\n<script src="/javascripts/application.js?1" type="text/javascript"></script>), javascript_include_tag(:defaults))
  end

  def test_register_javascript_include_default
    ENV["RAILS_ASSET_ID"] = ""
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'bank'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
  end

  def test_register_javascript_include_default_mixed_defaults
    ENV["RAILS_ASSET_ID"] = ""
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'bank'
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'robber', '/elsewhere/cools.js'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/elsewhere/cools.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
  end

  def test_custom_javascript_expansions
    ENV["RAILS_ASSET_ID"] = ""
    ActionView::Helpers::AssetTagHelper::register_javascript_expansion :robbery => ["bank", "robber"]
    assert_dom_equal  %(<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>), javascript_include_tag('controls', :robbery, 'effects')
  end

  def test_custom_javascript_expansions_and_defaults_puts_application_js_at_the_end
    ENV["RAILS_ASSET_ID"] = ""
    ActionView::Helpers::AssetTagHelper::register_javascript_expansion :robbery => ["bank", "robber"]
    assert_dom_equal  %(<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>), javascript_include_tag('controls',:defaults, :robbery, 'effects')
  end

  def test_custom_javascript_expansions_with_undefined_symbol
    ActionView::Helpers::AssetTagHelper::register_javascript_expansion :monkey => nil
    assert_raise(ArgumentError) { javascript_include_tag('first', :monkey, 'last') }
  end

  def test_stylesheet_path
    ENV["RAILS_ASSET_ID"] = ""
    StylePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_stylesheet_alias_for_stylesheet_path
    PathToStyleToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_link_tag
    ENV["RAILS_ASSET_ID"] = ""
    StyleLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_link_tag_with_missing_source
    assert_raise(Errno::ENOENT) {
      stylesheet_link_tag('missing_security_guard')
    }

    assert_nothing_raised {
      stylesheet_link_tag('http://example.com/css/missing_security_guard')
    }
  end

  def test_custom_stylesheet_expansions
    ENV["RAILS_ASSET_ID"] = ''
    ActionView::Helpers::AssetTagHelper::register_stylesheet_expansion :robbery => ["bank", "robber"]
    assert_dom_equal  %(<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" type="text/css" />), stylesheet_link_tag('version.1.0', :robbery, 'subdir/subdir')
  end

  def test_custom_stylesheet_expansions_with_undefined_symbol
    ActionView::Helpers::AssetTagHelper::register_stylesheet_expansion :monkey => nil
    assert_raise(ArgumentError) { stylesheet_link_tag('first', :monkey, 'last') }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_image_alias_for_image_path
    PathToImageToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_tag_windows_behaviour
    old_asset_id, ENV["RAILS_ASSET_ID"] = ENV["RAILS_ASSET_ID"], "1"
    # This simulates the behaviour of File#exist? on windows when testing a file ending in "."
    # If the file "rails.png" exists, windows will return true when asked if "rails.png." exists (notice trailing ".")
    # OS X, linux etc will return false in this case.
    File.stubs(:exist?).with('template/../fixtures/public/images/rails.png.').returns(true)
    assert_equal '<img alt="Rails" src="/images/rails.png?1" />', image_tag('rails.png')
  ensure
    if old_asset_id
      ENV["RAILS_ASSET_ID"] = old_asset_id
    else
      ENV.delete("RAILS_ASSET_ID")
    end
  end

  def test_video_path
    VideoPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_video_alias_for_video_path
    PathToVideoToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_video_tag
    VideoLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_audio_path
    AudioPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_audio_alias_for_audio_path
    PathToAudioToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_audio_tag
    AudioLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_timebased_asset_id
    expected_time = File.stat(File.expand_path(File.dirname(__FILE__) + "/../fixtures/public/images/rails.png")).mtime.to_i.to_s
    assert_equal %(<img alt="Rails" src="/images/rails.png?#{expected_time}" />), image_tag("rails.png")
  end

  def test_timebased_asset_id_with_relative_url_root
      ActionController::Base.relative_url_root = "/collaboration/hieraki"
      expected_time = File.stat(File.expand_path(File.dirname(__FILE__) + "/../fixtures/public/images/rails.png")).mtime.to_i.to_s
      assert_equal %(<img alt="Rails" src="#{ActionController::Base.relative_url_root}/images/rails.png?#{expected_time}" />), image_tag("rails.png")
    ensure
      ActionController::Base.relative_url_root = ""
  end

  def test_should_skip_asset_id_on_complete_url
    assert_equal %(<img alt="Rails" src="http://www.example.com/rails.png" />), image_tag("http://www.example.com/rails.png")
  end

  def test_should_use_preset_asset_id
    ENV["RAILS_ASSET_ID"] = "4500"
    assert_equal %(<img alt="Rails" src="/images/rails.png?4500" />), image_tag("rails.png")
  end

  def test_preset_empty_asset_id
    ENV["RAILS_ASSET_ID"] = ""
    assert_equal %(<img alt="Rails" src="/images/rails.png" />), image_tag("rails.png")
  end

  def test_should_not_modify_source_string
    source = '/images/rails.png'
    copy = source.dup
    image_tag(source)
    assert_equal copy, source
  end

  def test_caching_image_path_with_caching_and_proc_asset_host_using_request
    ENV['RAILS_ASSET_ID'] = ''
    ActionController::Base.asset_host = Proc.new do |source, request|
      if request.ssl?
        "#{request.protocol}#{request.host_with_port}"
      else
        "#{request.protocol}assets#{source.length}.example.com"
      end
    end

    ActionController::Base.perform_caching = true


    @controller.request.stubs(:ssl?).returns(false)
    assert_equal "http://assets15.example.com/images/xml.png", image_path("xml.png")

    @controller.request.stubs(:ssl?).returns(true)
    assert_equal "http://localhost/images/xml.png", image_path("xml.png")
  end

  def test_caching_javascript_include_tag_when_caching_on
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a0.example.com'
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<script src="http://a0.example.com/javascripts/all.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => true)
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'all.js'))

    assert_dom_equal(
      %(<script src="http://a0.example.com/javascripts/money.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'money.js'))

    assert_dom_equal(
      %(<script src="http://a0.example.com/absolute/test.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "/absolute/test")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute', 'test.js'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'all.js'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'money.js'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute'))
  end

  def test_caching_javascript_include_tag_when_caching_on_with_proc_asset_host
    ENV['RAILS_ASSET_ID'] = ''
    ActionController::Base.asset_host = Proc.new { |source| "http://a#{source.length}.example.com" }
    ActionController::Base.perform_caching = true

    assert_equal '/javascripts/scripts.js'.length, 23
    assert_dom_equal(
      %(<script src="http://a23.example.com/javascripts/scripts.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => 'scripts')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'scripts.js'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'scripts.js'))
  end

  def test_caching_javascript_include_tag_when_caching_on_with_2_argument_proc_asset_host
    ENV['RAILS_ASSET_ID'] = ''
    ActionController::Base.asset_host = Proc.new { |source, request|
      if request.ssl?
        "#{request.protocol}#{request.host_with_port}"
      else
        "#{request.protocol}assets#{source.length}.example.com"
      end
    }
    ActionController::Base.perform_caching = true

    assert_equal '/javascripts/vanilla.js'.length, 23
    assert_dom_equal(
      %(<script src="http://assets23.example.com/javascripts/vanilla.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => 'vanilla')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'vanilla.js'))

    class << @controller.request
      def protocol() 'https://' end
      def ssl?() true end
    end

    assert_equal '/javascripts/secure.js'.length, 22
    assert_dom_equal(
      %(<script src="https://localhost/javascripts/secure.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => 'secure')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'secure.js'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'vanilla.js'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'secure.js'))
  end

  def test_caching_javascript_include_tag_when_caching_on_with_2_argument_object_asset_host
    ENV['RAILS_ASSET_ID'] = ''
    ActionController::Base.asset_host = Class.new do
      def call(source, request)
        if request.ssl?
          "#{request.protocol}#{request.host_with_port}"
        else
          "#{request.protocol}assets#{source.length}.example.com"
        end
      end
    end.new

    ActionController::Base.perform_caching = true

    assert_equal '/javascripts/vanilla.js'.length, 23
    assert_dom_equal(
      %(<script src="http://assets23.example.com/javascripts/vanilla.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => 'vanilla')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'vanilla.js'))

    class << @controller.request
      def protocol() 'https://' end
      def ssl?() true end
    end

    assert_equal '/javascripts/secure.js'.length, 22
    assert_dom_equal(
      %(<script src="https://localhost/javascripts/secure.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => 'secure')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'secure.js'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'vanilla.js'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'secure.js'))
  end

  def test_caching_javascript_include_tag_when_caching_on_and_using_subdirectory
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a%d.example.com'
    ActionController::Base.perform_caching = true

    hash = '/javascripts/cache/money.js'.hash % 4
    assert_dom_equal(
      %(<script src="http://a#{hash}.example.com/javascripts/cache/money.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "cache/money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'cache', 'money.js'))
  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'cache', 'money.js'))
  end

  def test_caching_javascript_include_tag_with_all_and_recursive_puts_defaults_at_the_start_of_the_file
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a0.example.com'
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<script src="http://a0.example.com/javascripts/combined.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "combined", :recursive => true)
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))

    assert_equal(
      %(// prototype js\n\n// effects js\n\n// dragdrop js\n\n// controls js\n\n// application js\n\n// bank js\n\n// robber js\n\n// subdir js\n\n\n// version.1.0 js),
      IO.read(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))
    )

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))
  end

  def test_caching_javascript_include_tag_with_all_puts_defaults_at_the_start_of_the_file
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a0.example.com'
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<script src="http://a0.example.com/javascripts/combined.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "combined")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))

    assert_equal(
      %(// prototype js\n\n// effects js\n\n// dragdrop js\n\n// controls js\n\n// application js\n\n// bank js\n\n// robber js\n\n// version.1.0 js),
      IO.read(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))
    )

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'combined.js'))
  end

  def test_caching_javascript_include_tag_with_relative_url_root
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.relative_url_root = "/collaboration/hieraki"
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<script src="/collaboration/hieraki/javascripts/all.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => true)
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'all.js'))

    assert_dom_equal(
      %(<script src="/collaboration/hieraki/javascripts/money.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'money.js'))

  ensure
    ActionController::Base.relative_url_root = nil
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'all.js'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'money.js'))
  end

  def test_caching_javascript_include_tag_when_caching_off
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.perform_caching = false

    assert_dom_equal(
      %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => true)
    )

    assert_dom_equal(
      %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/subdir/subdir.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => true, :recursive => true)
    )

    assert !File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'all.js'))

    assert_dom_equal(
      %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "money")
    )

    assert_dom_equal(
      %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/application.js" type="text/javascript"></script>\n<script src="/javascripts/bank.js" type="text/javascript"></script>\n<script src="/javascripts/robber.js" type="text/javascript"></script>\n<script src="/javascripts/subdir/subdir.js" type="text/javascript"></script>\n<script src="/javascripts/version.1.0.js" type="text/javascript"></script>),
      javascript_include_tag(:all, :cache => "money", :recursive => true)
    )

    assert !File.exist?(File.join(ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR, 'money.js'))
  end

  def test_caching_stylesheet_link_tag_when_caching_on
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a0.example.com'
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<link href="http://a0.example.com/stylesheets/all.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => true)
    )

    files_to_be_joined = Dir["#{ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR}/[^all]*.css"]

    expected_mtime = files_to_be_joined.map { |p| File.mtime(p) }.max
    assert_equal expected_mtime, File.mtime(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    bytes_added_by_join = "\n\n".size * files_to_be_joined.size - "\n\n".size
    expected_size = files_to_be_joined.sum { |p| File.size(p) } + bytes_added_by_join
    assert_equal expected_size, File.size(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    assert_dom_equal(
      %(<link href="http://a0.example.com/stylesheets/money.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => "money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))

    assert_dom_equal(
      %(<link href="http://a0.example.com/absolute/test.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => "/absolute/test")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute', 'test.css'))
  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute'))
  end

  def test_concat_stylesheet_link_tag_when_caching_off
    ENV["RAILS_ASSET_ID"] = ""

    assert_dom_equal(
      %(<link href="/stylesheets/all.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :concat => true)
    )

    expected = Dir["#{ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR}/*.css"].map { |p| File.mtime(p) }.max
    assert_equal expected, File.mtime(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    assert_dom_equal(
      %(<link href="/stylesheets/money.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :concat => "money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))

    assert_dom_equal(
      %(<link href="/absolute/test.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :concat => "/absolute/test")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute', 'test.css'))
  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'absolute'))
  end

  def test_caching_stylesheet_link_tag_when_caching_on_and_missing_css_file
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = 'http://a0.example.com'
    ActionController::Base.perform_caching = true

    assert_raise(Errno::ENOENT) {
      stylesheet_link_tag('bank', 'robber', 'missing_security_guard', :cache => true)
    }

    assert ! File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    assert_raise(Errno::ENOENT) {
      stylesheet_link_tag('bank', 'robber', 'missing_security_guard', :cache => "money")
    }

    assert ! File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
  end

  def test_caching_stylesheet_link_tag_when_caching_on_with_proc_asset_host
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.asset_host = Proc.new { |source| "http://a#{source.length}.example.com" }
    ActionController::Base.perform_caching = true

    assert_equal '/stylesheets/styles.css'.length, 23
    assert_dom_equal(
      %(<link href="http://a23.example.com/stylesheets/styles.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => 'styles')
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'styles.css'))

  ensure
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'styles.css'))
  end

  def test_caching_stylesheet_link_tag_with_relative_url_root
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.relative_url_root = "/collaboration/hieraki"
    ActionController::Base.perform_caching = true

    assert_dom_equal(
      %(<link href="/collaboration/hieraki/stylesheets/all.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => true)
    )

    files_to_be_joined = Dir["#{ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR}/[^all]*.css"]

    expected_mtime = files_to_be_joined.map { |p| File.mtime(p) }.max
    assert_equal expected_mtime, File.mtime(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    assert_dom_equal(
      %(<link href="/collaboration/hieraki/stylesheets/money.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => "money")
    )

    assert File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
  ensure
    ActionController::Base.relative_url_root = nil
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))
    FileUtils.rm_f(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
  end

  def test_caching_stylesheet_include_tag_when_caching_off
    ENV["RAILS_ASSET_ID"] = ""
    ActionController::Base.perform_caching = false

    assert_dom_equal(
      %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => true)
    )

    assert_dom_equal(
      %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => true, :recursive => true)
    )

    assert !File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'all.css'))

    assert_dom_equal(
      %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => "money")
    )

    assert_dom_equal(
      %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/robber.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/stylesheets/version.1.0.css" media="screen" rel="stylesheet" type="text/css" />),
      stylesheet_link_tag(:all, :cache => "money", :recursive => true)
    )

    assert !File.exist?(File.join(ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR, 'money.css'))
  end
end

class AssetTagHelperNonVhostTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  def setup
    super
    ActionController::Base.relative_url_root = "/collaboration/hieraki"

    @controller = Class.new do
      attr_accessor :request

      def url_for(options)
        "http://www.example.com/collaboration/hieraki"
      end
    end.new

    @request = Class.new do
      def protocol
        'gopher://'
      end
    end.new

    @controller.request = @request

    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  def teardown
    ActionController::Base.relative_url_root = nil
  end

  def test_should_compute_proper_path
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(/collaboration/hieraki/images/xml.png), image_path("xml.png"))
    assert_dom_equal(%(<img alt="Mouse" onmouseover="this.src='/collaboration/hieraki/images/mouse_over.png'" onmouseout="this.src='/collaboration/hieraki/images/mouse.png'" src="/collaboration/hieraki/images/mouse.png" />), image_tag("mouse.png", :mouseover => "/images/mouse_over.png"))
    assert_dom_equal(%(<img alt="Mouse2" onmouseover="this.src='/collaboration/hieraki/images/mouse_over2.png'" onmouseout="this.src='/collaboration/hieraki/images/mouse2.png'" src="/collaboration/hieraki/images/mouse2.png" />), image_tag("mouse2.png", :mouseover => image_path("mouse_over2.png")))
  end

  def test_should_ignore_relative_root_path_on_complete_url
    assert_dom_equal(%(http://www.example.com/images/xml.png), image_path("http://www.example.com/images/xml.png"))
  end

  def test_should_compute_proper_path_with_asset_host
    ActionController::Base.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/images/xml.png), image_path("xml.png"))
    assert_dom_equal(%(<img alt="Mouse" onmouseover="this.src='http://assets.example.com/collaboration/hieraki/images/mouse_over.png'" onmouseout="this.src='http://assets.example.com/collaboration/hieraki/images/mouse.png'" src="http://assets.example.com/collaboration/hieraki/images/mouse.png" />), image_tag("mouse.png", :mouseover => "/images/mouse_over.png"))
    assert_dom_equal(%(<img alt="Mouse2" onmouseover="this.src='http://assets.example.com/collaboration/hieraki/images/mouse_over2.png'" onmouseout="this.src='http://assets.example.com/collaboration/hieraki/images/mouse2.png'" src="http://assets.example.com/collaboration/hieraki/images/mouse2.png" />), image_tag("mouse2.png", :mouseover => image_path("mouse_over2.png")))
  ensure
    ActionController::Base.asset_host = ""
  end

  def test_should_ignore_asset_host_on_complete_url
    ActionController::Base.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="http://bar.example.com/stylesheets/style.css" media="screen" rel="stylesheet" type="text/css" />), stylesheet_link_tag("http://bar.example.com/stylesheets/style.css"))
  ensure
    ActionController::Base.asset_host = ""
  end

  def test_should_wildcard_asset_host_between_zero_and_four
    ActionController::Base.asset_host = 'http://a%d.example.com'
    assert_match %r(http://a[0123].example.com/collaboration/hieraki/images/xml.png), image_path('xml.png')
  ensure
    ActionController::Base.asset_host = nil
  end

  def test_asset_host_without_protocol_should_use_request_protocol
    ActionController::Base.asset_host = 'a.example.com'
    assert_equal 'gopher://a.example.com/collaboration/hieraki/images/xml.png', image_path('xml.png')
  ensure
    ActionController::Base.asset_host = nil
  end

  def test_asset_host_without_protocol_should_use_request_protocol_even_if_path_present
    ActionController::Base.asset_host = 'a.example.com/files/go/here'
    assert_equal 'gopher://a.example.com/files/go/here/collaboration/hieraki/images/xml.png', image_path('xml.png')
  ensure
    ActionController::Base.asset_host = nil
  end

  def test_assert_css_and_js_of_the_same_name_return_correct_extension
    assert_dom_equal(%(/collaboration/hieraki/javascripts/foo.js), javascript_path("foo"))
    assert_dom_equal(%(/collaboration/hieraki/stylesheets/foo.css), stylesheet_path("foo"))

  end
end
