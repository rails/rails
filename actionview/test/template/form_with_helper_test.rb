require "abstract_unit"
require "controller/fake_models"

class FormWithHelperTest < ActionView::TestCase
  tests ActionView::Helpers::FormTagHelper

  setup do
    @post = Post.new("Catch 22", "Joseph Heller", "The plotline follows...", 1, false, Date.new(2004, 6, 15))
    @comment = Comment.new
    @comment.body = "Awsome post"
    @post.comments = []
    @post.comments << @comment
    def @post.id; 0; end
    def @post.to_param; "77"; end

    I18n.backend.store_translations "label",
      activemodel: {
        attributes: {
          post: {
            cost: "Total cost"
          }
        }
      },
      helpers: {
        label: {
          post: {
            body: "Write entire text here",
          },
        }
      }

    I18n.backend.store_translations "placeholder",
      activemodel: {
        attributes: {
          post: {
            cost: "Total cost"
          },
          "post/cost": {
            uk: "Pounds"
          }
        }
      },
      helpers: {
        placeholder: {
          post: {
            title: "What is this about?",
            written_on: {
              spanish: "Escrito en"
            },
          }
        }
      }
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :customers
    resources :posts do
      resources :comments
    end
  end

  include Routes.url_helpers

  def test_label
    assert_tag_equal("<label>Title</label>") { |f| f.label("title") }
    assert_tag_equal("<label>The title goes here</label>") { |f| f.label("title", "The title goes here") }
    assert_tag_equal('<label for="title_label">Title</label>') { |f| f.label("title", for: "title_label") }
    assert_tag_equal('<label class="title_label">Title</label>') { |f| f.label("title", class: "title_label") }
    assert_tag_equal("<label>Secret?</label>") { |f| f.label("secret?") }
  end

  def test_label_with_symbols
    assert_tag_equal("<label>Title</label>") { |f| f.label(:title) }
    assert_tag_equal("<label>Secret?</label>") { |f| f.label(:"secret?") }
    assert_tag_equal('<label for="my_for">Title</label>') { |f| f.label(:title, for: :"my_for") }
  end

  def test_label_with_locales
    I18n.with_locale :label do
      assert_tag_equal("<label>Write entire text here</label>") { |f| f.label("body") }
      assert_tag_equal("<label>Write entire text here</label>") { |f| f.label(:body) }
    end
  end

  def test_label_with_human_attribute_name
    I18n.with_locale :label do
      assert_tag_equal("<label>Total cost</label>") { |f| f.label(:cost) }
    end
  end

  def test_label_with_locales_and_options
    I18n.with_locale :label do
      assert_tag_equal('<label class="post_body">Write entire text here</label>') { |f| f.label(:body, class: "post_body") }
    end
  end

  def test_label_with_non_active_record_object
    actual = form_with(model: OpenStruct.new(name:"ok"), url: "an_url", scope: "person") { |f| f.label(:name) }
    expected = whole_form("an_url", method: "post") { "<label>Name</label>" }
    assert_dom_equal expected, actual
  end

  def test_label_does_not_generate_for_attribute_when_given_nil
    assert_tag_equal("<label>Title</label>") { |f| f.label(:title, for: nil) }
    assert_tag_equal("<label>Title</label>") { |f| f.label(:title, class: nil) }
  end

  def test_label_with_attributes
    assert_tag_equal('<label id="my_id">Title</label>') { |f| f.label(:title, id: "my_id") }
    assert_tag_equal('<label id="my_id">Title</label>') { |f| f.label(:title, "id": "my_id") }
    assert_tag_equal('<label for="my_for" id="my_id">Title</label>') { |f| f.label(:title, for: "my_for", id: "my_id") }
    assert_tag_equal('<label for="my_for" id="my_id">Title</label>') { |f| f.label(:title, "for": "my_for", "id": "my_id") }
  end

  def test_label_with_block
    assert_tag_equal("<label>The title, please:</label>") { |f| f.label(:title) { "The title, please:" } }
  end

  def test_label_with_block_and_html
    assert_tag_equal('<label>Accept <a href="/terms">Terms</a>.</label>') { |f| f.label(:terms) { raw('Accept <a href="/terms">Terms</a>.') } }
  end

  def test_label_with_block_and_options
    assert_tag_equal('<label for="my_for">The title, please:</label>') { |f| f.label(:title, for: "my_for") { "The title, please:" } }
    assert_tag_equal('<label for="my_for">The title, please:</label>') { |f| f.label(:title, "for": "my_for") { "The title, please:" } }
  end

  def test_label_with_block_and_argument
    I18n.with_locale :label do
      assert_tag_equal("<label>Title</label>") { |f| f.label(:title) { |t| t } }
    end
  end

  def test_label_with_block_in_erb
    assert_dom_equal(
      %{\n<label>\n<input name="post[title]" type="text" value="Babe went home">\n</label>},
      view.render("test/field_with_label_with_block")
    )
  end

  def test_file_field_has_no_size
    assert_tag_equal('<input name="post[title]" type="file">') { |f| f.file_field(:title) }
  end

  def test_file_field_with_multiple_behavior
    assert_tag_equal('<input multiple="multiple" name="post[attachment][]" type="file">') { |f| f.file_field(:attachment, multiple: true) }
  end

  def test_file_field_with_multiple_behavior_and_explicit_name
    assert_tag_equal('<input multiple="multiple" name="custom" type="file">') { |f| f.file_field(:blah, multiple: true, name: "custom") }
    assert_tag_equal('<input multiple="multiple" name="custom[]" type="file">') { |f| f.file_field(:custom, multiple: true, scope: nil) }
  end

  def test_hidden_field
    assert_tag_equal('<input name="post[title]" type="hidden" value="Catch 22">') { |f| f.hidden_field("title") }
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1">') { |f| f.hidden_field("secret?") }
  end

  def test_hidden_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_tag_equal('<input name="post[title]" type="hidden" value="&lt;b&gt;Hello World&lt;/b&gt;">') { |f| f.hidden_field(:title) }
  end

  def test_hidden_field_with_nil_value
    assert_tag_equal('<input name="post[title]" type="hidden">') { |f| f.hidden_field("title", value: nil) }
  end

  def test_hidden_field_with_options
    assert_tag_equal('<input name="post[title]" type="hidden" value="Something Else">') { |f| f.hidden_field("title", "Something Else") }
  end

  def test_text_field_with_custom_type
    assert_tag_equal('<input name="post[title]" type="email" value="Catch 22">') { |f| f.text_field(:title, type: "email") }
  end

  def test_text_field
    assert_tag_equal('<input name="post[title]" type="text" value="Catch 22">') { |f| f.text_field("title") }
    assert_tag_equal('<input name="post[title]" type="password" value="Catch 22">') { |f| f.password_field("title", value: @post.title) }
    assert_tag_equal('<input name="post[title]" type="password">') { |f| f.password_field("title") }
  end

  def test_text_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_tag_equal('<input name="post[title]" type="text" value="&lt;b&gt;Hello World&lt;/b&gt;">') { |f| f.text_field("title") }
  end

  def test_text_field_with_html_entities
    @post.title = "The HTML Entity for & is &amp;"
    assert_tag_equal('<input name="post[title]" type="text" value="The HTML Entity for &amp; is &amp;amp;" ">') { |f| f.text_field("title") }
  end

  def test_text_field_with_options
    assert_tag_equal('<input name="post[title]" size="35" type="text" value="Catch 22">') { |f| f.text_field("title", size: 35) }
  end

  def test_text_field_assuming_size
    assert_tag_equal('<input maxlength="35" name="post[title]" size="35" type="text" value="Catch 22">') { |f| f.text_field("title", maxlength: 35) }
  end

  def test_text_field_removing_size
    assert_tag_equal('<input maxlength="35" name="post[title]" type="text" value="Catch 22">') { |f| f.text_field("title", maxlength: 35, size: nil) }
  end

  def test_text_field_with_nil_value
    assert_tag_equal('<input name="post[title]" type="text">') { |f| f.text_field("title", value: nil) }
  end

  def test_text_field_with_nil_name
    assert_tag_equal('<input type="text" value="Catch 22">') { |f| f.text_field("title", name: nil) }
  end

  def test_text_field_with_custom_scope
    assert_tag_equal("<input type='text' name='custom[title]' value='Catch 22'>") { |f| f.text_field :title, scope: "custom" }
  end

  def test_text_field_with_nil_scope
    assert_tag_equal("<input type='text' name='title' value='Catch 22'>") { |f| f.text_field :title, scope: nil }
  end

  def test_text_field_with_id
    assert_tag_equal("<input type='text' name='post[title]' value='Catch 22' id='this_is_post_title'>") { |f| f.text_field :title, id: "this_is_post_title" }
  end

  def test_text_field_with_value
    assert_tag_equal("<input type='text' name='post[title]' value='Closing Time'>") { |f| f.text_field :title, "Closing Time" }
  end

  def test_text_field_placeholder_without_locales
    I18n.with_locale :placeholder do
      assert_tag_equal('<input name="post[body]" placeholder="Body" type="text" value="The plotline follows...">') do |f|
        f.text_field(:body, placeholder: true)
      end
    end
  end

  def test_text_field_placeholder_with_locales
    I18n.with_locale :placeholder do
      assert_tag_equal('<input name="post[title]" placeholder="What is this about?" type="text" value="Catch 22">') do |f|
        f.text_field(:title, placeholder: true)
      end
    end
  end

  def test_text_field_placeholder_with_human_attribute_name
    I18n.with_locale :placeholder do
      assert_tag_equal('<input name="post[cost]" placeholder="Total cost" type="text">') do |f|
         f.text_field(:cost, placeholder: true)
       end
    end
  end

  def test_text_field_placeholder_with_string_value
    I18n.with_locale :placeholder do
      assert_tag_equal('<input id="post_cost" name="post[cost]" placeholder="HOW MUCH?" type="text">') do |f|
        text_field(:post, :cost, placeholder: "HOW MUCH?")
      end
    end
  end

  def test_text_field_placeholder_with_human_attribute_name_and_value
    I18n.with_locale :placeholder do
      assert_tag_equal('<input name="post[cost]" placeholder="Pounds" type="text">') do |f|
        f.text_field(:cost, placeholder: :uk)
      end
    end
  end

  def test_text_field_placeholder_with_locales_and_value
    I18n.with_locale :placeholder do
      assert_tag_equal('<input name="post[written_on]" placeholder="Escrito en" type="text" value="2004-06-15">') do |f|
         f.text_field(:written_on, placeholder: :spanish)
       end
    end
  end

  def test_checkbox
    assert_tag_equal("<input name='post[secret]' type='hidden' value='0'><input name='post[secret]' type='checkbox' checked='checked' value='1' >") do |f|
      f.check_box(:secret)
    end
  end

  def test_check_box_is_html_safe
    fields_with(model: @post) { |f| assert f.check_box("secret").html_safe? }
  end

  def test_check_box_checked_if_object_value_is_same_that_check_value
    assert_tag_equal('<input name="post[secret]" type="hidden" value="0"><input checked="checked" name="post[secret]" type="checkbox" value="1">') { |f| f.check_box("secret") }
  end

  def test_check_box_not_checked_if_object_value_is_same_that_unchecked_value
    @post.secret = 0
    assert_tag_equal('<input name="post[secret]" type="hidden" value="0"><input name="post[secret]" type="checkbox" value="1">') { |f| f.check_box("secret") }
  end

  def test_check_box_checked_if_option_checked_is_present
    assert_tag_equal('<input name="post[secret]" type="hidden" value="0"><input checked="checked" name="post[secret]" type="checkbox" value="1">') { |f| f.check_box("secret", checked: "checked") }
  end
  def test_check_box_checked_if_object_value_is_true
    @post.secret = true
    expected = '<input name="post[secret]" type="hidden" value="0"><input checked="checked" name="post[secret]" type="checkbox" value="1">'
    assert_tag_equal(expected) { |f| f.check_box(:secret) }
    assert_tag_equal(expected) { |f| f.check_box("secret") }
    assert_tag_equal(expected) { |f| f.check_box(:"secret?") }
    assert_tag_equal(expected) { |f| f.check_box("secret?") }
  end

  def test_check_box_with_include_hidden_false
    @post.secret = false
    assert_tag_equal('<input name="post[secret]" type="checkbox" value="1">') { |f| f.check_box("secret", include_hidden: false) }
  end

  def test_check_box_with_explicit_checked_and_unchecked_values_when_object_value_is_string
    @post.secret = "on"
    assert_tag_equal('<input name="post[secret]" type="hidden" value="off"><input checked="checked" name="post[secret]" type="checkbox" value="on">') { |f| f.check_box(:secret, on: "on", off: "off") }
    @post.secret = "off"
    assert_tag_equal('<input name="post[secret]" type="hidden" value="off"><input name="post[secret]" type="checkbox" value="on">') { |f| f.check_box(:secret, on: "on", off: "off") }
  end

  def test_check_box_with_explicit_checked_and_unchecked_values_when_object_value_is_boolean
    @post.secret = false
    assert_tag_equal('<input name="post[secret]" type="hidden" value="true"><input checked="checked" name="post[secret]" type="checkbox" value="false">') { |f| f.check_box(:secret,  on: false, off: true) }

    @post.secret = true
    assert_tag_equal('<input name="post[secret]" type="hidden" value="true"><input name="post[secret]" type="checkbox" value="false">') { |f| f.check_box(:secret, on: false, off: true) }
  end

  def test_check_box_with_explicit_checked_and_unchecked_values_when_object_value_is_integer
    @post.secret = 0
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input checked="checked" name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1) }
    @post.secret = 1
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1) }
    @post.secret = 2
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1) }
  end

  def test_check_box_with_explicit_checked_and_unchecked_values_when_object_value_is_float
    @post.secret = 0.0
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input checked="checked" name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret,on: 0, off: 1) }

    @post.secret = 1.1
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1) }

    @post.secret = 2.2
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off:1) }
  end

  def test_check_box_with_explicit_checked_and_unchecked_values_when_object_value_is_big_decimal
    @post.secret = BigDecimal.new(0)
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input checked="checked" name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1) }

    @post.secret = BigDecimal.new(1)
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box("secret", on: 0, off: 1) }

    @post.secret = BigDecimal.new(2.2, 1)
    assert_tag_equal('<input name="post[secret]" type="hidden" value="1"><input name="post[secret]" type="checkbox" value="0">') { |f| f.check_box(:secret, on: 0, off: 1)}
  end

  def test_check_box_with_nil_unchecked_value
    @post.secret = "on"
    assert_tag_equal('<input checked="checked" name="post[secret]" type="checkbox" value="on">') { |f| f.check_box(:secret, on: "on", off: nil) }
  end

  def test_check_box_with_nil_unchecked_value_is_html_safe
    fields_with(model: @post) { |f| assert f.check_box(:secret, on: "on", off: nil).html_safe? }
  end

  def test_check_box_with_multiple_behavior
    @post.comment_ids = [2,3]
    assert_tag_equal('<input name="post[comment_ids][]" type="hidden" value="0"><input name="post[comment_ids][]" type="checkbox" value="1">') { |f| f.check_box(:comment_ids, on: 1, multiple: true) }
    assert_tag_equal('<input name="post[comment_ids][]" type="hidden" value="0"><input checked="checked" name="post[comment_ids][]" type="checkbox" value="3">') { |f| f.check_box(:comment_ids, on: 3, multiple: true) }
  end

  def test_check_box_with_multiple_behavior_and_index
    @post.comment_ids = [2,3]
    assert_tag_equal('<input name="post[foo][comment_ids][]" type="hidden" value="0"><input name="post[foo][comment_ids][]" type="checkbox" value="1">') { |f| f.check_box(:comment_ids, on: 1, multiple: true, index: "foo") }
    assert_tag_equal('<input name="post[bar][comment_ids][]" type="hidden" value="0"><input checked="checked" name="post[bar][comment_ids][]" type="checkbox" value="3">') { |f| f.check_box(:comment_ids, on: 3, multiple: true, index: "bar") }
  end

  def test_checkbox_disabled_disables_hidden_field
    assert_tag_equal('<input name="post[secret]" type="hidden" value="0" disabled="disabled"><input checked="checked" disabled="disabled" name="post[secret]" type="checkbox" value="1">') { |f| f.check_box(:secret, disabled: true) }
  end

  def test_checkbox_form_html5_attribute
    assert_tag_equal('<input form="new_form" name="post[secret]" type="hidden" value="0" /><input checked="checked" form="new_form" name="post[secret]" type="checkbox" value="1" />') { |f| f.check_box(:secret, form: "new_form") }
  end

  def test_radio_button
    assert_tag_equal('<input name="post[title]" type="radio" value="Goodbye World">') do |f|
      f.radio_button("title", "Goodbye World")
    end
    assert_tag_equal('<input name="item[subobject][title]" type="radio" value="inside world">') do |f|
      f.radio_button("title", "inside world", scope: "item[subobject]")
    end
  end

  def test_radio_button_checked
    assert_tag_equal('<input checked="checked" name="post[title]" type="radio" value="Catch 22">') { |f| f.radio_button(:title, "Catch 22") }
    assert_tag_equal('<input checked="checked" name="post[secret]" type="radio" value="1">') { |f| f.radio_button(:secret, "1") }
  end

  def test_radio_button_with_negative_integer_value
    assert_tag_equal('<input name="post[secret]" type="radio" value="-1" />') { |f| f.radio_button(:secret, "-1") }
  end

  def test_radio_button_with_booleans
    assert_tag_equal('<input name="post[secret]" type="radio" value="true">') { |f| f.radio_button(:secret, true) }
    assert_tag_equal('<input name="post[secret]" type="radio" value="false">') { |f| f.radio_button(:secret, false) }
  end

  def test_text_area_placeholder_without_locales
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[body]' placeholder='Body'>\nThe plotline follows...</textarea>") do |f|
        f.text_area(:body, placeholder: true)
      end
    end
  end

  def test_text_area_placeholder_with_locales
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[title]' placeholder='What is this about?'>\nCatch 22</textarea>") do |f|
        f.text_area(:title, placeholder: true)
      end
    end
  end

  def test_text_area_placeholder_with_human_attribute_name
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[cost]' placeholder='Total cost'>\n</textarea>") do |f|
        f.text_area(:cost, placeholder: true)
      end
    end
  end

  def test_text_area_placeholder_with_string_value
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[cost]' placeholder='HOW MUCH?'>\n</textarea>") do |f|
        f.text_area(:cost, placeholder: "HOW MUCH?")
      end
    end
  end

  def test_text_area_placeholder_with_human_attribute_name_and_value
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[cost]' placeholder='Pounds'>\n</textarea>") do |f|
        f.text_area(:cost, placeholder: :uk)
      end
    end
  end

  def test_text_area_placeholder_with_locales_and_value
    I18n.with_locale :placeholder do
      assert_tag_equal("<textarea name='post[written_on]' placeholder='Escrito en'>\n2004-06-15</textarea>") do |f|
        f.text_area(:written_on, placeholder: :spanish)
      end
    end
  end

  def test_text_area
    assert_tag_equal("<textarea name='post[body]'>\nThe plotline follows...</textarea>") do |f|
      f.text_area("body")
    end
  end

  def test_text_area_with_escapes
    @post.body = "Back to <i>the</i> hill and over it again!"
    assert_tag_equal("<textarea name='post[body]'>\nBack to &lt;i&gt;the&lt;/i&gt; hill and over it again!</textarea>") do |f|
      f.text_area("body")
    end
  end

  def test_text_area_with_value
    assert_tag_equal("<textarea name='post[body]'>\nTesting alternate values.</textarea>") do |f|
      f.text_area(:body, "Testing alternate values.")
    end
    assert_tag_equal("<textarea name='post[body]'>\nTesting alternate values.</textarea>") do |f|
      f.text_area(:body, content: "Testing alternate values.")
    end
  end

  def test_text_area_with_nil_alternate_value
    assert_tag_equal("<textarea name='post[body]'>\n</textarea>") do |f|
      f.text_area(:body, content: nil)
    end
  end

  def test_text_area_with_html_entities
    @post.body = "The HTML Entity for & is &amp;"
    assert_tag_equal("<textarea name='post[body]'>\nThe HTML Entity for &amp; is &amp;amp;</textarea>") do |f|
      f.text_area(:body)
    end
  end

  def test_url_field
    assert_tag_equal('<input name="post[cost]" type="url">') { |f| f.url_field("cost") }
  end

  def test_email_field
    assert_tag_equal('<input name="post[cost]" type="email">') { |f| f.email_field("cost") }
  end

  def test_select_with_choices_as_pairs
    categories = [%w(Volvo volvo), %w(Saab saab), %w(Mercedes mercedes)]
    expected = "<select name='post[category]'>" +
        "<option value='volvo'>Volvo</option>\n" +
        "<option value='saab'>Saab</option>\n" +
        "<option value='mercedes'>Mercedes</option>" +
      "</select>"
    assert_tag_equal(expected) { |f| f.select :category, categories }
    assert_tag_equal(expected) { |f| f.select "category", categories }
  end

  def test_select_choices_as_array
    categories = %w(volvo saab mercedes)
    expected = "<select name='post[category]'>" +
        "<option value=''></option>" +
        "<option value='volvo'>volvo</option>\n" +
        "<option value='saab'>saab</option>\n" +
        "<option value='mercedes'>mercedes</option>" +
      "</select>"
    assert_tag_equal(expected) { |f| f.select :category, categories, blank: true }
    assert_tag_equal(expected) { |f| f.select "category", categories, blank: true }
  end

  def test_collection_select
    expected = "<select name='post[author_name]'>" +
        "<option value='&lt;Abe&gt;'>&lt;Abe&gt;</option>\n" +
        "<option value='Babe'>Babe</option>\n" +
        "<option value='Cabe'>Cabe</option>" +
      "</select>"
    assert_tag_equal(expected) { |f| f.select(:author_name, collection: dummy_posts, value: :author_name, text: :author_name) }
    assert_tag_equal(expected) { |f| f.select("author_name", collection: dummy_posts, value: "author_name", text: "author_name") }
  end

  def test_nested_fields
    actual = fields_with(model: @post) do |f|
      concat f.fields(model: @comment) { |c| concat c.text_field(:body) }
    end
    assert_dom_equal "<input name='post[comment][body]' type='text' value='Awsome post'>", actual
  end

  def test_nested_fields_indexed
    actual = fields_with(model: @post, indexed: true) do |f|
      concat f.text_field(:title)
      concat f.fields(model: @comment, indexed: true) { |c| concat c.text_field(:name) }
    end
    expected = "<input name='post[77][title]' type='text' value='Catch 22'><input name='post[77][comment][][name]' type='text' value='new comment'>"
    assert_dom_equal expected, actual
  end

  def test_double_nested_fields_indexed
    @comment.save
    actual = fields_with(scope: :posts) do |f|
      f.fields(model: @post, indexed: true) do |f2|
        @post.comments.each do |comment|
          concat f2.fields(model: comment, indexed: true) { |c| concat c.text_field(:name) }
        end
      end
    end
    expected = "<input name='posts[post][77][comment][1][name]' type='text' value='comment #1'>"
    assert_dom_equal expected, actual
  end

  def test_nested_fields_with_index
    actual = fields_with(model: @post, index: 1) do |c|
      concat c.text_field(:title)
      concat c.fields(model: @comment, index: 1) { |r| concat r.text_field(:name) }
    end
    expected = "<input name='post[1][title]' type='text' value='Catch 22'><input name='post[1][comment][1][name]' type='text' value='new comment'>"
    assert_dom_equal expected, actual
  end

  def test_nested_fields_with_as
    actual = fields_with(model: @post, scope: "thepost") do |f|
      concat f.fields(model: @post, as: "comment") { |c| concat c.text_field(:title) }
    end
    expected = "<input name='thepost[comment][title]' type='text' value='Catch 22'>"
    assert_dom_equal expected, actual
  end

  def test_nested_fields_with_index_and_as
    actual = fields_with(model: @post, scope: "postie", index: 6) do |f|
      concat f.fields(model: @post, as: "comment", index: 9) { |c|
        concat c.text_field(:title)
        concat c.radio_button(:title, "hello")
      }
    end
    expected = "<input name='postie[6][comment][9][title]' type='text' value='Catch 22'><input name='postie[6][comment][9][title]' type='radio' value='hello'>"
    assert_dom_equal expected, actual
  end

  def test_form_with_url
    expected = whole_form("/posts", remote: true) do
      "<label>The Title</label>" +
      "<input type='text' name='title'>" +
      "<textarea name='body'>\n</textarea>" +
      "<input name='commit' value='Save changes' data-disable-with='Save changes' type='submit'>"
    end
    actual = form_with(url: "/posts") do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_url_and_scope
    expected = whole_form("/posts", remote: true) do
      "<label>The Title</label>" +
      "<input type='text' name='post[title]'>" +
      "<textarea name='post[body]'>\n</textarea>" +
      "<input name='commit' value='Save Post' data-disable-with='Save Post' type='submit'>"
    end

    actual = form_with(url: "/posts", scope: :post) do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end

    assert_dom_equal  expected, actual
  end

  def test_form_with_model
    expected = whole_form("/posts", remote: true) do
      "<label>The Title</label>" +
      "<input type='text' name='post[title]' value='Catch 22'>" +
      "<textarea name='post[body]'>\nThe plotline follows...</textarea>" +
      "<input name='commit' value='Create Post' data-disable-with='Create Post' type='submit'>"
    end

    actual = form_with(model: @post) do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end

    assert_dom_equal expected, actual
  end

  def test_form_with_non_persisted_model
    customer = Customer.new("John")
    expected = whole_form("/customers", method: "post")
    actual = form_with(model: customer)
    assert_dom_equal expected, actual
  end

  def test_form_with_persisted_model
    customer = Customer.new("John", 123)
    expected = whole_form("/customers/123", method: "patch")
    actual = form_with(model: customer)
    assert_dom_equal expected, actual
  end

  def test_form_with_nested_persisted
    comment = Comment.new.tap { |c| c.save }
    expected = whole_form("/posts/77/comments/1", method: "patch")
    actual = form_with(model: [@post, comment])
    assert_dom_equal expected, actual
  end

  def test_form_with_nested_non_persisted
    expected = whole_form("/posts/77/comments", method: "post")
    actual = form_with(model: [@post, @comment])
    assert_dom_equal expected, actual
  end

  def test_form_with_custom_id_and_class
    expected = whole_form("/posts", remote: true, id: "post_id", class: "post_class")
    assert_dom_equal expected, form_with(model: @post, class: "post_class", id: "post_id")
  end

  def test_form_with_custom_attribute
    expected = whole_form("/posts", remote: true, autocomplete: "on")
    assert_dom_equal expected, form_with(model: @post, autocomplete: "on")
  end

  def test_form_with_data_attributes
    expected = whole_form("/posts", remote: true, "data-test": "test")
    assert_dom_equal expected, form_with(model: @post, "data-test": "test")
    assert_dom_equal expected, form_with(model: @post, data: {test: "test"} )
  end

  def test_fields_for_returns_block_result
    output = fields_with(model: Post.new) { |f| "fields" }
    assert_equal "fields", output
  end

  protected

    def assert_tag_equal(expected, model: @post, &actual)
      assert_dom_equal expected, fields_with(model: model, &actual)
    end

    def hidden_fields(method: nil, enforce_utf8: true, **options)
      if enforce_utf8
        txt = %{<input name="utf8" type="hidden" value="&#x2713;">}
      else
        txt = ""
      end
      if method && !%w(get post).include?(method.to_s)
        txt << %{<input name="_method" type="hidden" value="#{method}">}
      end
      txt
    end

    def form_text(action = "/", remote: nil, multipart: nil, method: "post", **options)
      txt =  %{<form accept-charset="UTF-8" action="#{action}"}
      txt << %{ enctype="multipart/form-data"} if multipart
      txt << %{ data-remote="true"} if remote
      options.each do |attr, value|
        txt << %{ #{attr}="#{value}"}
      end
      method = method.to_s == "get" ? "get" : "post"
      txt << %{ method="#{method}">}
    end

    def whole_form(action = "/", method: "post", remote: true, multipart: nil, **options, &block)
      contents = block_given? ? yield : ""
      form_tag = form_text(action, remote: remote, multipart: multipart, method: method, **options)
      form_tag + hidden_fields(method: method) + contents + "</form>"
    end

    def dummy_posts
      [ Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!") ]
    end
end
