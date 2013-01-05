require 'abstract_unit'
require 'controller/fake_models'
require 'active_support/core_ext/object/inclusion'

class FormHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::FormHelper

  def form_for(*)
    @output_buffer = super
  end

  def setup
    super

    # Create "label" locale for testing I18n label helpers
    I18n.backend.store_translations 'label', {
      :activemodel => {
        :attributes => {
          :post => {
            :cost => "Total cost"
          }
        }
      },
      :helpers => {
        :label => {
          :post => {
            :body => "Write entire text here",
            :color => {
              :red => "Rojo"
            },
            :comments => {
              :body => "Write body here"
            }
          },
          :tag => {
            :value => "Tag"
          }
        }
      }
    }

    # Create "submit" locale for testing I18n submit helpers
    I18n.backend.store_translations 'submit', {
      :helpers => {
        :submit => {
          :create => 'Create %{model}',
          :update => 'Confirm %{model} changes',
          :submit => 'Save changes',
          :another_post => {
            :update => 'Update your %{model}'
          }
        }
      }
    }

    @post = Post.new
    @comment = Comment.new
    def @post.errors()
      Class.new{
        def [](field); field == "author_name" ? ["can't be empty"] : [] end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "Author name can't be empty" ] end
      }.new
    end
    def @post.id; 123; end
    def @post.id_before_type_cast; 123; end
    def @post.to_param; '123'; end

    @post.persisted   = true
    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret      = 1
    @post.written_on  = Date.new(2004, 6, 15)

    @post.comments = []
    @post.comments << @comment

    @post.tags = []
    @post.tags << Tag.new

    @blog_post = Blog::Post.new("And his name will be forty and four.", 44)
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :posts do
      resources :comments
    end

    namespace :admin do
      resources :posts do
        resources :comments
      end
    end

    match "/foo", :to => "controller#action"
    root :to => "main#index"
  end

  def _routes
    Routes
  end

  include Routes.url_helpers

  def url_for(object)
    @url_for_options = object
    if object.is_a?(Hash) && object[:use_route].blank? && object[:controller].blank?
      object.merge!(:controller => "main", :action => "index")
    end
    super
  end

  def test_label
    assert_dom_equal('<label for="post_title">Title</label>', label("post", "title"))
    assert_dom_equal('<label for="post_title">The title goes here</label>', label("post", "title", "The title goes here"))
    assert_dom_equal(
      '<label class="title_label" for="post_title">Title</label>',
      label("post", "title", nil, :class => 'title_label')
    )
    assert_dom_equal('<label for="post_secret">Secret?</label>', label("post", "secret?"))
  end

  def test_label_with_symbols
    assert_dom_equal('<label for="post_title">Title</label>', label(:post, :title))
    assert_dom_equal('<label for="post_secret">Secret?</label>', label(:post, :secret?))
  end

  def test_label_with_locales_strings
    old_locale, I18n.locale = I18n.locale, :label
    assert_dom_equal('<label for="post_body">Write entire text here</label>', label("post", "body"))
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_human_attribute_name
    old_locale, I18n.locale = I18n.locale, :label
    assert_dom_equal('<label for="post_cost">Total cost</label>', label(:post, :cost))
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_locales_symbols
    old_locale, I18n.locale = I18n.locale, :label
    assert_dom_equal('<label for="post_body">Write entire text here</label>', label(:post, :body))
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_locales_and_options
    old_locale, I18n.locale = I18n.locale, :label
    assert_dom_equal('<label for="post_body" class="post_body">Write entire text here</label>', label(:post, :body, :class => 'post_body'))
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_locales_and_value
    old_locale, I18n.locale = I18n.locale, :label
    assert_dom_equal('<label for="post_color_red">Rojo</label>', label(:post, :color, :value => "red"))
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_locales_and_nested_attributes
    old_locale, I18n.locale = I18n.locale, :label
    form_for(@post, :html => { :id => 'create-post' }) do |f|
      f.fields_for(:comments) do |cf|
        concat cf.label(:body)
      end
    end

    expected = whole_form("/posts/123", "create-post" , "edit_post", :method => "put") do
      "<label for=\"post_comments_attributes_0_body\">Write body here</label>"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_locales_fallback_and_nested_attributes
    old_locale, I18n.locale = I18n.locale, :label
    form_for(@post, :html => { :id => 'create-post' }) do |f|
      f.fields_for(:tags) do |cf|
        concat cf.label(:value)
      end
    end

    expected = whole_form("/posts/123", "create-post" , "edit_post", :method => "put") do
      "<label for=\"post_tags_attributes_0_value\">Tag</label>"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_label_with_for_attribute_as_symbol
    assert_dom_equal('<label for="my_for">Title</label>', label(:post, :title, nil, :for => "my_for"))
  end

  def test_label_with_for_attribute_as_string
    assert_dom_equal('<label for="my_for">Title</label>', label(:post, :title, nil, "for" => "my_for"))
  end

  def test_label_with_id_attribute_as_symbol
    assert_dom_equal('<label for="post_title" id="my_id">Title</label>', label(:post, :title, nil, :id => "my_id"))
  end

  def test_label_with_id_attribute_as_string
    assert_dom_equal('<label for="post_title" id="my_id">Title</label>', label(:post, :title, nil, "id" => "my_id"))
  end

  def test_label_with_for_and_id_attributes_as_symbol
    assert_dom_equal('<label for="my_for" id="my_id">Title</label>', label(:post, :title, nil, :for => "my_for", :id => "my_id"))
  end

  def test_label_with_for_and_id_attributes_as_string
    assert_dom_equal('<label for="my_for" id="my_id">Title</label>', label(:post, :title, nil, "for" => "my_for", "id" => "my_id"))
  end

  def test_label_for_radio_buttons_with_value
    assert_dom_equal('<label for="post_title_great_title">The title goes here</label>', label("post", "title", "The title goes here", :value => "great_title"))
    assert_dom_equal('<label for="post_title_great_title">The title goes here</label>', label("post", "title", "The title goes here", :value => "great title"))
  end

  def test_label_with_block
    assert_dom_equal('<label for="post_title">The title, please:</label>', label(:post, :title) { "The title, please:" })
  end

  def test_label_with_block_in_erb
    assert_equal "<label for=\"post_message\">\n  Message\n  <input id=\"post_message\" name=\"post[message]\" size=\"30\" type=\"text\" />\n</label>", view.render("test/label_with_block")
  end

  def test_text_field
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title")
    )
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="password" />', password_field("post", "title")
    )
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="password" value="Hello World" />', password_field("post", "title", :value => @post.title)
    )
    assert_dom_equal(
      '<input id="person_name" name="person[name]" size="30" type="password" />', password_field("person", "name")
    )
  end

  def test_text_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="&lt;b&gt;Hello World&lt;/b&gt;" />', text_field("post", "title")
    )
  end

  def test_text_field_with_html_entities
    @post.title = "The HTML Entity for & is &amp;"
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="The HTML Entity for &amp; is &amp;amp;" />',
      text_field("post", "title")
    )
  end

  def test_text_field_with_options
    expected = '<input id="post_title" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_dom_equal expected, text_field("post", "title", "size" => 35)
    assert_dom_equal expected, text_field("post", "title", :size => 35)
  end

  def test_text_field_assuming_size
    expected = '<input id="post_title" maxlength="35" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_dom_equal expected, text_field("post", "title", "maxlength" => 35)
    assert_dom_equal expected, text_field("post", "title", :maxlength => 35)
  end

  def test_text_field_removing_size
    expected = '<input id="post_title" maxlength="35" name="post[title]" type="text" value="Hello World" />'
    assert_dom_equal expected, text_field("post", "title", "maxlength" => 35, "size" => nil)
    assert_dom_equal expected, text_field("post", "title", :maxlength => 35, :size => nil)
  end

  def test_text_field_with_nil_value
    expected = '<input id="post_title" name="post[title]" size="30" type="text" />'
    assert_dom_equal expected, text_field("post", "title", :value => nil)
  end

  def test_text_field_doesnt_change_param_values
    object_name = 'post[]'
    expected = '<input id="post_123_title" name="post[123][title]" size="30" type="text" value="Hello World" />'
    assert_equal expected, text_field(object_name, "title")
    assert_equal object_name, "post[]"
  end

  def test_file_field_has_no_size
    expected = '<input id="user_avatar" name="user[avatar]" type="file" />'
    assert_dom_equal expected, file_field("user", "avatar")
  end

  def test_hidden_field
    assert_dom_equal '<input id="post_title" name="post[title]" type="hidden" value="Hello World" />',
      hidden_field("post", "title")
      assert_dom_equal '<input id="post_secret" name="post[secret]" type="hidden" value="1" />',
        hidden_field("post", "secret?")
  end

  def test_hidden_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_dom_equal '<input id="post_title" name="post[title]" type="hidden" value="&lt;b&gt;Hello World&lt;/b&gt;" />',
      hidden_field("post", "title")
  end

  def test_hidden_field_with_nil_value
    expected = '<input id="post_title" name="post[title]" type="hidden" />'
    assert_dom_equal expected, hidden_field("post", "title", :value => nil)
  end

  def test_hidden_field_with_options
    assert_dom_equal '<input id="post_title" name="post[title]" type="hidden" value="Something Else" />',
      hidden_field("post", "title", :value => "Something Else")
  end

  def test_text_field_with_custom_type
    assert_dom_equal '<input id="user_email" size="30" name="user[email]" type="email" />',
      text_field("user", "email", :type => "email")
  end

  def test_check_box
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret")
    )
    @post.secret = 0
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret")
    )
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret" ,{"checked"=>"checked"})
    )
    @post.secret = true
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret")
    )
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret?")
    )

    @post.secret = ['0']
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret")
    )
    @post.secret = ['1']
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret")
    )
  end

  def test_check_box_with_explicit_checked_and_unchecked_values
    @post.secret = "on"
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="off" /><input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="on" />',
      check_box("post", "secret", {}, "on", "off")
    )
  end

  def test_check_box_with_nil_unchecked_value
    @post.secret = "on"
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="on" />',
      check_box("post", "secret", {}, "on", nil)
    )
  end

  def test_check_box_with_multiple_behavior
    @post.comment_ids = [2,3]
    assert_dom_equal(
      '<input name="post[comment_ids][]" type="hidden" value="0" /><input id="post_comment_ids_1" name="post[comment_ids][]" type="checkbox" value="1" />',
      check_box("post", "comment_ids", { :multiple => true }, 1)
    )
    assert_dom_equal(
      '<input name="post[comment_ids][]" type="hidden" value="0" /><input checked="checked" id="post_comment_ids_3" name="post[comment_ids][]" type="checkbox" value="3" />',
      check_box("post", "comment_ids", { :multiple => true }, 3)
    )
  end

  def test_check_box_with_multiple_behavior_and_index
    @post.comment_ids = [2,3]
    assert_dom_equal(
      '<input name="post[foo][comment_ids][]" type="hidden" value="0" /><input id="post_foo_comment_ids_1" name="post[foo][comment_ids][]" type="checkbox" value="1" />',
      check_box("post", "comment_ids", { :multiple => true, :index => "foo" }, 1)
    )
    assert_dom_equal(
      '<input name="post[bar][comment_ids][]" type="hidden" value="0" /><input checked="checked" id="post_bar_comment_ids_3" name="post[bar][comment_ids][]" type="checkbox" value="3" />',
      check_box("post", "comment_ids", { :multiple => true, :index => "bar" }, 3)
    )

  end

  def test_checkbox_disabled_disables_hidden_field
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" disabled="disabled"/><input checked="checked" disabled="disabled" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret", { :disabled => true })
    )
  end

  def test_radio_button
    assert_dom_equal('<input checked="checked" id="post_title_hello_world" name="post[title]" type="radio" value="Hello World" />',
      radio_button("post", "title", "Hello World")
    )
    assert_dom_equal('<input id="post_title_goodbye_world" name="post[title]" type="radio" value="Goodbye World" />',
      radio_button("post", "title", "Goodbye World")
    )
    assert_dom_equal('<input id="item_subobject_title_inside_world" name="item[subobject][title]" type="radio" value="inside world"/>',
      radio_button("item[subobject]", "title", "inside world")
    )
  end

  def test_radio_button_is_checked_with_integers
    assert_dom_equal('<input checked="checked" id="post_secret_1" name="post[secret]" type="radio" value="1" />',
      radio_button("post", "secret", "1")
   )
  end

  def test_radio_button_with_negative_integer_value
    assert_dom_equal('<input id="post_secret_-1" name="post[secret]" type="radio" value="-1" />',
      radio_button("post", "secret", "-1"))
  end

  def test_radio_button_respects_passed_in_id
     assert_dom_equal('<input checked="checked" id="foo" name="post[secret]" type="radio" value="1" />',
       radio_button("post", "secret", "1", :id=>"foo")
    )
  end

  def test_radio_button_with_booleans
    assert_dom_equal('<input id="post_secret_true" name="post[secret]" type="radio" value="true" />',
      radio_button("post", "secret", true)
    )

    assert_dom_equal('<input id="post_secret_false" name="post[secret]" type="radio" value="false" />',
      radio_button("post", "secret", false)
    )
  end

  def test_text_area
    assert_dom_equal(
      %{<textarea cols="40" id="post_body" name="post[body]" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body")
    )
  end

  def test_text_area_with_escapes
    @post.body        = "Back to <i>the</i> hill and over it again!"
    assert_dom_equal(
      %{<textarea cols="40" id="post_body" name="post[body]" rows="20">\nBack to &lt;i&gt;the&lt;/i&gt; hill and over it again!</textarea>},
      text_area("post", "body")
    )
  end

  def test_text_area_with_alternate_value
    assert_dom_equal(
      %{<textarea cols="40" id="post_body" name="post[body]" rows="20">\nTesting alternate values.</textarea>},
      text_area("post", "body", :value => 'Testing alternate values.')
    )
  end

  def test_text_area_with_html_entities
    @post.body        = "The HTML Entity for & is &amp;"
    assert_dom_equal(
      %{<textarea cols="40" id="post_body" name="post[body]" rows="20">\nThe HTML Entity for &amp; is &amp;amp;</textarea>},
      text_area("post", "body")
    )
  end

  def test_text_area_with_size_option
    assert_dom_equal(
      %{<textarea cols="183" id="post_body" name="post[body]" rows="820">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", :size => "183x820")
    )
  end

  def test_search_field
    expected = %{<input id="contact_notes_query" size="30" name="contact[notes_query]" type="search" />}
    assert_dom_equal(expected, search_field("contact", "notes_query"))
  end

  def test_telephone_field
    expected = %{<input id="user_cell" size="30" name="user[cell]" type="tel" />}
    assert_dom_equal(expected, telephone_field("user", "cell"))
  end

  def test_url_field
    expected = %{<input id="user_homepage" size="30" name="user[homepage]" type="url" />}
    assert_dom_equal(expected, url_field("user", "homepage"))
  end

  def test_email_field
    expected = %{<input id="user_address" size="30" name="user[address]" type="email" />}
    assert_dom_equal(expected, email_field("user", "address"))
  end

  def test_number_field
    expected = %{<input name="order[quantity]" max="9" id="order_quantity" type="number" min="1" />}
    assert_dom_equal(expected, number_field("order", "quantity", :in => 1...10))
    expected = %{<input name="order[quantity]" size="30" max="9" id="order_quantity" type="number" min="1" />}
    assert_dom_equal(expected, number_field("order", "quantity", :size => 30, :in => 1...10))
  end

  def test_range_input
    expected = %{<input name="hifi[volume]" step="0.1" max="11" id="hifi_volume" type="range" min="0" />}
    assert_dom_equal(expected, range_field("hifi", "volume", :in => 0..11, :step => 0.1))
    expected = %{<input name="hifi[volume]" step="0.1" size="30" max="11" id="hifi_volume" type="range" min="0" />}
    assert_dom_equal(expected, range_field("hifi", "volume", :size => 30, :in => 0..11, :step => 0.1))
  end

  def test_explicit_name
    assert_dom_equal(
      '<input id="post_title" name="dont guess" size="30" type="text" value="Hello World" />', text_field("post", "title", "name" => "dont guess")
    )
    assert_dom_equal(
      %{<textarea cols="40" id="post_body" name="really!" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", "name" => "really!")
    )
    assert_dom_equal(
      '<input name="i mean it" type="hidden" value="0" /><input checked="checked" id="post_secret" name="i mean it" type="checkbox" value="1" />',
      check_box("post", "secret", "name" => "i mean it")
    )
    assert_dom_equal text_field("post", "title", "name" => "dont guess"),
                 text_field("post", "title", :name => "dont guess")
    assert_dom_equal text_area("post", "body", "name" => "really!"),
                 text_area("post", "body", :name => "really!")
    assert_dom_equal check_box("post", "secret", "name" => "i mean it"),
                 check_box("post", "secret", :name => "i mean it")
  end

  def test_explicit_id
    assert_dom_equal(
      '<input id="dont guess" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title", "id" => "dont guess")
    )
    assert_dom_equal(
      %{<textarea cols="40" id="really!" name="post[body]" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", "id" => "really!")
    )
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" id="i mean it" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret", "id" => "i mean it")
    )
    assert_dom_equal text_field("post", "title", "id" => "dont guess"),
                 text_field("post", "title", :id => "dont guess")
    assert_dom_equal text_area("post", "body", "id" => "really!"),
                 text_area("post", "body", :id => "really!")
    assert_dom_equal check_box("post", "secret", "id" => "i mean it"),
                 check_box("post", "secret", :id => "i mean it")
  end

  def test_nil_id
    assert_dom_equal(
      '<input name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title", "id" => nil)
    )
    assert_dom_equal(
      %{<textarea cols="40" name="post[body]" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", "id" => nil)
    )
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="0" /><input checked="checked" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret", "id" => nil)
    )
    assert_dom_equal(
      '<input type="radio" name="post[secret]" value="0" />',
      radio_button("post", "secret", "0", "id" => nil)
    )
    assert_dom_equal(
      '<select name="post[secret]"></select>',
      select("post", "secret", [], {}, "id" => nil)
    )
    assert_dom_equal text_field("post", "title", "id" => nil),
                 text_field("post", "title", :id => nil)
    assert_dom_equal text_area("post", "body", "id" => nil),
                 text_area("post", "body", :id => nil)
    assert_dom_equal check_box("post", "secret", "id" => nil),
                 check_box("post", "secret", :id => nil)
    assert_dom_equal radio_button("post", "secret", "0", "id" => nil),
                 radio_button("post", "secret", "0", :id => nil)
  end

  def test_index
    assert_dom_equal(
      '<input name="post[5][title]" size="30" id="post_5_title" type="text" value="Hello World" />',
      text_field("post", "title", "index" => 5)
    )
    assert_dom_equal(
      %{<textarea cols="40" name="post[5][body]" id="post_5_body" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", "index" => 5)
    )
    assert_dom_equal(
      '<input name="post[5][secret]" type="hidden" value="0" /><input checked="checked" name="post[5][secret]" type="checkbox" value="1" id="post_5_secret" />',
      check_box("post", "secret", "index" => 5)
    )
    assert_dom_equal(
      text_field("post", "title", "index" => 5),
      text_field("post", "title", "index" => 5)
    )
    assert_dom_equal(
      text_area("post", "body", "index" => 5),
      text_area("post", "body", "index" => 5)
    )
    assert_dom_equal(
      check_box("post", "secret", "index" => 5),
      check_box("post", "secret", "index" => 5)
    )
  end

  def test_index_with_nil_id
    assert_dom_equal(
      '<input name="post[5][title]" size="30" type="text" value="Hello World" />',
      text_field("post", "title", "index" => 5, 'id' => nil)
    )
    assert_dom_equal(
      %{<textarea cols="40" name="post[5][body]" rows="20">\nBack to the hill and over it again!</textarea>},
      text_area("post", "body", "index" => 5, 'id' => nil)
    )
    assert_dom_equal(
      '<input name="post[5][secret]" type="hidden" value="0" /><input checked="checked" name="post[5][secret]" type="checkbox" value="1" />',
      check_box("post", "secret", "index" => 5, 'id' => nil)
    )
    assert_dom_equal(
      text_field("post", "title", "index" => 5, 'id' => nil),
      text_field("post", "title", :index => 5, :id => nil)
    )
    assert_dom_equal(
      text_area("post", "body", "index" => 5, 'id' => nil),
      text_area("post", "body", :index => 5, :id => nil)
    )
    assert_dom_equal(
      check_box("post", "secret", "index" => 5, 'id' => nil),
      check_box("post", "secret", :index => 5, :id => nil)
    )
  end

  def test_auto_index
    pid = @post.id
    assert_dom_equal(
      "<label for=\"post_#{pid}_title\">Title</label>",
      label("post[]", "title")
    )
    assert_dom_equal(
      "<input id=\"post_#{pid}_title\" name=\"post[#{pid}][title]\" size=\"30\" type=\"text\" value=\"Hello World\" />", text_field("post[]","title")
    )
    assert_dom_equal(
      "<textarea cols=\"40\" id=\"post_#{pid}_body\" name=\"post[#{pid}][body]\" rows=\"20\">\nBack to the hill and over it again!</textarea>",
      text_area("post[]", "body")
    )
    assert_dom_equal(
      "<input name=\"post[#{pid}][secret]\" type=\"hidden\" value=\"0\" /><input checked=\"checked\" id=\"post_#{pid}_secret\" name=\"post[#{pid}][secret]\" type=\"checkbox\" value=\"1\" />",
      check_box("post[]", "secret")
    )
   assert_dom_equal(
      "<input checked=\"checked\" id=\"post_#{pid}_title_hello_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Hello World\" />",
      radio_button("post[]", "title", "Hello World")
    )
    assert_dom_equal("<input id=\"post_#{pid}_title_goodbye_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Goodbye World\" />",
      radio_button("post[]", "title", "Goodbye World")
    )
  end

  def test_auto_index_with_nil_id
    pid = @post.id
    assert_dom_equal(
      "<input name=\"post[#{pid}][title]\" size=\"30\" type=\"text\" value=\"Hello World\" />",
      text_field("post[]","title", :id => nil)
    )
    assert_dom_equal(
      "<textarea cols=\"40\" name=\"post[#{pid}][body]\" rows=\"20\">\nBack to the hill and over it again!</textarea>",
      text_area("post[]", "body", :id => nil)
    )
    assert_dom_equal(
      "<input name=\"post[#{pid}][secret]\" type=\"hidden\" value=\"0\" /><input checked=\"checked\" name=\"post[#{pid}][secret]\" type=\"checkbox\" value=\"1\" />",
      check_box("post[]", "secret", :id => nil)
    )
   assert_dom_equal(
"<input checked=\"checked\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Hello World\" />",
      radio_button("post[]", "title", "Hello World", :id => nil)
    )
    assert_dom_equal("<input name=\"post[#{pid}][title]\" type=\"radio\" value=\"Goodbye World\" />",
      radio_button("post[]", "title", "Goodbye World", :id => nil)
    )
  end

  def test_form_for_requires_block
    assert_raises(ArgumentError) do
      form_for(:post, @post, :html => { :id => 'create-post' })
    end
  end

  def test_form_for
    form_for(@post, :html => { :id => 'create-post' }) do |f|
      concat f.label(:title) { "The Title" }
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
      concat f.submit('Create post')
      concat f.button('Create post')
    end

    expected = whole_form("/posts/123", "create-post" , "edit_post", :method => "put") do
      "<label for='post_title'>The Title</label>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='commit' type='submit' value='Create post' />" +
      "<button name='button' type='submit'>Create post</button>"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_file_field_generate_multipart
    Post.send :attr_accessor, :file

    form_for(@post, :html => { :id => 'create-post' }) do |f|
      concat f.file_field(:file)
    end

    expected = whole_form("/posts/123", "create-post" , "edit_post", :method => "put", :multipart => true) do
      "<input name='post[file]' type='file' id='post_file' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_file_field_generate_multipart
    Comment.send :attr_accessor, :file

    form_for(@post) do |f|
      concat f.fields_for(:comment, @post) { |c|
        concat c.file_field(:file)
      }
    end

    expected = whole_form("/posts/123", "edit_post_123" , "edit_post", :method => "put", :multipart => true) do
      "<input name='post[comment][file]' type='file' id='post_comment_file' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_format
    form_for(@post, :format => :json, :html => { :id => "edit_post_123", :class => "edit_post" }) do |f|
      concat f.label(:title)
    end

    expected = whole_form("/posts/123.json", "edit_post_123" , "edit_post", :method => "put") do
      "<label for='post_title'>Title</label>"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_model_using_relative_model_naming
    form_for(@blog_post) do |f|
      concat f.text_field :title
      concat f.submit('Edit post')
    end

    expected = whole_form("/posts/44", "edit_post_44" , "edit_post", :method => "put") do
      "<input name='post[title]' size='30' type='text' id='post_title' value='And his name will be forty and four.' />" +
      "<input name='commit' type='submit' value='Edit post' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_symbol_object_name
    form_for(@post, :as => "other_name", :html => { :id => 'create-post' }) do |f|
      concat f.label(:title, :class => 'post_title')
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
      concat f.submit('Create post')
    end

    expected =  whole_form("/posts/123", "create-post", "edit_other_name", :method => "put") do
      "<label for='other_name_title' class='post_title'>Title</label>" +
      "<input name='other_name[title]' size='30' id='other_name_title' value='Hello World' type='text' />" +
      "<textarea name='other_name[body]' id='other_name_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='other_name[secret]' value='0' type='hidden' />" +
      "<input name='other_name[secret]' checked='checked' id='other_name_secret' value='1' type='checkbox' />" +
      "<input name='commit' value='Create post' type='submit' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_method_as_part_of_html_options
    form_for(@post, :url => '/', :html => { :id => 'create-post', :method => :delete }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =  whole_form("/", "create-post", "edit_post", "delete") do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_method
    form_for(@post, :url => '/', :method => :delete, :html => { :id => 'create-post' }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =  whole_form("/", "create-post", "edit_post", "delete") do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_search_field
    # Test case for bug which would emit an "object" attribute
    # when used with form_for using a search_field form helper
    form_for(Post.new, :url => "/search", :html => { :id => 'search-post', :method => :get}) do |f|
      concat f.search_field(:title)
    end

    expected =  whole_form("/search", "search-post", "new_post", "get") do
      "<input name='post[title]' size='30' type='search' id='post_title' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_remote
    form_for(@post, :url => '/', :remote => true, :html => { :id => 'create-post', :method => :put }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =  whole_form("/", "create-post", "edit_post", :method => "put", :remote => true) do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_remote_in_html
    form_for(@post, :url => '/', :html => { :remote => true, :id => 'create-post', :method => :put }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =  whole_form("/", "create-post", "edit_post", :method => "put", :remote => true) do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_remote_without_html
    @post.persisted = false
    form_for(@post, :remote => true) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =  whole_form("/posts", 'new_post', 'new_post', :remote => true) do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_without_object
    form_for(:post, :html => { :id => 'create-post' }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form("/", "create-post") do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_index
    form_for(@post, :as => "post[]") do |f|
      concat f.label(:title)
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<label for='post_123_title'>Title</label>" +
      "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
      "<textarea name='post[123][body]' id='post_123_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[123][secret]' type='hidden' value='0' />" +
      "<input name='post[123][secret]' checked='checked' type='checkbox' id='post_123_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_nil_index_option_override
    form_for(@post, :as => "post[]", :index => nil) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<input name='post[][title]' size='30' type='text' id='post__title' value='Hello World' />" +
      "<textarea name='post[][body]' id='post__body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[][secret]' type='hidden' value='0' />" +
      "<input name='post[][secret]' checked='checked' type='checkbox' id='post__secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_label_error_wrapping
    form_for(@post) do |f|
      concat f.label(:author_name, :class => 'label')
      concat f.text_field(:author_name)
      concat f.submit('Create post')
    end

    expected = whole_form("/posts/123", "edit_post_123" , "edit_post", :method => "put") do
      "<div class='field_with_errors'><label for='post_author_name' class='label'>Author name</label></div>" +
      "<div class='field_with_errors'><input name='post[author_name]' size='30' type='text' id='post_author_name' value='' /></div>" +
      "<input name='commit' type='submit' value='Create post' />"
    end

    assert_dom_equal expected, output_buffer
  end


  def test_form_for_label_error_wrapping_without_conventional_instance_variable
    post = remove_instance_variable :@post

    form_for(post) do |f|
      concat f.label(:author_name, :class => 'label')
      concat f.text_field(:author_name)
      concat f.submit('Create post')
    end

    expected = whole_form("/posts/123", "edit_post_123" , "edit_post", :method => "put") do
      "<div class='field_with_errors'><label for='post_author_name' class='label'>Author name</label></div>" +
      "<div class='field_with_errors'><input name='post[author_name]' size='30' type='text' id='post_author_name' value='' /></div>" +
      "<input name='commit' type='submit' value='Create post' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_namespace
    form_for(@post, :namespace => 'namespace') do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form('/posts/123', 'namespace_edit_post_123', 'edit_post', 'put') do
      "<input name='post[title]' size='30' type='text' id='namespace_post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='namespace_post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='namespace_post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_namespace_with_date_select
    form_for(@post, :namespace => 'namespace') do |f|
      concat f.date_select(:written_on)
    end

    assert_select 'select#namespace_post_written_on_1i'
  end

  def test_form_for_with_namespace_with_label
    form_for(@post, :namespace => 'namespace') do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    expected = whole_form('/posts/123', 'namespace_edit_post_123', 'edit_post', 'put') do
      "<label for='namespace_post_title'>Title</label>" +
      "<input name='post[title]' size='30' type='text' id='namespace_post_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_two_form_for_with_namespace
    form_for(@post, :namespace => 'namespace_1') do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    expected_1 = whole_form('/posts/123', 'namespace_1_edit_post_123', 'edit_post', 'put') do
      "<label for='namespace_1_post_title'>Title</label>" +
      "<input name='post[title]' size='30' type='text' id='namespace_1_post_title' value='Hello World' />"
    end

    assert_dom_equal expected_1, output_buffer

    form_for(@post, :namespace => 'namespace_2') do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    expected_2 = whole_form('/posts/123', 'namespace_2_edit_post_123', 'edit_post', 'put') do
      "<label for='namespace_2_post_title'>Title</label>" +
      "<input name='post[title]' size='30' type='text' id='namespace_2_post_title' value='Hello World' />"
    end

    assert_dom_equal expected_2, output_buffer
  end

  def test_fields_for_with_namespace
    @comment.body = 'Hello World'
    form_for(@post, :namespace => 'namespace') do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.fields_for(@comment) { |c|
        concat c.text_field(:body)
      }
    end

    expected = whole_form('/posts/123', 'namespace_edit_post_123', 'edit_post', 'put') do
      "<input name='post[title]' size='30' type='text' id='namespace_post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='namespace_post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[comment][body]' size='30' type='text' id='namespace_post_comment_body' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_submit_with_object_as_new_record_and_locale_strings
    old_locale, I18n.locale = I18n.locale, :submit

    @post.persisted = false
    form_for(@post) do |f|
      concat f.submit
    end

    expected = whole_form('/posts', 'new_post', 'new_post') do
      "<input name='commit' type='submit' value='Create Post' />"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_submit_with_object_as_existing_record_and_locale_strings
    old_locale, I18n.locale = I18n.locale, :submit

    form_for(@post) do |f|
      concat f.submit
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      "<input name='commit' type='submit' value='Confirm Post changes' />"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_submit_without_object_and_locale_strings
    old_locale, I18n.locale = I18n.locale, :submit

    form_for(:post) do |f|
      concat f.submit :class => "extra"
    end

    expected = whole_form do
      "<input name='commit' class='extra' type='submit' value='Save changes' />"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_submit_with_object_and_nested_lookup
    old_locale, I18n.locale = I18n.locale, :submit

    form_for(@post, :as => :another_post) do |f|
      concat f.submit
    end

    expected = whole_form('/posts/123', 'edit_another_post', 'edit_another_post', :method => 'put') do
      "<input name='commit' type='submit' value='Update your Post' />"
    end

    assert_dom_equal expected, output_buffer
  ensure
    I18n.locale = old_locale
  end

  def test_nested_fields_for
    @comment.body = 'Hello World'
    form_for(@post) do |f|
      concat f.fields_for(@comment) { |c|
        concat c.text_field(:body)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      "<input name='post[comment][body]' size='30' type='text' id='post_comment_body' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_nested_collections
    form_for(@post, :as => 'post[]') do |f|
      concat f.text_field(:title)
      concat f.fields_for('comment[]', @comment) { |c|
        concat c.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
      "<input name='post[123][comment][][name]' size='30' type='text' id='post_123_comment__name' value='new comment' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_and_parent_fields
    form_for(@post, :index => 1) do |c|
      concat c.text_field(:title)
      concat c.fields_for('comment', @comment, :index => 1) { |r|
        concat r.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', 'put') do
      "<input name='post[1][title]' size='30' type='text' id='post_1_title' value='Hello World' />" +
      "<input name='post[1][comment][1][name]' size='30' type='text' id='post_1_comment_1_name' value='new comment' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_index_and_nested_fields_for
    output_buffer = form_for(@post, :index => 1) do |f|
      concat f.fields_for(:comment, @post) { |c|
        concat c.text_field(:title)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', 'put') do
      "<input name='post[1][comment][title]' size='30' type='text' id='post_1_comment_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_on_both
    form_for(@post, :index => 1) do |f|
      concat f.fields_for(:comment, @post, :index => 5) { |c|
        concat c.text_field(:title)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', 'put') do
      "<input name='post[1][comment][5][title]' size='30' type='text' id='post_1_comment_5_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_auto_index
    form_for(@post, :as => "post[]") do |f|
      concat f.fields_for(:comment, @post) { |c|
        concat c.text_field(:title)
      }
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<input name='post[123][comment][title]' size='30' type='text' id='post_123_comment_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_radio_button
    form_for(@post) do |f|
      concat f.fields_for(:comment, @post, :index => 5) { |c|
        concat c.radio_button(:title, "hello")
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', 'put') do
      "<input name='post[comment][5][title]' type='radio' id='post_comment_5_title_hello' value='hello' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_auto_index_on_both
    form_for(@post, :as => "post[]") do |f|
      concat f.fields_for("comment[]", @post) { |c|
        concat c.text_field(:title)
      }
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<input name='post[123][comment][123][title]' size='30' type='text' id='post_123_comment_123_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_and_auto_index
    output_buffer = form_for(@post, :as => "post[]") do |f|
      concat f.fields_for(:comment, @post, :index => 5) { |c|
        concat c.text_field(:title)
      }
    end

    output_buffer << form_for(@post, :as => :post, :index => 1) do |f|
      concat f.fields_for("comment[]", @post) { |c|
        concat c.text_field(:title)
      }
    end

    expected = whole_form('/posts/123', 'edit_post[]', 'edit_post[]', 'put') do
      "<input name='post[123][comment][5][title]' size='30' type='text' id='post_123_comment_5_title' value='Hello World' />"
    end + whole_form('/posts/123', 'edit_post', 'edit_post', 'put') do
      "<input name='post[1][comment][123][title]' size='30' type='text' id='post_1_comment_123_title' value='Hello World' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_a_new_record_on_a_nested_attributes_one_to_one_association
    @post.author = Author.new

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        concat af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
        '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="new author" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_explicitly_passed_object_on_a_nested_attributes_one_to_one_association
    form_for(@post) do |f|
      f.fields_for(:author, Author.new(123)) do |af|
        assert_not_nil af.object
        assert_equal 123, af.object.id
      end
    end
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association
    @post.author = Author.new(321)

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        concat af.text_field(:name)
      }
    end

   expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
     '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
     '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
     '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />'
   end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association_using_erb_and_inline_block
    @post.author = Author.new(321)

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
      '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association_with_disabled_hidden_id
    @post.author = Author.new(321)

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author, :include_id => false) { |af|
        af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association_with_disabled_hidden_id_inherited
    @post.author = Author.new(321)

    form_for(@post, :include_id => false) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association_with_disabled_hidden_id_override
    @post.author = Author.new(321)

    form_for(@post, :include_id => false) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author, :include_id => true) { |af|
        af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
      '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_one_to_one_association_with_explicit_hidden_field_placement
    @post.author = Author.new(321)

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        concat af.hidden_field(:id)
        concat af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(@post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_with_disabled_hidden_id
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }
    @post.author = Author.new(321)

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        concat af.text_field(:name)
      }
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment, :include_id => false) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
      '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_with_disabled_hidden_id_inherited
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }
    @post.author = Author.new(321)

    form_for(@post, :include_id => false) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author) { |af|
        concat af.text_field(:name)
      }
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_with_disabled_hidden_id_override
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }
    @post.author = Author.new(321)

    form_for(@post, :include_id => false) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:author, :include_id => true) { |af|
        concat af.text_field(:name)
      }
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
      '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_using_erb_and_inline_block
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(@post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_with_explicit_hidden_field_placement
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(@post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.hidden_field(:id)
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_new_records_on_a_nested_attributes_collection_association
    @post.comments = [Comment.new, Comment.new]

    form_for(@post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="new comment" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_and_new_records_on_a_nested_attributes_collection_association
    @post.comments = [Comment.new(321), Comment.new]

    form_for(@post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        concat f.fields_for(:comments, comment) { |cf|
          concat cf.text_field(:name)
        }
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #321" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="321" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_empty_supplied_attributes_collection
    form_for(@post) do |f|
      concat f.text_field(:title)
      f.fields_for(:comments, []) do |cf|
        concat cf.text_field(:name)
      end
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_supplied_nested_attributes_collection
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:comments, @post.comments) { |cf|
        concat cf.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_arel_like
    @post.comments = ArelLike.new

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:comments, @post.comments) { |cf|
        concat cf.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_supplied_nested_attributes_collection_different_from_record_one
    comments = Array.new(2) { |id| Comment.new(id + 1) }
    @post.comments = []

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:comments, comments) { |cf|
        concat cf.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
      '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_on_a_nested_attributes_collection_association_yields_only_builder
    @post.comments = [Comment.new(321), Comment.new]
    yielded_comments = []

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.fields_for(:comments) { |cf|
        concat cf.text_field(:name)
        yielded_comments << cf.object
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #321" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="321" />' +
      '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />'
    end

    assert_dom_equal expected, output_buffer
    assert_equal yielded_comments, @post.comments
  end

  def test_nested_fields_for_with_child_index_option_override_on_a_nested_attributes_collection_association
    @post.comments = []

    form_for(@post) do |f|
      concat f.fields_for(:comments, Comment.new(321), :child_index => 'abc') { |cf|
        concat cf.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input id="post_comments_attributes_abc_name" name="post[comments_attributes][abc][name]" size="30" type="text" value="comment #321" />' +
      '<input id="post_comments_attributes_abc_id" name="post[comments_attributes][abc][id]" type="hidden" value="321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_uses_unique_indices_for_different_collection_associations
    @post.comments = [Comment.new(321)]
    @post.tags = [Tag.new(123), Tag.new(456)]
    @post.comments[0].relevances = []
    @post.tags[0].relevances = []
    @post.tags[1].relevances = []

    form_for(@post) do |f|
      concat f.fields_for(:comments, @post.comments[0]) { |cf|
        concat cf.text_field(:name)
        concat cf.fields_for(:relevances, CommentRelevance.new(314)) { |crf|
          concat crf.text_field(:value)
        }
      }
      concat f.fields_for(:tags, @post.tags[0]) { |tf|
        concat tf.text_field(:value)
        concat tf.fields_for(:relevances, TagRelevance.new(3141)) { |trf|
          concat trf.text_field(:value)
        }
      }
      concat f.fields_for('tags', @post.tags[1]) { |tf|
        concat tf.text_field(:value)
        concat tf.fields_for(:relevances, TagRelevance.new(31415)) { |trf|
          concat trf.text_field(:value)
        }
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #321" />' +
      '<input id="post_comments_attributes_0_relevances_attributes_0_value" name="post[comments_attributes][0][relevances_attributes][0][value]" size="30" type="text" value="commentrelevance #314" />' +
      '<input id="post_comments_attributes_0_relevances_attributes_0_id" name="post[comments_attributes][0][relevances_attributes][0][id]" type="hidden" value="314" />' +
      '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="321" />' +
      '<input id="post_tags_attributes_0_value" name="post[tags_attributes][0][value]" size="30" type="text" value="tag #123" />' +
      '<input id="post_tags_attributes_0_relevances_attributes_0_value" name="post[tags_attributes][0][relevances_attributes][0][value]" size="30" type="text" value="tagrelevance #3141" />' +
      '<input id="post_tags_attributes_0_relevances_attributes_0_id" name="post[tags_attributes][0][relevances_attributes][0][id]" type="hidden" value="3141" />' +
      '<input id="post_tags_attributes_0_id" name="post[tags_attributes][0][id]" type="hidden" value="123" />' +
      '<input id="post_tags_attributes_1_value" name="post[tags_attributes][1][value]" size="30" type="text" value="tag #456" />' +
      '<input id="post_tags_attributes_1_relevances_attributes_0_value" name="post[tags_attributes][1][relevances_attributes][0][value]" size="30" type="text" value="tagrelevance #31415" />' +
      '<input id="post_tags_attributes_1_relevances_attributes_0_id" name="post[tags_attributes][1][relevances_attributes][0][id]" type="hidden" value="31415" />' +
      '<input id="post_tags_attributes_1_id" name="post[tags_attributes][1][id]" type="hidden" value="456" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_hash_like_model
    @author = HashBackedAuthor.new

    form_for(@post) do |f|
      concat f.fields_for(:author, @author) { |af|
        concat af.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="hash backed author" />'
    end

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for
    output_buffer = fields_for(:post, @post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_index
    output_buffer = fields_for("post[]", @post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
      "<textarea name='post[123][body]' id='post_123_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[123][secret]' type='hidden' value='0' />" +
      "<input name='post[123][secret]' checked='checked' type='checkbox' id='post_123_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_nil_index_option_override
    output_buffer = fields_for("post[]", @post, :index => nil) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[][title]' size='30' type='text' id='post__title' value='Hello World' />" +
      "<textarea name='post[][body]' id='post__body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[][secret]' type='hidden' value='0' />" +
      "<input name='post[][secret]' checked='checked' type='checkbox' id='post__secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_index_option_override
    output_buffer = fields_for("post[]", @post, :index => "abc") do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[abc][title]' size='30' type='text' id='post_abc_title' value='Hello World' />" +
      "<textarea name='post[abc][body]' id='post_abc_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[abc][secret]' type='hidden' value='0' />" +
      "<input name='post[abc][secret]' checked='checked' type='checkbox' id='post_abc_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_without_object
    output_buffer = fields_for(:post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_only_object
    output_buffer = fields_for(@post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_object_with_bracketed_name
    output_buffer = fields_for("author[post]", @post) do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    assert_dom_equal "<label for=\"author_post_title\">Title</label>" +
    "<input name='author[post][title]' size='30' type='text' id='author_post_title' value='Hello World' />",
      output_buffer
  end

  def test_fields_for_object_with_bracketed_name_and_index
    output_buffer = fields_for("author[post]", @post, :index => 1) do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    assert_dom_equal "<label for=\"author_post_1_title\">Title</label>" +
      "<input name='author[post][1][title]' size='30' type='text' id='author_post_1_title' value='Hello World' />",
      output_buffer
  end

  def test_form_builder_does_not_have_form_for_method
    assert ! ActionView::Helpers::FormBuilder.instance_methods.include?('form_for')
  end

  def test_form_for_and_fields_for
    form_for(@post, :as => :post, :html => { :id => 'create-post' }) do |post_form|
      concat post_form.text_field(:title)
      concat post_form.text_area(:body)

      concat fields_for(:parent_post, @post) { |parent_fields|
        concat parent_fields.check_box(:secret)
      }
    end

    expected = whole_form('/posts/123', 'create-post', 'edit_post', :method => 'put') do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='parent_post[secret]' type='hidden' value='0' />" +
      "<input name='parent_post[secret]' checked='checked' type='checkbox' id='parent_post_secret' value='1' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_and_fields_for_with_object
    form_for(@post, :as => :post, :html => { :id => 'create-post' }) do |post_form|
      concat post_form.text_field(:title)
      concat post_form.text_area(:body)

      concat post_form.fields_for(@comment) { |comment_fields|
        concat comment_fields.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'create-post', 'edit_post', :method => 'put') do
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea>" +
      "<input name='post[comment][name]' type='text' id='post_comment_name' value='new comment' size='30' />"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_and_fields_for_with_non_nested_association_and_without_object
    form_for(@post) do |f|
      concat f.fields_for(:category) { |c|
        concat c.text_field(:name)
      }
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', 'put') do
      "<input name='post[category][name]' type='text' size='30' id='post_category_name' />"
    end

    assert_dom_equal expected, output_buffer
  end

  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    (field_helpers - %w(hidden_field)).each do |selector|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{selector}(field, *args, &proc)
          ("<label for='\#{field}'>\#{field.to_s.humanize}:</label> " + super + "<br/>").html_safe
        end
      RUBY_EVAL
    end
  end

  def test_form_for_with_labelled_builder
    form_for(@post, :builder => LabelledFormBuilder) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>"
    end

    assert_dom_equal expected, output_buffer
  end

  def hidden_fields(method = nil)
    txt =  %{<div style="margin:0;padding:0;display:inline">}
    txt << %{<input name="utf8" type="hidden" value="&#x2713;" />}
    if method && !method.to_s.in?(['get', 'post'])
      txt << %{<input name="_method" type="hidden" value="#{method}" />}
    end
    txt << %{</div>}
  end

  def form_text(action = "/", id = nil, html_class = nil, remote = nil, multipart = nil, method = nil)
    txt =  %{<form accept-charset="UTF-8" action="#{action}"}
    txt << %{ enctype="multipart/form-data"} if multipart
    txt << %{ data-remote="true"} if remote
    txt << %{ class="#{html_class}"} if html_class
    txt << %{ id="#{id}"} if id
    method = method.to_s == "get" ? "get" : "post"
    txt << %{ method="#{method}">}
  end

  def whole_form(action = "/", id = nil, html_class = nil, options = nil)
    contents = block_given? ? yield : ""

    if options.is_a?(Hash)
      method, remote, multipart = options.values_at(:method, :remote, :multipart)
    else
      method = options
    end

    form_text(action, id, html_class, remote, multipart, method) + hidden_fields(method) + contents + "</form>"
  end

  def test_default_form_builder
    old_default_form_builder, ActionView::Base.default_form_builder =
      ActionView::Base.default_form_builder, LabelledFormBuilder

    form_for(@post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>"
    end

    assert_dom_equal expected, output_buffer
  ensure
    ActionView::Base.default_form_builder = old_default_form_builder
  end

  def test_lazy_loading_default_form_builder
    old_default_form_builder, ActionView::Base.default_form_builder =
      ActionView::Base.default_form_builder, "FormHelperTest::LabelledFormBuilder"

    form_for(@post) do |f|
      concat f.text_field(:title)
    end

    expected = whole_form('/posts/123', 'edit_post_123', 'edit_post', :method => 'put') do
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>"
    end

    assert_dom_equal expected, output_buffer
  ensure
    ActionView::Base.default_form_builder = old_default_form_builder
  end

  def test_fields_for_with_labelled_builder
    output_buffer = fields_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>\nBack to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_labelled_builder_with_nested_fields_for_without_options_hash
    klass = nil

    form_for(@post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new) do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilder, klass
  end

  def test_form_for_with_labelled_builder_with_nested_fields_for_with_options_hash
    klass = nil

    form_for(@post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new, :index => 'foo') do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilder, klass
  end

  def test_form_for_with_labelled_builder_path
    path = nil

    form_for(@post, :builder => LabelledFormBuilder) do |f|
      path = f.to_partial_path
      ''
    end

    assert_equal 'labelled_form', path
  end

  class LabelledFormBuilderSubclass < LabelledFormBuilder; end

  def test_form_for_with_labelled_builder_with_nested_fields_for_with_custom_builder
    klass = nil

    form_for(@post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new, :builder => LabelledFormBuilderSubclass) do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilderSubclass, klass
  end

  def test_form_for_with_html_options_adds_options_to_form_tag
    form_for(@post, :html => {:id => 'some_form', :class => 'some_class'}) do |f| end
    expected = whole_form("/posts/123", "some_form", "some_class", 'put')

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_string_url_option
    form_for(@post, :url => 'http://www.otherdomain.com') do |f| end

    assert_equal whole_form("http://www.otherdomain.com", 'edit_post_123', 'edit_post', 'put'), output_buffer
  end

  def test_form_for_with_hash_url_option
    form_for(@post, :url => {:controller => 'controller', :action => 'action'}) do |f| end

    assert_equal 'controller', @url_for_options[:controller]
    assert_equal 'action', @url_for_options[:action]
  end

  def test_form_for_with_record_url_option
    form_for(@post, :url => @post) do |f| end

    expected = whole_form("/posts/123", 'edit_post_123', 'edit_post', 'put')
    assert_equal expected, output_buffer
  end

  def test_form_for_with_existing_object
    form_for(@post) do |f| end

    expected = whole_form("/posts/123", "edit_post_123", "edit_post", "put")
    assert_equal expected, output_buffer
  end

  def test_form_for_with_new_object
    post = Post.new
    post.persisted = false
    def post.id() nil end

    form_for(post) do |f| end

    expected = whole_form("/posts", "new_post", "new_post")
    assert_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_in_list
    @comment.save
    form_for([@post, @comment]) {}

    expected = whole_form(post_comment_path(@post, @comment), "edit_comment_1", "edit_comment", "put")
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_new_object_in_list
    form_for([@post, @comment]) {}

    expected = whole_form(post_comments_path(@post), "new_comment", "new_comment")
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_and_namespace_in_list
    @comment.save
    form_for([:admin, @post, @comment]) {}

    expected = whole_form(admin_post_comment_path(@post, @comment), "edit_comment_1", "edit_comment", "put")
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_new_object_and_namespace_in_list
    form_for([:admin, @post, @comment]) {}

    expected = whole_form(admin_post_comments_path(@post), "new_comment", "new_comment")
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_and_custom_url
    form_for(@post, :url => "/super_posts") do |f| end

    expected = whole_form("/super_posts", "edit_post_123", "edit_post", "put")
    assert_equal expected, output_buffer
  end

  def test_fields_for_returns_block_result
    output = fields_for(Post.new) { |f| "fields" }
    assert_equal "fields", output
  end

  def test_form_for_only_instantiates_builder_once
    initialization_count = 0
    builder_class = Class.new(ActionView::Helpers::FormBuilder) do
      define_method :initialize do |*args|
        super(*args)
        initialization_count += 1
      end
    end

    form_for(@post, :builder => builder_class) { }
    assert_equal 1, initialization_count, 'form builder instantiated more than once'
  end

  protected
    def protect_against_forgery?
      false
    end

end
