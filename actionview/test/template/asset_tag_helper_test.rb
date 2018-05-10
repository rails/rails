# frozen_string_literal: true

require "abstract_unit"
require "active_support/ordered_options"

class AssetTagHelperTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  attr_reader :request

  def setup
    super

    @controller = BasicController.new

    @request = Class.new do
      attr_accessor :script_name
      def protocol() "http://" end
      def ssl?() false end
      def host_with_port() "localhost" end
      def base_url() "http://www.example.com" end
      def send_early_hints(links) end
    end.new

    @controller.request = @request
  end

  def url_for(*_args)
    "http://www.example.com"
  end

  def content_security_policy_nonce
    "iyhD0Yc0W+c="
  end

  AssetPathToTag = {
    %(asset_path(""))             => %(),
    %(asset_path("   "))          => %(),
    %(asset_path("foo"))          => %(/foo),
    %(asset_path("style.css"))    => %(/style.css),
    %(asset_path("xmlhr.js"))     => %(/xmlhr.js),
    %(asset_path("xml.png"))      => %(/xml.png),
    %(asset_path("dir/xml.png"))  => %(/dir/xml.png),
    %(asset_path("/dir/xml.png")) => %(/dir/xml.png),

    %(asset_path("script.min"))       => %(/script.min),
    %(asset_path("script.min.js"))    => %(/script.min.js),
    %(asset_path("style.min"))        => %(/style.min),
    %(asset_path("style.min.css"))    => %(/style.min.css),

    %(asset_path("http://www.outside.com/image.jpg")) => %(http://www.outside.com/image.jpg),
    %(asset_path("HTTP://www.outside.com/image.jpg")) => %(HTTP://www.outside.com/image.jpg),

    %(asset_path("style", type: :stylesheet)) => %(/stylesheets/style.css),
    %(asset_path("xmlhr", type: :javascript)) => %(/javascripts/xmlhr.js),
    %(asset_path("xml.png", type: :image))    => %(/images/xml.png)
  }

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss)) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag(:json)) => %(<link href="http://www.example.com" rel="alternate" title="JSON" type="application/json" />),
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, "http://localhost/feed")) => %(<link href="http://localhost/feed" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, "//localhost/feed")) => %(<link href="//localhost/feed" rel="alternate" title="RSS" type="application/rss+xml" />),
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
    %(javascript_path("/super/xmlhr.js")) => %(/super/xmlhr.js),
    %(javascript_path("xmlhr.min")) => %(/javascripts/xmlhr.min.js),
    %(javascript_path("xmlhr.min.js")) => %(/javascripts/xmlhr.min.js),

    %(javascript_path("xmlhr.js?123")) => %(/javascripts/xmlhr.js?123),
    %(javascript_path("xmlhr.js?body=1")) => %(/javascripts/xmlhr.js?body=1),
    %(javascript_path("xmlhr.js#hash")) => %(/javascripts/xmlhr.js#hash),
    %(javascript_path("xmlhr.js?123#hash")) => %(/javascripts/xmlhr.js?123#hash)
  }

  PathToJavascriptToTag = {
    %(path_to_javascript("xmlhr")) => %(/javascripts/xmlhr.js),
    %(path_to_javascript("super/xmlhr")) => %(/javascripts/super/xmlhr.js),
    %(path_to_javascript("/super/xmlhr.js")) => %(/super/xmlhr.js)
  }

  JavascriptUrlToTag = {
    %(javascript_url("xmlhr")) => %(http://www.example.com/javascripts/xmlhr.js),
    %(javascript_url("super/xmlhr")) => %(http://www.example.com/javascripts/super/xmlhr.js),
    %(javascript_url("/super/xmlhr.js")) => %(http://www.example.com/super/xmlhr.js)
  }

  UrlToJavascriptToTag = {
    %(url_to_javascript("xmlhr")) => %(http://www.example.com/javascripts/xmlhr.js),
    %(url_to_javascript("super/xmlhr")) => %(http://www.example.com/javascripts/super/xmlhr.js),
    %(url_to_javascript("/super/xmlhr.js")) => %(http://www.example.com/super/xmlhr.js)
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("bank")) => %(<script src="/javascripts/bank.js" ></script>),
    %(javascript_include_tag("bank.js")) => %(<script src="/javascripts/bank.js" ></script>),
    %(javascript_include_tag("bank", :lang => "vbscript")) => %(<script lang="vbscript" src="/javascripts/bank.js" ></script>),
    %(javascript_include_tag("bank", :host => "assets.example.com")) => %(<script src="http://assets.example.com/javascripts/bank.js"></script>),

    %(javascript_include_tag("http://example.com/all")) => %(<script src="http://example.com/all"></script>),
    %(javascript_include_tag("http://example.com/all.js")) => %(<script src="http://example.com/all.js"></script>),
    %(javascript_include_tag("//example.com/all.js")) => %(<script src="//example.com/all.js"></script>),
  }

  StylePathToTag = {
    %(stylesheet_path("bank")) => %(/stylesheets/bank.css),
    %(stylesheet_path("bank.css")) => %(/stylesheets/bank.css),
    %(stylesheet_path('subdir/subdir')) => %(/stylesheets/subdir/subdir.css),
    %(stylesheet_path('/subdir/subdir.css')) => %(/subdir/subdir.css),
    %(stylesheet_path("style.min")) => %(/stylesheets/style.min.css),
    %(stylesheet_path("style.min.css")) => %(/stylesheets/style.min.css)
  }

  PathToStyleToTag = {
    %(path_to_stylesheet("style")) => %(/stylesheets/style.css),
    %(path_to_stylesheet("style.css")) => %(/stylesheets/style.css),
    %(path_to_stylesheet('dir/file')) => %(/stylesheets/dir/file.css),
    %(path_to_stylesheet('/dir/file.rcss', :extname => false)) => %(/dir/file.rcss),
    %(path_to_stylesheet('/dir/file', :extname => '.rcss')) => %(/dir/file.rcss)
  }

  StyleUrlToTag = {
    %(stylesheet_url("bank")) => %(http://www.example.com/stylesheets/bank.css),
    %(stylesheet_url("bank.css")) => %(http://www.example.com/stylesheets/bank.css),
    %(stylesheet_url('subdir/subdir')) => %(http://www.example.com/stylesheets/subdir/subdir.css),
    %(stylesheet_url('/subdir/subdir.css')) => %(http://www.example.com/subdir/subdir.css)
  }

  UrlToStyleToTag = {
    %(url_to_stylesheet("style")) => %(http://www.example.com/stylesheets/style.css),
    %(url_to_stylesheet("style.css")) => %(http://www.example.com/stylesheets/style.css),
    %(url_to_stylesheet('dir/file')) => %(http://www.example.com/stylesheets/dir/file.css),
    %(url_to_stylesheet('/dir/file.rcss', :extname => false)) => %(http://www.example.com/dir/file.rcss),
    %(url_to_stylesheet('/dir/file', :extname => '.rcss')) => %(http://www.example.com/dir/file.rcss)
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("bank")) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("bank.css")) => %(<link href="/stylesheets/bank.css" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("/elsewhere/file")) => %(<link href="/elsewhere/file.css" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("subdir/subdir")) => %(<link href="/stylesheets/subdir/subdir.css" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("bank", :media => "all")) => %(<link href="/stylesheets/bank.css" media="all" rel="stylesheet" />),
    %(stylesheet_link_tag("bank", :host => "assets.example.com")) => %(<link href="http://assets.example.com/stylesheets/bank.css" media="screen" rel="stylesheet" />),

    %(stylesheet_link_tag("http://www.example.com/styles/style")) => %(<link href="http://www.example.com/styles/style" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("http://www.example.com/styles/style.css")) => %(<link href="http://www.example.com/styles/style.css" media="screen" rel="stylesheet" />),
    %(stylesheet_link_tag("//www.example.com/styles/style.css")) => %(<link href="//www.example.com/styles/style.css" media="screen" rel="stylesheet" />),
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

  ImageUrlToTag = {
    %(image_url("xml"))          => %(http://www.example.com/images/xml),
    %(image_url("xml.png"))      => %(http://www.example.com/images/xml.png),
    %(image_url("dir/xml.png"))  => %(http://www.example.com/images/dir/xml.png),
    %(image_url("/dir/xml.png")) => %(http://www.example.com/dir/xml.png)
  }

  UrlToImageToTag = {
    %(url_to_image("xml"))          => %(http://www.example.com/images/xml),
    %(url_to_image("xml.png"))      => %(http://www.example.com/images/xml.png),
    %(url_to_image("dir/xml.png"))  => %(http://www.example.com/images/dir/xml.png),
    %(url_to_image("/dir/xml.png")) => %(http://www.example.com/dir/xml.png)
  }

  ImageLinkToTag = {
    %(image_tag("xml.png")) => %(<img src="/images/xml.png" />),
    %(image_tag("rss.gif", :alt => "rss syndication")) => %(<img alt="rss syndication" src="/images/rss.gif" />),
    %(image_tag("gold.png", :size => "20")) => %(<img height="20" src="/images/gold.png" width="20" />),
    %(image_tag("gold.png", :size => 20)) => %(<img height="20" src="/images/gold.png" width="20" />),
    %(image_tag("gold.png", :size => "45x70")) => %(<img height="70" src="/images/gold.png" width="45" />),
    %(image_tag("gold.png", "size" => "45x70")) => %(<img height="70" src="/images/gold.png" width="45" />),
    %(image_tag("error.png", "size" => "45 x 70")) => %(<img src="/images/error.png" />),
    %(image_tag("error.png", "size" => "x")) => %(<img src="/images/error.png" />),
    %(image_tag("google.com.png")) => %(<img src="/images/google.com.png" />),
    %(image_tag("slash..png")) => %(<img src="/images/slash..png" />),
    %(image_tag(".pdf.png")) => %(<img src="/images/.pdf.png" />),
    %(image_tag("http://www.rubyonrails.com/images/rails.png")) => %(<img src="http://www.rubyonrails.com/images/rails.png" />),
    %(image_tag("//www.rubyonrails.com/images/rails.png")) => %(<img src="//www.rubyonrails.com/images/rails.png" />),
    %(image_tag("mouse.png", :alt => nil)) => %(<img src="/images/mouse.png" />),
    %(image_tag("data:image/gif;base64,R0lGODlhAQABAID/AMDAwAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==", :alt => nil)) => %(<img src="data:image/gif;base64,R0lGODlhAQABAID/AMDAwAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==" />),
    %(image_tag("")) => %(<img src="" />),
    %(image_tag("gold.png", data: { title: 'Rails Application' })) => %(<img data-title="Rails Application" src="/images/gold.png" />),
    %(image_tag("rss.gif", srcset: "/assets/pic_640.jpg 640w, /assets/pic_1024.jpg 1024w")) => %(<img srcset="/assets/pic_640.jpg 640w, /assets/pic_1024.jpg 1024w" src="/images/rss.gif" />),
    %(image_tag("rss.gif", srcset: { "pic_640.jpg" => "640w", "pic_1024.jpg" => "1024w" })) => %(<img srcset="/images/pic_640.jpg 640w, /images/pic_1024.jpg 1024w" src="/images/rss.gif" />),
    %(image_tag("rss.gif", srcset: [["pic_640.jpg", "640w"], ["pic_1024.jpg", "1024w"]])) => %(<img srcset="/images/pic_640.jpg 640w, /images/pic_1024.jpg 1024w" src="/images/rss.gif" />)
  }

  FaviconLinkToTag = {
    %(favicon_link_tag) => %(<link href="/images/favicon.ico" rel="shortcut icon" type="image/x-icon" />),
    %(favicon_link_tag 'favicon.ico') => %(<link href="/images/favicon.ico" rel="shortcut icon" type="image/x-icon" />),
    %(favicon_link_tag 'favicon.ico', :rel => 'foo') => %(<link href="/images/favicon.ico" rel="foo" type="image/x-icon" />),
    %(favicon_link_tag 'favicon.ico', :rel => 'foo', :type => 'bar') => %(<link href="/images/favicon.ico" rel="foo" type="bar" />),
    %(favicon_link_tag 'mb-icon.png', :rel => 'apple-touch-icon', :type => 'image/png') => %(<link href="/images/mb-icon.png" rel="apple-touch-icon" type="image/png" />)
  }

  PreloadLinkToTag = {
    %(preload_link_tag '/styles/custom_theme.css') => %(<link rel="preload" href="/styles/custom_theme.css" as="style" type="text/css" />),
    %(preload_link_tag '/videos/video.webm') => %(<link rel="preload" href="/videos/video.webm" as="video" type="video/webm" />),
    %(preload_link_tag '/posts.json', as: 'fetch') => %(<link rel="preload" href="/posts.json" as="fetch" type="application/json" />),
    %(preload_link_tag '/users', as: 'fetch', type: 'application/json') => %(<link rel="preload" href="/users" as="fetch" type="application/json" />),
    %(preload_link_tag '//example.com/map?callback=initMap', as: 'fetch', type: 'application/javascript') => %(<link rel="preload" href="//example.com/map?callback=initMap" as="fetch" type="application/javascript" />),
    %(preload_link_tag '//example.com/font.woff2') => %(<link rel="preload" href="//example.com/font.woff2" as="font" type="font/woff2" crossorigin="anonymous"/>),
    %(preload_link_tag '//example.com/font.woff2', crossorigin: 'use-credentials') => %(<link rel="preload" href="//example.com/font.woff2" as="font" type="font/woff2" crossorigin="use-credentials" />),
    %(preload_link_tag '/media/audio.ogg', nopush: true) => %(<link rel="preload" href="/media/audio.ogg" as="audio" type="audio/ogg" />)
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

  VideoUrlToTag = {
    %(video_url("xml"))          => %(http://www.example.com/videos/xml),
    %(video_url("xml.ogg"))      => %(http://www.example.com/videos/xml.ogg),
    %(video_url("dir/xml.ogg"))  => %(http://www.example.com/videos/dir/xml.ogg),
    %(video_url("/dir/xml.ogg")) => %(http://www.example.com/dir/xml.ogg)
  }

  UrlToVideoToTag = {
    %(url_to_video("xml"))          => %(http://www.example.com/videos/xml),
    %(url_to_video("xml.ogg"))      => %(http://www.example.com/videos/xml.ogg),
    %(url_to_video("dir/xml.ogg"))  => %(http://www.example.com/videos/dir/xml.ogg),
    %(url_to_video("/dir/xml.ogg")) => %(http://www.example.com/dir/xml.ogg)
  }

  VideoLinkToTag = {
    %(video_tag("xml.ogg")) => %(<video src="/videos/xml.ogg"></video>),
    %(video_tag("rss.m4v", :autoplay => true, :controls => true)) => %(<video autoplay="autoplay" controls="controls" src="/videos/rss.m4v"></video>),
    %(video_tag("rss.m4v", :preload => 'none')) => %(<video preload="none" src="/videos/rss.m4v"></video>),
    %(video_tag("gold.m4v", :size => "160x120")) => %(<video height="120" src="/videos/gold.m4v" width="160"></video>),
    %(video_tag("gold.m4v", "size" => "320x240")) => %(<video height="240" src="/videos/gold.m4v" width="320"></video>),
    %(video_tag("trailer.ogg", :poster => "screenshot.png")) => %(<video poster="/images/screenshot.png" src="/videos/trailer.ogg"></video>),
    %(video_tag("error.avi", "size" => "100")) => %(<video height="100" src="/videos/error.avi" width="100"></video>),
    %(video_tag("error.avi", "size" => 100)) => %(<video height="100" src="/videos/error.avi" width="100"></video>),
    %(video_tag("error.avi", "size" => "100 x 100")) => %(<video src="/videos/error.avi"></video>),
    %(video_tag("error.avi", "size" => "x")) => %(<video src="/videos/error.avi"></video>),
    %(video_tag("http://media.rubyonrails.org/video/rails_blog_2.mov")) => %(<video src="http://media.rubyonrails.org/video/rails_blog_2.mov"></video>),
    %(video_tag("//media.rubyonrails.org/video/rails_blog_2.mov")) => %(<video src="//media.rubyonrails.org/video/rails_blog_2.mov"></video>),
    %(video_tag("multiple.ogg", "multiple.avi")) => %(<video><source src="/videos/multiple.ogg" /><source src="/videos/multiple.avi" /></video>),
    %(video_tag(["multiple.ogg", "multiple.avi"])) => %(<video><source src="/videos/multiple.ogg" /><source src="/videos/multiple.avi" /></video>),
    %(video_tag(["multiple.ogg", "multiple.avi"], :size => "160x120", :controls => true)) => %(<video controls="controls" height="120" width="160"><source src="/videos/multiple.ogg" /><source src="/videos/multiple.avi" /></video>)
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

  AudioUrlToTag = {
    %(audio_url("xml"))          => %(http://www.example.com/audios/xml),
    %(audio_url("xml.wav"))      => %(http://www.example.com/audios/xml.wav),
    %(audio_url("dir/xml.wav"))  => %(http://www.example.com/audios/dir/xml.wav),
    %(audio_url("/dir/xml.wav")) => %(http://www.example.com/dir/xml.wav)
  }

  UrlToAudioToTag = {
    %(url_to_audio("xml"))          => %(http://www.example.com/audios/xml),
    %(url_to_audio("xml.wav"))      => %(http://www.example.com/audios/xml.wav),
    %(url_to_audio("dir/xml.wav"))  => %(http://www.example.com/audios/dir/xml.wav),
    %(url_to_audio("/dir/xml.wav")) => %(http://www.example.com/dir/xml.wav)
  }

  AudioLinkToTag = {
    %(audio_tag("xml.wav")) => %(<audio src="/audios/xml.wav"></audio>),
    %(audio_tag("rss.wav", :autoplay => true, :controls => true)) => %(<audio autoplay="autoplay" controls="controls" src="/audios/rss.wav"></audio>),
    %(audio_tag("http://media.rubyonrails.org/audio/rails_blog_2.mov")) => %(<audio src="http://media.rubyonrails.org/audio/rails_blog_2.mov"></audio>),
    %(audio_tag("//media.rubyonrails.org/audio/rails_blog_2.mov")) => %(<audio src="//media.rubyonrails.org/audio/rails_blog_2.mov"></audio>),
    %(audio_tag("audio.mp3", "audio.ogg")) => %(<audio><source src="/audios/audio.mp3" /><source src="/audios/audio.ogg" /></audio>),
    %(audio_tag(["audio.mp3", "audio.ogg"])) => %(<audio><source src="/audios/audio.mp3" /><source src="/audios/audio.ogg" /></audio>),
    %(audio_tag(["audio.mp3", "audio.ogg"], :preload => 'none', :controls => true)) => %(<audio preload="none" controls="controls"><source src="/audios/audio.mp3" /><source src="/audios/audio.ogg" /></audio>)
  }

  FontPathToTag = {
    %(font_path("font.eot")) => %(/fonts/font.eot),
    %(font_path("font.eot#iefix")) => %(/fonts/font.eot#iefix),
    %(font_path("font.woff")) => %(/fonts/font.woff),
    %(font_path("font.ttf")) => %(/fonts/font.ttf),
    %(font_path("font.ttf?123")) => %(/fonts/font.ttf?123)
  }

  FontUrlToTag = {
    %(font_url("font.eot")) => %(http://www.example.com/fonts/font.eot),
    %(font_url("font.eot#iefix")) => %(http://www.example.com/fonts/font.eot#iefix),
    %(font_url("font.woff")) => %(http://www.example.com/fonts/font.woff),
    %(font_url("font.ttf")) => %(http://www.example.com/fonts/font.ttf),
    %(font_url("font.ttf?123")) => %(http://www.example.com/fonts/font.ttf?123),
    %(font_url("font.ttf", host: "http://assets.example.com")) => %(http://assets.example.com/fonts/font.ttf)
  }

  UrlToFontToTag = {
    %(url_to_font("font.eot")) => %(http://www.example.com/fonts/font.eot),
    %(url_to_font("font.eot#iefix")) => %(http://www.example.com/fonts/font.eot#iefix),
    %(url_to_font("font.woff")) => %(http://www.example.com/fonts/font.woff),
    %(url_to_font("font.ttf")) => %(http://www.example.com/fonts/font.ttf),
    %(url_to_font("font.ttf?123")) => %(http://www.example.com/fonts/font.ttf?123),
    %(url_to_font("font.ttf", host: "http://assets.example.com")) => %(http://assets.example.com/fonts/font.ttf)
  }

  def test_autodiscovery_link_tag_with_unknown_type_but_not_pass_type_option_key
    assert_raise(ArgumentError) do
      auto_discovery_link_tag(:xml)
    end
  end

  def test_autodiscovery_link_tag_with_unknown_type
    result = auto_discovery_link_tag(:xml, "/feed.xml", type: "application/xml")
    expected = %(<link href="/feed.xml" rel="alternate" title="XML" type="application/xml" />)
    assert_dom_equal expected, result
  end

  def test_asset_path_tag
    AssetPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_asset_path_tag_raises_an_error_for_nil_source
    e = assert_raise(ArgumentError) { asset_path(nil) }
    assert_equal("nil is not a valid asset source", e.message)
  end

  def test_asset_path_tag_to_not_create_duplicate_slashes
    @controller.config.asset_host = "host/"
    assert_dom_equal("http://host/foo", asset_path("foo"))

    @controller.config.relative_url_root = "/some/root/"
    assert_dom_equal("http://host/some/root/foo", asset_path("foo"))
  end

  def test_compute_asset_public_path
    assert_equal "/robots.txt", compute_asset_path("robots.txt")
    assert_equal "/robots.txt", compute_asset_path("/robots.txt")
    assert_equal "/javascripts/foo.js", compute_asset_path("foo.js", type: :javascript)
    assert_equal "/javascripts/foo.js", compute_asset_path("/foo.js", type: :javascript)
    assert_equal "/stylesheets/foo.css", compute_asset_path("foo.css", type: :stylesheet)
  end

  def test_auto_discovery_link_tag
    AutoDiscoveryToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_javascript_alias_for_javascript_path
    PathToJavascriptToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_url
    JavascriptUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_javascript_alias_for_javascript_url
    UrlToJavascriptToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include_tag
    JavascriptIncludeToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include_tag_with_missing_source
    assert_nothing_raised {
      javascript_include_tag("missing_security_guard")
    }

    assert_nothing_raised {
      javascript_include_tag("http://example.com/css/missing_security_guard")
    }
  end

  def test_javascript_include_tag_is_html_safe
    assert_predicate javascript_include_tag("prototype"), :html_safe?
  end

  def test_javascript_include_tag_relative_protocol
    @controller.config.asset_host = "assets.example.com"
    assert_dom_equal %(<script src="//assets.example.com/javascripts/prototype.js"></script>), javascript_include_tag("prototype", protocol: :relative)
  end

  def test_javascript_include_tag_default_protocol
    @controller.config.asset_host = "assets.example.com"
    @controller.config.default_asset_host_protocol = :relative
    assert_dom_equal %(<script src="//assets.example.com/javascripts/prototype.js"></script>), javascript_include_tag("prototype")
  end

  def test_javascript_include_tag_nonce
    assert_dom_equal %(<script src="/javascripts/bank.js" nonce="iyhD0Yc0W+c="></script>), javascript_include_tag("bank", nonce: true)
  end

  def test_stylesheet_path
    StylePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_stylesheet_alias_for_stylesheet_path
    PathToStyleToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_url
    StyleUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_stylesheet_alias_for_stylesheet_url
    UrlToStyleToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_link_tag
    StyleLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_link_tag_with_missing_source
    assert_nothing_raised {
      stylesheet_link_tag("missing_security_guard")
    }

    assert_nothing_raised {
      stylesheet_link_tag("http://example.com/css/missing_security_guard")
    }
  end

  def test_stylesheet_link_tag_without_request
    @request = nil
    assert_dom_equal(
      %(<link rel="stylesheet" media="screen" href="/stylesheets/foo.css" />),
      stylesheet_link_tag("foo.css")
    )
  end

  def test_stylesheet_link_tag_is_html_safe
    assert_predicate stylesheet_link_tag("dir/file"), :html_safe?
    assert_predicate stylesheet_link_tag("dir/other/file", "dir/file2"), :html_safe?
  end

  def test_stylesheet_link_tag_escapes_options
    assert_dom_equal %(<link href="/file.css" media="&lt;script&gt;" rel="stylesheet" />), stylesheet_link_tag("/file", media: "<script>")
  end

  def test_stylesheet_link_tag_should_not_output_the_same_asset_twice
    assert_dom_equal %(<link href="/stylesheets/wellington.css" media="screen" rel="stylesheet" />\n<link href="/stylesheets/amsterdam.css" media="screen" rel="stylesheet" />), stylesheet_link_tag("wellington", "wellington", "amsterdam")
  end

  def test_stylesheet_link_tag_with_relative_protocol
    @controller.config.asset_host = "assets.example.com"
    assert_dom_equal %(<link href="//assets.example.com/stylesheets/wellington.css" media="screen" rel="stylesheet" />), stylesheet_link_tag("wellington", protocol: :relative)
  end

  def test_stylesheet_link_tag_with_default_protocol
    @controller.config.asset_host = "assets.example.com"
    @controller.config.default_asset_host_protocol = :relative
    assert_dom_equal %(<link href="//assets.example.com/stylesheets/wellington.css" media="screen" rel="stylesheet" />), stylesheet_link_tag("wellington")
  end

  def test_javascript_include_tag_without_request
    @request = nil
    assert_dom_equal %(<script src="/javascripts/foo.js"></script>), javascript_include_tag("foo.js")
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_image_alias_for_image_path
    PathToImageToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_url
    ImageUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_image_alias_for_image_url
    UrlToImageToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_alt
    [nil, "/", "/foo/bar/", "foo/bar/"].each do |prefix|
      assert_deprecated do
        assert_equal "Rails", image_alt("#{prefix}rails.png")
      end
      assert_deprecated do
        assert_equal "Rails", image_alt("#{prefix}rails-9c0a079bdd7701d7e729bd956823d153.png")
      end
      assert_deprecated do
        assert_equal "Rails", image_alt("#{prefix}rails-f56ef62bc41b040664e801a38f068082a75d506d9048307e8096737463503d0b.png")
      end
      assert_deprecated do
        assert_equal "Long file name with hyphens", image_alt("#{prefix}long-file-name-with-hyphens.png")
      end
      assert_deprecated do
        assert_equal "Long file name with underscores", image_alt("#{prefix}long_file_name_with_underscores.png")
      end
    end
  end

  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_tag_does_not_modify_options
    options = { size: "16x10" }
    image_tag("icon", options)
    assert_equal({ size: "16x10" }, options)
  end

  def test_image_tag_raises_an_error_for_competing_size_arguments
    exception = assert_raise(ArgumentError) do
      image_tag("gold.png", height: "100", width: "200", size: "45x70")
    end

    assert_equal("Cannot pass a :size option with a :height or :width option", exception.message)
  end

  def test_favicon_link_tag
    FaviconLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_preload_link_tag
    PreloadLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_video_path
    VideoPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_path_to_video_alias_for_video_path
    PathToVideoToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_video_url
    VideoUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_video_alias_for_video_url
    UrlToVideoToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
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

  def test_audio_url
    AudioUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_audio_alias_for_audio_url
    UrlToAudioToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_audio_tag
    AudioLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_font_path
    FontPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_font_url
    FontUrlToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_url_to_font_alias_for_font_url
    UrlToFontToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_video_audio_tag_does_not_modify_options
    options = { autoplay: true }
    video_tag("video", options)
    assert_equal({ autoplay: true }, options)
    audio_tag("audio", options)
    assert_equal({ autoplay: true }, options)
  end

  def test_image_tag_interpreting_email_cid_correctly
    # An inline image has no need for an alt tag to be automatically generated from the cid:
    assert_equal '<img src="cid:thi%25%25sis@acontentid" />', image_tag("cid:thi%25%25sis@acontentid")
  end

  def test_image_tag_interpreting_email_adding_optional_alt_tag
    assert_equal '<img alt="Image" src="cid:thi%25%25sis@acontentid" />', image_tag("cid:thi%25%25sis@acontentid", alt: "Image")
  end

  def test_should_not_modify_source_string
    source = "/images/rails.png"
    copy = source.dup
    image_tag(source)
    assert_equal copy, source
  end

  class PlaceholderImage
    def blank?; true; end
    def to_s; "no-image-yet.png"; end
  end
  def test_image_path_with_blank_placeholder
    assert_equal "/images/no-image-yet.png", image_path(PlaceholderImage.new)
  end

  def test_image_path_with_asset_host_proc_returning_nil
    @controller.config.asset_host = Proc.new do |source|
      unless source.end_with?("tiff")
        "cdn.example.com"
      end
    end

    assert_equal "/images/file.tiff", image_path("file.tiff")
    assert_equal "http://cdn.example.com/images/file.png", image_path("file.png")
  end

  def test_image_url_with_asset_host_proc_returning_nil
    @controller.config.asset_host = Proc.new { nil }
    @controller.request = Struct.new(:base_url, :script_name).new("http://www.example.com", nil)

    assert_equal "/images/rails.png", image_path("rails.png")
    assert_equal "http://www.example.com/images/rails.png", image_url("rails.png")
  end

  def test_caching_image_path_with_caching_and_proc_asset_host_using_request
    @controller.config.asset_host = Proc.new do |source, request|
      if request.ssl?
        "#{request.protocol}#{request.host_with_port}"
      else
        "#{request.protocol}assets#{source.length}.example.com"
      end
    end

    @controller.request.stub(:ssl?, false) do
      assert_equal "http://assets15.example.com/images/xml.png", image_path("xml.png")
    end

    @controller.request.stub(:ssl?, true) do
      assert_equal "http://localhost/images/xml.png", image_path("xml.png")
    end
  end
end

class AssetTagHelperNonVhostTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  attr_reader :request

  def setup
    super
    @controller = BasicController.new
    @controller.config.relative_url_root = "/collaboration/hieraki"

    @request = Struct.new(:protocol, :base_url) do
      def send_early_hints(links); end
    end.new("gopher://", "gopher://www.example.com")
    @controller.request = @request
  end

  def url_for(_options)
    "http://www.example.com/collaboration/hieraki"
  end

  def test_should_compute_proper_path
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(/collaboration/hieraki/images/xml.png), image_path("xml.png"))
  end

  def test_should_return_nothing_if_asset_host_isnt_configured
    assert_nil compute_asset_host("foo")
  end

  def test_should_current_request_host_is_always_returned_for_request
    assert_equal "gopher://www.example.com", compute_asset_host("foo", protocol: :request)
  end

  def test_should_return_custom_host_if_passed_in_options
    assert_equal "http://custom.example.com", compute_asset_host("foo", host: "http://custom.example.com")
  end

  def test_should_ignore_relative_root_path_on_complete_url
    assert_dom_equal(%(http://www.example.com/images/xml.png), image_path("http://www.example.com/images/xml.png"))
  end

  def test_should_return_simple_string_asset_host
    @controller.config.asset_host = "assets.example.com"
    assert_equal "gopher://assets.example.com", compute_asset_host("foo")
  end

  def test_should_return_relative_asset_host
    @controller.config.asset_host = "assets.example.com"
    assert_equal "//assets.example.com", compute_asset_host("foo", protocol: :relative)
  end

  def test_should_return_custom_protocol_asset_host
    @controller.config.asset_host = "assets.example.com"
    assert_equal "ftp://assets.example.com", compute_asset_host("foo", protocol: "ftp")
  end

  def test_should_compute_proper_path_with_asset_host
    @controller.config.asset_host = "assets.example.com"
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/images/xml.png), image_path("xml.png"))
  end

  def test_should_compute_proper_path_with_asset_host_and_default_protocol
    @controller.config.asset_host = "assets.example.com"
    @controller.config.default_asset_host_protocol = :request
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/images/xml.png), image_path("xml.png"))
  end

  def test_should_compute_proper_url_with_asset_host
    @controller.config.asset_host = "assets.example.com"
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_url("xmlhr"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_url("style"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/images/xml.png), image_url("xml.png"))
  end

  def test_should_compute_proper_url_with_asset_host_and_default_protocol
    @controller.config.asset_host = "assets.example.com"
    @controller.config.default_asset_host_protocol = :request
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_url("xmlhr"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_url("style"))
    assert_dom_equal(%(gopher://assets.example.com/collaboration/hieraki/images/xml.png), image_url("xml.png"))
  end

  def test_should_return_asset_host_with_protocol
    @controller.config.asset_host = "http://assets.example.com"
    assert_equal "http://assets.example.com", compute_asset_host("foo")
  end

  def test_should_ignore_asset_host_on_complete_url
    @controller.config.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="http://bar.example.com/stylesheets/style.css" media="screen" rel="stylesheet" />), stylesheet_link_tag("http://bar.example.com/stylesheets/style.css"))
  end

  def test_should_ignore_asset_host_on_scheme_relative_url
    @controller.config.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="//bar.example.com/stylesheets/style.css" media="screen" rel="stylesheet" />), stylesheet_link_tag("//bar.example.com/stylesheets/style.css"))
  end

  def test_should_wildcard_asset_host
    @controller.config.asset_host = "http://a%d.example.com"
    assert_match(%r(http://a[0123]\.example\.com), compute_asset_host("foo"))
  end

  def test_should_wildcard_asset_host_between_zero_and_four
    @controller.config.asset_host = "http://a%d.example.com"
    assert_match(%r(http://a[0123]\.example\.com/collaboration/hieraki/images/xml\.png), image_path("xml.png"))
    assert_match(%r(http://a[0123]\.example\.com/collaboration/hieraki/images/xml\.png), image_url("xml.png"))
  end

  def test_asset_host_without_protocol_should_be_protocol_relative
    @controller.config.asset_host = "a.example.com"
    assert_equal "gopher://a.example.com/collaboration/hieraki/images/xml.png", image_path("xml.png")
    assert_equal "gopher://a.example.com/collaboration/hieraki/images/xml.png", image_url("xml.png")
  end

  def test_asset_host_without_protocol_should_be_protocol_relative_even_if_path_present
    @controller.config.asset_host = "a.example.com/files/go/here"
    assert_equal "gopher://a.example.com/files/go/here/collaboration/hieraki/images/xml.png", image_path("xml.png")
    assert_equal "gopher://a.example.com/files/go/here/collaboration/hieraki/images/xml.png", image_url("xml.png")
  end

  def test_assert_css_and_js_of_the_same_name_return_correct_extension
    assert_dom_equal(%(/collaboration/hieraki/javascripts/foo.js), javascript_path("foo"))
    assert_dom_equal(%(/collaboration/hieraki/stylesheets/foo.css), stylesheet_path("foo"))
  end
end

class AssetTagHelperWithoutRequestTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  undef :request

  def test_stylesheet_link_tag_without_request
    assert_dom_equal(
      %(<link rel="stylesheet" media="screen" href="/stylesheets/foo.css" />),
      stylesheet_link_tag("foo.css")
    )
  end

  def test_javascript_include_tag_without_request
    assert_dom_equal %(<script src="/javascripts/foo.js"></script>), javascript_include_tag("foo.js")
  end
end

class AssetUrlHelperControllerTest < ActionView::TestCase
  tests ActionView::Helpers::AssetUrlHelper

  def setup
    super

    @controller = BasicController.new
    @controller.extend ActionView::Helpers::AssetUrlHelper

    @request = Class.new do
      attr_accessor :script_name
      def protocol() "http://" end
      def ssl?() false end
      def host_with_port() "www.example.com" end
      def base_url() "http://www.example.com" end
    end.new

    @controller.request = @request
  end

  def test_asset_path
    assert_equal "/foo", @controller.asset_path("foo")
  end

  def test_asset_url
    assert_equal "http://www.example.com/foo", @controller.asset_url("foo")
  end
end

class AssetUrlHelperEmptyModuleTest < ActionView::TestCase
  tests ActionView::Helpers::AssetUrlHelper

  def setup
    super

    @module = Module.new
    @module.extend ActionView::Helpers::AssetUrlHelper
  end

  def test_asset_path
    assert_equal "/foo", @module.asset_path("foo")
  end

  def test_asset_url
    assert_equal "/foo", @module.asset_url("foo")
  end

  def test_asset_url_with_request
    @module.instance_eval do
      def request
        Struct.new(:base_url, :script_name).new("http://www.example.com", nil)
      end
    end

    assert @module.request
    assert_equal "http://www.example.com/foo", @module.asset_url("foo")
  end

  def test_asset_url_with_config_asset_host
    @module.instance_eval do
      def config
        Struct.new(:asset_host).new("http://www.example.com")
      end
    end

    assert @module.config.asset_host
    assert_equal "http://www.example.com/foo", @module.asset_url("foo")
  end

  def test_asset_url_with_custom_asset_host
    @module.instance_eval do
      def config
        Struct.new(:asset_host).new("http://www.example.com")
      end
    end

    assert @module.config.asset_host
    assert_equal "http://custom.example.com/foo", @module.asset_url("foo", host: "http://custom.example.com")
  end
end
