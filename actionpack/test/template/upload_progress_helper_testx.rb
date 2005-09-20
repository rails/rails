require File.dirname(__FILE__) + '/../abstract_unit'

require File.dirname(__FILE__) + '/../../lib/action_view/helpers/date_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/number_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/asset_tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/javascript_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/upload_progress_helper'
require File.dirname(__FILE__) + '/../../../activesupport/lib/active_support/core_ext/hash' #for stringify keys

class MockProgress
  def initialize(started, finished)
    @started, @finished = [started, finished]
  end

  def started?
    @started
  end

  def finished?
    @finished
  end

  def message
    "A message"
  end

  def method_missing(meth, *args)
    # Just return some consitant number
    meth.to_s.hash.to_i.abs + args.hash.to_i.abs
  end
end

class UploadProgressHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::UploadProgressHelper

  def next_upload_id; @upload_id = last_upload_id.succ; end
  def last_upload_id; @upload_id ||= 0; end
  def current_upload_id; last_upload_id; end
  def upload_progress(upload_id = nil); @upload_progress ||= MockProgress.new(false, true); end

  def setup
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com"
      end
    end
    @controller = @controller.new
  end

  def test_upload_status_tag
    assert_dom_equal(
      '<div class="progressBar" id="UploadProgressBar0"><div class="border"><div class="background"><div class="foreground"></div></div></div></div><div class="uploadStatus" id="UploadStatus0"></div>',
      upload_status_tag
    )
  end

  def test_upload_status_text_tag
    assert_dom_equal(
      '<div class="my-upload" id="my-id">Starting</div>',
      upload_status_text_tag('Starting', :class => 'my-upload', :id => 'my-id')
    )
  end


  def test_upload_progress_text
    @upload_progress = MockProgress.new(false, false)
    assert_equal(
      "Upload starting...",
      upload_progress_text
    )

    @upload_progress = MockProgress.new(true, false)
    assert_equal(
      "828.7 MB of 456.2 MB at 990.1 MB/s; 10227 days remaining",
      upload_progress_text
    )

    @upload_progress = MockProgress.new(true, true)
    assert_equal(
      "A message",
      upload_progress_text
    )
  end

  def test_upload_progress_update_bar_js
    assert_equal(
      "if($('UploadProgressBar0')){$('UploadProgressBar0').firstChild.firstChild.style.width='0%'}",
      upload_progress_update_bar_js
    )

    assert_equal(
      "if($('UploadProgressBar0')){$('UploadProgressBar0').firstChild.firstChild.style.width='50%'}",
      upload_progress_update_bar_js(50)
    )
  end

  def test_finish_upload_status
    assert_dom_equal(
      "<html><head><script language=\"javascript\" type=\"text/javascript\">function finish() { if (parent.document.uploadStatus0) { parent.document.uploadStatus0.stop();\n }\n }</script></head><body onload=\"finish()\"></body></html>",
      finish_upload_status
    )

    assert_dom_equal(
      "<html><head><script language=\"javascript\" type=\"text/javascript\">function finish() { if (parent.document.uploadStatus0) { parent.document.uploadStatus0.stop(123);\n }\n }</script></head><body onload=\"finish()\"></body></html>",
      finish_upload_status(:client_js_argument => 123)
    )

    assert_dom_equal(
      "<html><head><script language=\"javascript\" type=\"text/javascript\">function finish() { if (parent.document.uploadStatus0) { parent.document.uploadStatus0.stop();\nparent.location.replace('/redirected/');\n }\n }</script></head><body onload=\"finish()\"></body></html>",
      finish_upload_status(:redirect_to => '/redirected/')
    )
  end

  def test_form_tag_with_upload_progress
    assert_dom_equal(
      "<form action=\"http://www.example.com\" enctype=\"multipart/form-data\" method=\"post\" onsubmit=\"if (this.action.indexOf('upload_id') &lt; 0){ this.action += '?upload_id=1'; }this.target = 'UploadTarget1';$('UploadStatus1').innerHTML='Upload starting...'; if($('UploadProgressBar1')){$('UploadProgressBar1').firstChild.firstChild.style.width='0%'}; if (document.uploadStatus1) { document.uploadStatus1.stop(); }document.uploadStatus1 = new Ajax.PeriodicalUpdater('UploadStatus1','http://www.example.com', Object.extend({asynchronous:true, evalScripts:true, onComplete:function(request){$('UploadStatus1').innerHTML='A message';if($('UploadProgressBar1')){$('UploadProgressBar1').firstChild.firstChild.style.width='100%'};document.uploadStatus1 = null}},{decay:1.8,frequency:2.0})); return true\"><iframe id=\"UploadTarget1\" name=\"UploadTarget1\" src=\"\" style=\"width:0px;height:0px;border:0\"></iframe>",
      form_tag_with_upload_progress
    )
  end

  def test_form_tag_with_upload_progress_custom
    assert_dom_equal(
      "<form action=\"http://www.example.com\" enctype=\"multipart/form-data\" method=\"post\" onsubmit=\"if (this.action.indexOf('upload_id') &lt; 0){ this.action += '?upload_id=5'; }this.target = 'awindow';$('UploadStatus0').innerHTML='Upload starting...'; if($('UploadProgressBar0')){$('UploadProgressBar0').firstChild.firstChild.style.width='0%'}; alert('foo'); if (document.uploadStatus0) { document.uploadStatus0.stop(); }document.uploadStatus0 = new Ajax.PeriodicalUpdater('UploadStatus0','http://www.example.com', Object.extend({asynchronous:true, evalScripts:true, onComplete:function(request){$('UploadStatus0').innerHTML='A message';if($('UploadProgressBar0')){$('UploadProgressBar0').firstChild.firstChild.style.width='100%'};document.uploadStatus0 = null; alert('bar')}},{decay:7,frequency:6})); return true\" target=\"awindow\">",
      form_tag_with_upload_progress({:upload_id => 5}, {:begin => "alert('foo')", :finish => "alert('bar')", :frequency => 6, :decay => 7, :target => 'awindow'}) 
    )
  end
end
