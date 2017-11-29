# frozen_string_literal: true

require "abstract_unit"

class ActiveModelHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ActiveModelHelper

  silence_warnings do
    Post = Struct.new(:author_name, :body, :category, :published, :updated_at) do
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
    @post.errors[:category] << "must exist"
    @post.errors[:published] << "must be accepted"
    @post.errors[:updated_at] << "bar"

    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.category    = "rails"
    @post.published   = false
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
    assert_dom_equal(expected_dom, select("post", "author_name", [:a, :b], include_blank: "Choose one..."))
    assert_dom_equal(expected_dom, select("post", "author_name", [:a, :b], prompt: "Choose one..."))
  end

  def test_select_grouped_options_with_errors
    grouped_options = [
      ["A", [["A1"], ["A2"]]],
      ["B", [["B1"], ["B2"]]],
    ]

    assert_dom_equal(
      %(<div class="field_with_errors"><select name="post[category]" id="post_category"><optgroup label="A"><option value="A1">A1</option>\n<option value="A2">A2</option></optgroup><optgroup label="B"><option value="B1">B1</option>\n<option value="B2">B2</option></optgroup></select></div>),
      select("post", "category", grouped_options)
    )
  end

  def test_collection_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><select name="post[author_name]" id="post_author_name"><option value="a">a</option>\n<option value="b">b</option></select></div>),
      collection_select("post", "author_name", [:a, :b], :to_s, :to_s)
    )
  end

  def test_date_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><select id="post_updated_at_1i" name="post[updated_at(1i)]">\n<option selected="selected" value="2004">2004</option>\n<option value="2005">2005</option>\n</select>\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="1" />\n</div>),
      date_select("post", "updated_at", discard_month: true, discard_day: true, start_year: 2004, end_year: 2005)
    )
  end

  def test_datetime_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_updated_at_1i" name="post[updated_at(1i)]" type="hidden" value="2004" />\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n<option selected="selected" value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]">\n<option selected="selected" value="00">00</option>\n</select>\n</div>),
      datetime_select("post", "updated_at", discard_year: true, discard_month: true, discard_day: true, minute_step: 60)
    )
  end

  def test_time_select_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input id="post_updated_at_1i" name="post[updated_at(1i)]" type="hidden" value="2004" />\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n<option selected="selected" value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]">\n<option selected="selected" value="00">00</option>\n</select>\n</div>),
      time_select("post", "updated_at", minute_step: 60)
    )
  end

  def test_label_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><label for="post_body">Body</label></div>),
      label("post", "body")
    )
  end

  def test_check_box_with_errors
    assert_dom_equal(
      %(<input name="post[published]" type="hidden" value="0" /><div class="field_with_errors"><input type="checkbox" value="1" name="post[published]" id="post_published" /></div>),
      check_box("post", "published")
    )
  end

  def test_check_boxes_with_errors
    assert_dom_equal(
      %(<input name="post[published]" type="hidden" value="0" /><div class="field_with_errors"><input type="checkbox" value="1" name="post[published]" id="post_published" /></div><input name="post[published]" type="hidden" value="0" /><div class="field_with_errors"><input type="checkbox" value="1" name="post[published]" id="post_published" /></div>),
      check_box("post", "published") + check_box("post", "published")
    )
  end

  def test_radio_button_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input type="radio" value="rails" checked="checked" name="post[category]" id="post_category_rails" /></div>),
      radio_button("post", "category", "rails")
    )
  end

  def test_radio_buttons_with_errors
    assert_dom_equal(
      %(<div class="field_with_errors"><input type="radio" value="rails" checked="checked" name="post[category]" id="post_category_rails" /></div><div class="field_with_errors"><input type="radio" value="java" name="post[category]" id="post_category_java" /></div>),
      radio_button("post", "category", "rails") + radio_button("post", "category", "java")
    )
  end

  def test_collection_check_boxes_with_errors
    assert_dom_equal(
      %(<input type="hidden" name="post[category][]" value="" /><div class="field_with_errors"><input type="checkbox" value="ruby" name="post[category][]" id="post_category_ruby" /></div><label for="post_category_ruby">ruby</label><div class="field_with_errors"><input type="checkbox" value="java" name="post[category][]" id="post_category_java" /></div><label for="post_category_java">java</label>),
      collection_check_boxes("post", "category", [:ruby, :java], :to_s, :to_s)
    )
  end

  def test_collection_radio_buttons_with_errors
    assert_dom_equal(
      %(<input type="hidden" name="post[category]" value="" /><div class="field_with_errors"><input type="radio" value="ruby" name="post[category]" id="post_category_ruby" /></div><label for="post_category_ruby">ruby</label><div class="field_with_errors"><input type="radio" value="java" name="post[category]" id="post_category_java" /></div><label for="post_category_java">java</label>),
      collection_radio_buttons("post", "category", [:ruby, :java], :to_s, :to_s)
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

  FIELD_ERROR_HTML_OPTIONS = {
    %(check_box("post", "published"))                       => %(<input name="post[published]" type="hidden" value="0" /><input type="checkbox" value="1" name="post[published]" id="post_published" class="is-invalid" data-error="invalid" />),
    %(check_box("post", "published", class: "my-checkbox")) => %(<input name="post[published]" type="hidden" value="0" /><input class="my-checkbox is-invalid" type="checkbox" value="1" name="post[published]" id="post_published" data-error="invalid" />),

    %(collection_check_boxes("post", "category", [:ruby, :java], :to_s, :to_s))                               => %(<input type="hidden" name="post[category][]" value="" /><input class="is-invalid" type="checkbox" value="ruby" name="post[category][]" id="post_category_ruby" data-error="invalid" /><label for="post_category_ruby">ruby</label><input class="is-invalid" type="checkbox" value="java" name="post[category][]" id="post_category_java" data-error="invalid" /><label for="post_category_java">java</label>),
    %(collection_check_boxes("post", "category", [:ruby, :java], :to_s, :to_s, {}, { class: "my-checkbox" })) => %(<input type="hidden" name="post[category][]" value="" /><input class="my-checkbox is-invalid" type="checkbox" value="ruby" name="post[category][]" id="post_category_ruby" data-error="invalid" /><label for="post_category_ruby">ruby</label><input class="my-checkbox is-invalid" type="checkbox" value="java" name="post[category][]" id="post_category_java" data-error="invalid" /><label for="post_category_java">java</label>),

    %(collection_radio_buttons("post", "category", [:ruby, :java], :to_s, :to_s))                            => %(<input type="hidden" name="post[category]" value="" /><input class="is-invalid" type="radio" value="ruby" name="post[category]" id="post_category_ruby" data-error="invalid" /><label for="post_category_ruby">ruby</label><input class="is-invalid" type="radio" value="java" name="post[category]" id="post_category_java" data-error="invalid" /><label for="post_category_java">java</label>),
    %(collection_radio_buttons("post", "category", [:ruby, :java], :to_s, :to_s, {}, { class: "my-radio" })) => %(<input type="hidden" name="post[category]" value="" /><input class="my-radio is-invalid" type="radio" value="ruby" name="post[category]" id="post_category_ruby" data-error="invalid" /><label for="post_category_ruby">ruby</label><input class="my-radio is-invalid" type="radio" value="java" name="post[category]" id="post_category_java" data-error="invalid" /><label for="post_category_java">java</label>),

    %(color_field("post", "body"))                    => %(<input value="#000000" type="color" name="post[body]" id="post_body" class="is-invalid" data-error="invalid" />),
    %(color_field("post", "body", class: "my-color")) => %(<input class="my-color is-invalid" value="#000000" type="color" name="post[body]" id="post_body" data-error="invalid" />),

    %(date_select("post", "updated_at", discard_month: true, discard_day: true, start_year: 2004, end_year: 2005))                                                                    => %(<select id="post_updated_at_1i" name="post[updated_at(1i)]" class="is-invalid" data-error="invalid">\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n</select>\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n),
    %(date_select("post", "updated_at", discard_month: true, discard_day: true, start_year: 2004, end_year: 2005, with_css_classes: true))                                            => %(<select id="post_updated_at_1i" name="post[updated_at(1i)]" class="is-invalid year" data-error="invalid">\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n</select>\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n),
    %(date_select("post", "updated_at", discard_month: true, discard_day: true, start_year: 2004, end_year: 2005, with_css_classes: { year: "my-year" }))                             => %(<select id="post_updated_at_1i" name="post[updated_at(1i)]" class="is-invalid my-year" data-error="invalid">\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n</select>\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n),
    %(date_select("post", "updated_at", { discard_day: true, use_month_numbers: true, start_year: 2004, end_year: 2005, with_css_classes: true }, class: "my-select"))                => %(<select id="post_updated_at_1i" name="post[updated_at(1i)]" class="my-select is-invalid year" data-error="invalid">\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n</select>\n<select id="post_updated_at_2i" name="post[updated_at(2i)]" class="my-select is-invalid month" data-error="invalid">\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6" selected="selected">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n</select>\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n),
    %(date_select("post", "updated_at", { discard_day: true, use_month_numbers: true, start_year: 2004, end_year: 2005, with_css_classes: { year: "my-year" } }, class: "my-select")) => %(<select id="post_updated_at_1i" name="post[updated_at(1i)]" class="my-select is-invalid my-year" data-error="invalid">\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n</select>\n<select id="post_updated_at_2i" name="post[updated_at(2i)]" class="my-select is-invalid" data-error="invalid">\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6" selected="selected">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n</select>\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n),

    %(datetime_select("post", "updated_at", discard_year: true, discard_month: true, discard_day: true, minute_step: 60, include_blank: true))                                                                  => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="is-invalid" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(datetime_select("post", "updated_at", discard_year: true, discard_month: true, discard_day: true, minute_step: 60, include_blank: true, with_css_classes: true))                                          => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid hour" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="is-invalid minute" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(datetime_select("post", "updated_at", discard_year: true, discard_month: true, discard_day: true, minute_step: 60, include_blank: true, with_css_classes: { hour: "my-hour" }))                           => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid my-hour" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="is-invalid" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(datetime_select("post", "updated_at", { discard_year: true, discard_month: true, discard_day: true, minute_step: 60, include_blank: true, with_css_classes: true }, class: "my-datetime"))                => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="my-datetime is-invalid hour" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="my-datetime is-invalid minute" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(datetime_select("post", "updated_at", { discard_year: true, discard_month: true, discard_day: true, minute_step: 60, include_blank: true, with_css_classes: { hour: "my-hour" } }, class: "my-datetime")) => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="1" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="my-datetime is-invalid my-hour" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="my-datetime is-invalid" data-error="invalid">\n<option value=""></option>\n<option value="00" selected="selected">00</option>\n</select>\n),

    %(email_field("post", "author_name"))                    => %(<input type="email" value="" name="post[author_name]" id="post_author_name" class="is-invalid" data-error="invalid" />),
    %(email_field("post", "author_name", class: "my-email")) => %(<input class="my-email is-invalid" type="email" value="" name="post[author_name]" id="post_author_name" data-error="invalid" />),

    %(file_field("post", "body"))                   => %(<input type="file" name="post[body]" id="post_body" class="is-invalid" data-error="invalid" />),
    %(file_field("post", "body", class: "my-file")) => %(<input class="my-file is-invalid" type="file" name="post[body]" id="post_body" data-error="invalid" />),

    %(hidden_field("post", "author_name")) => %(<input id="post_author_name" name="post[author_name]" type="hidden" value="" />),

    %(label("post", "body"))                            => %(<label class="is-invalid" for="post_body" data-error="invalid">Body</label>),
    %(label("post", "body", {}, { class: "my-label" })) => %(<label class="my-label is-invalid" for="post_body" data-error="invalid">Body</label>),

    %(password_field("post", "body"))                  => %(<input type="password" name="post[body]" id="post_body" class="is-invalid" data-error="invalid" />),
    %(password_field("post", "body", class: "my-pwd")) => %(<input class="my-pwd is-invalid" type="password" name="post[body]" id="post_body" data-error="invalid" />),

    %(radio_button("post", "category", "rails"))                    => %(<input type="radio" value="rails" checked="checked" name="post[category]" id="post_category_rails" class="is-invalid" data-error="invalid" />),
    %(radio_button("post", "category", "rails", class: "my-radio")) => %(<input class="my-radio is-invalid" type="radio" value="rails" checked="checked" name="post[category]" id="post_category_rails" data-error="invalid" />),

    %(select("post", "author_name", [:a, :b]))                         => %(<select name="post[author_name]" id="post_author_name" class="is-invalid" data-error="invalid"><option value="a">a</option>\n<option value="b">b</option></select>),
    %(select("post", "author_name", [:a, :b], {}, class: "my-author")) => %(<select class="my-author is-invalid" name="post[author_name]" id="post_author_name" data-error="invalid"><option value="a">a</option>\n<option value="b">b</option></select>),

    %(select("post", "author_name", [:a, :b], prompt: "Choose one..."))        => %(<select name="post[author_name]" id="post_author_name" class="is-invalid" data-error="invalid"><option value="">Choose one...</option>\n<option value="a">a</option>\n<option value="b">b</option></select>),
    %(select("post", "author_name", [:a, :b], include_blank: "Choose one...")) => %(<select name="post[author_name]" id="post_author_name" class="is-invalid" data-error="invalid"><option value="">Choose one...</option>\n<option value="a">a</option>\n<option value="b">b</option></select>),

    %(select("post", "category", [["A", [["A1"], ["A2"]]]]))                         => %(<select name="post[category]" id="post_category" class="is-invalid" data-error="invalid"><optgroup label="A"><option value="A1">A1</option>\n<option value="A2">A2</option></optgroup></select>),
    %(select("post", "category", [["A", [["A1"], ["A2"]]]], {}, class: "my-select")) => %(<select class="my-select is-invalid" name="post[category]" id="post_category" data-error="invalid"><optgroup label="A"><option value="A1">A1</option>\n<option value="A2">A2</option></optgroup></select>),

    %(text_field("post", "author_name"))                   => %(<input type="text" value="" name="post[author_name]" id="post_author_name" class="is-invalid" data-error="invalid" />),
    %(text_field("post", "author_name", class: "my-text")) => %(<input type="text" value="" name="post[author_name]" id="post_author_name" class="my-text is-invalid" data-error="invalid" />),

    %(text_area("post", "author_name"))                       => %(<textarea id="post_author_name" name="post[author_name]" class="is-invalid" data-error="invalid">\n</textarea>),
    %(text_area("post", "author_name", class: "my-textarea")) => %(<textarea id="post_author_name" name="post[author_name]" class="my-textarea is-invalid" data-error="invalid">\n</textarea>),

    %(time_select("post", "updated_at", minute_step: 60))                                                                                       => %(<input id="post_updated_at_1i" name="post[updated_at(1i)]" type="hidden" value="2004" />\n<input id="post_updated_at_2i" name="post[updated_at(2i)]" type="hidden" value="6" />\n<input id="post_updated_at_3i" name="post[updated_at(3i)]" type="hidden" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid" data-error="invalid">\n<option selected="selected" value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" class="is-invalid" data-error="invalid" name="post[updated_at(5i)]">\n<option selected="selected" value="00">00</option>\n</select>\n),
    %(time_select("post", "updated_at", { minute_step: 60, with_css_classes: true }))                                                           => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid hour" data-error="invalid">\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="is-invalid minute" data-error="invalid">\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(time_select("post", "updated_at", { minute_step: 60, with_css_classes: { hour: "my-hour", minute: "my-minute" } }))                       => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="is-invalid my-hour" data-error="invalid">\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="is-invalid my-minute" data-error="invalid">\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(time_select("post", "updated_at", { minute_step: 60, with_css_classes: true }, { class: "my-time" }))                                     => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="my-time is-invalid hour" data-error="invalid">\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="my-time is-invalid minute" data-error="invalid">\n<option value="00" selected="selected">00</option>\n</select>\n),
    %(time_select("post", "updated_at", { minute_step: 60, with_css_classes: { hour: "my-hour", minute: "my-minute" } }, { class: "my-time" })) => %(<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n<select id="post_updated_at_4i" name="post[updated_at(4i)]" class="my-time is-invalid my-hour" data-error="invalid">\n<option value="00" selected="selected">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_updated_at_5i" name="post[updated_at(5i)]" class="my-time is-invalid my-minute" data-error="invalid">\n<option value="00" selected="selected">00</option>\n</select>\n),
  }

  def test_field_error_html_options
    old_options = ActionView::Base.field_error_html_options
    old_proc = ActionView::Base.field_error_proc
    ActionView::Base.field_error_html_options = { class: "is-invalid", data: { error: "invalid" } }
    ActionView::Base.field_error_proc = Proc.new { |html_tag, instance| html_tag }

    FIELD_ERROR_HTML_OPTIONS.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  ensure
    ActionView::Base.field_error_html_options = old_options if old_options
    ActionView::Base.field_error_proc = old_proc if old_proc
  end
end
