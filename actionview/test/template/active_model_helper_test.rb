require "abstract_unit"

class ActiveModelHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ActiveModelHelper

  silence_warnings do
    class Post < Struct.new(:author_name, :body, :updated_at)
      include ActiveModel::Conversion
      include ActiveModel::Validations

      def persisted?
        false
      end
    end
  end

  def setup
    super

    @post = Post.new
    @post.errors[:author_name] << "can't be empty"
    @post.errors[:body] << "foo"
    @post.errors[:updated_at] << "bar"

    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.updated_at  = Date.new(2004, 6, 15)
  end

  def test_text_area_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><textarea id="post_body" name="post[body]">\nBack to the hill and over it again!</textarea></div>),
      text_area("post", "body")
    )
  end

  def test_text_field_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_author_name" name="post[author_name]" type="text" value="" /></div>),
      text_field("post", "author_name")
    )
  end

  def test_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><select name="post[author_name]" id="post_author_name"><option value="a">a</option>\n<option value="b">b</option></select></div>),
      select("post", "author_name", [:a, :b])
    )
  end

  def test_select_with_errors_and_blank_option
    expected_dom = %(<div class="field_with_errors"><select name="post[author_name]" id="post_author_name"><option value="">Choose one...</option>\n<option value="a">a</option>\n<option value="b">b</option></select></div>)
    assert_dom_equal(expected_dom, select("post", "author_name", [:a, :b], :include_blank => "Choose one..."))
    assert_dom_equal(expected_dom, select("post", "author_name", [:a, :b], :prompt => "Choose one..."))
  end

  def test_date_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><select id="post_updated_at_1i" name="post[updated_at(1i)]">\n<option selected="selected" value="2004">2004</option>\n<option value="2005">2005</option>\n</select>\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="1" />\n</div>),
      date_select("post", "updated_at", :discard_month => true, :discard_day => true, :start_year => 2004, :end_year => 2005)
    )
  end

  def test_datetime_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_updated_at_1i" name="post[updated_at(1i)]" type="hidden" value="2004" />\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n<option selected="selected" value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]">\n<option selected="selected" value="00">00</option>\n</select>\n</div>),
      datetime_select("post", "updated_at", :discard_year => true, :discard_month => true, :discard_day => true, :minute_step => 60)
    )
  end

  def test_time_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_updated_at_1i" name="post[updated_at(1i)]" type="hidden" value="2004" />\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n<option selected="selected" value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]">\n<option selected="selected" value="00">00</option>\n</select>\n</div>),
      time_select("post", "updated_at", :minute_step => 60)
    )
  end

  def test_hidden_field_does_not_render_errors
    assert_dom_equal(
      %(<input id="post_author_name" name="post[author_name]" type="hidden" value="" />),
      hidden_field("post", "author_name")
    )
  end

  def test_field_error_proc
    old_proc = ActionView::Base.field_error_proc
    ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
      raw(%(<div class=\"field_with_errors\">#{html_tag} <span class="error">#{[instance.error_message].join(', ')}</span></div>))
    end

    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_author_name" name="post[author_name]" type="text" value="" /> <span class="error">can't be empty</span></div>),
      text_field("post", "author_name")
    )
  ensure
    ActionView::Base.field_error_proc = old_proc if old_proc
  end

end
