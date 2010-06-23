require 'abstract_unit'

silence_warnings do
  Post = Struct.new(:title, :author_name, :body, :secret, :written_on, :cost)
  Post.class_eval do
    alias_method :title_before_type_cast, :title unless respond_to?(:title_before_type_cast)
    alias_method :body_before_type_cast, :body unless respond_to?(:body_before_type_cast)
    alias_method :author_name_before_type_cast, :author_name unless respond_to?(:author_name_before_type_cast)
    alias_method :secret?, :secret

    def new_record=(boolean)
      @new_record = boolean
    end

    def new_record?
      @new_record
    end

    attr_accessor :author
    def author_attributes=(attributes); end

    attr_accessor :comments
    def comments_attributes=(attributes); end

    attr_accessor :tags
    def tags_attributes=(attributes); end
  end

  class Comment
    attr_reader :id
    attr_reader :post_id
    def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
    def save; @id = 1; @post_id = 1 end
    def new_record?; @id.nil? end
    def to_param; @id; end
    def name
      @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
    end

    attr_accessor :relevances
    def relevances_attributes=(attributes); end

  end

  class Tag
    attr_reader :id
    attr_reader :post_id
    def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
    def save; @id = 1; @post_id = 1 end
    def new_record?; @id.nil? end
    def to_param; @id; end
    def value
      @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
    end

    attr_accessor :relevances
    def relevances_attributes=(attributes); end

  end

  class CommentRelevance
    attr_reader :id
    attr_reader :comment_id
    def initialize(id = nil, comment_id = nil); @id, @comment_id = id, comment_id end
    def save; @id = 1; @comment_id = 1 end
    def new_record?; @id.nil? end
    def to_param; @id; end
    def value
      @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
    end
  end

  class TagRelevance
    attr_reader :id
    attr_reader :tag_id
    def initialize(id = nil, tag_id = nil); @id, @tag_id = id, tag_id end
    def save; @id = 1; @tag_id = 1 end
    def new_record?; @id.nil? end
    def to_param; @id; end
    def value
      @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
    end
  end

  class Author < Comment
    attr_accessor :post
    def post_attributes=(attributes); end
  end
end

class FormHelperTest < ActionView::TestCase
  tests ActionView::Helpers::FormHelper

  def setup
    super

    # Create "label" locale for testing I18n label helpers
    I18n.backend.store_translations 'label', {
      :helpers => {
        :label => {
          :post => {
            :body => "Write entire text here"
          }
        }
      }
    }

    @post = Post.new
    @comment = Comment.new
    def @post.errors()
      Class.new{
        def on(field); "can't be empty" if field == "author_name"; end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "Author name can't be empty" ] end
      }.new
    end
    def @post.id; 123; end
    def @post.id_before_type_cast; 123; end
    def @post.to_param; '123'; end

    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret      = 1
    @post.written_on  = Date.new(2004, 6, 15)

    def Post.human_attribute_name(attribute)
      attribute.to_s == "cost" ? "Total cost" : attribute.to_s.humanize
    end

    @controller = Class.new do
      attr_reader :url_for_options
      def url_for(options)
        @url_for_options = options
        "http://www.example.com"
      end
    end
    @controller = @controller.new
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

  def test_text_field
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title")
    )
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="password" value="Hello World" />', password_field("post", "title")
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

  def test_text_field_doesnt_change_param_values
    object_name = 'post[]'
    expected = '<input id="post_123_title" name="post[123][title]" size="30" type="text" value="Hello World" />'
    assert_equal expected, text_field(object_name, "title")
    assert_equal object_name, "post[]"
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

  def test_text_field_with_options
    assert_dom_equal '<input id="post_title" name="post[title]" type="hidden" value="Something Else" />',
      hidden_field("post", "title", :value => "Something Else")
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

  def test_checkbox_disabled_still_submits_checked_value
    assert_dom_equal(
      '<input name="post[secret]" type="hidden" value="1" /><input checked="checked" disabled="disabled" id="post_secret" name="post[secret]" type="checkbox" value="1" />',
      check_box("post", "secret", { :disabled => :true })
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
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_text_area_with_escapes
    @post.body        = "Back to <i>the</i> hill and over it again!"
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to &lt;i&gt;the&lt;/i&gt; hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_text_area_with_alternate_value
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Testing alternate values.</textarea>',
      text_area("post", "body", :value => 'Testing alternate values.')
    )
  end

  def test_text_area_with_html_entities
    @post.body        = "The HTML Entity for & is &amp;"
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">The HTML Entity for &amp; is &amp;amp;</textarea>',
      text_area("post", "body")
    )
  end

  def test_text_area_with_size_option
    assert_dom_equal(
      '<textarea cols="183" id="post_body" name="post[body]" rows="820">Back to the hill and over it again!</textarea>',
      text_area("post", "body", :size => "183x820")
    )
  end

  def test_explicit_name
    assert_dom_equal(
      '<input id="post_title" name="dont guess" size="30" type="text" value="Hello World" />', text_field("post", "title", "name" => "dont guess")
    )
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="really!" rows="20">Back to the hill and over it again!</textarea>',
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
      '<textarea cols="40" id="really!" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
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
      "<textarea cols=\"40\" id=\"post_#{pid}_body\" name=\"post[#{pid}][body]\" rows=\"20\">Back to the hill and over it again!</textarea>",
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

  def test_form_for
    form_for(:post, @post, :html => { :id => 'create-post' }) do |f|
      concat f.label(:title)
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
      concat f.submit('Create post')
    end

    expected =
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<label for='post_title'>Title</label>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='commit' id='post_submit' type='submit' value='Create post' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_method
    form_for(:post, @post, :html => { :id => 'create-post', :method => :put }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_without_object
    form_for(:post, :html => { :id => 'create-post' }) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_index
    form_for("post[]", @post) do |f|
      concat f.label(:title)
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' method='post'>" +
      "<label for=\"post_123_title\">Title</label>" +
      "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
      "<textarea name='post[123][body]' id='post_123_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[123][secret]' type='hidden' value='0' />" +
      "<input name='post[123][secret]' checked='checked' type='checkbox' id='post_123_secret' value='1' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_nil_index_option_override
    form_for("post[]", @post, :index => nil) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' method='post'>" +
      "<input name='post[][title]' size='30' type='text' id='post__title' value='Hello World' />" +
      "<textarea name='post[][body]' id='post__body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[][secret]' type='hidden' value='0' />" +
      "<input name='post[][secret]' checked='checked' type='checkbox' id='post__secret' value='1' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for
    form_for(:post, @post) do |f|
      f.fields_for(:comment, @post) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[comment][title]' size='30' type='text' id='post_comment_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_nested_collections
    form_for('post[]', @post) do |f|
      concat f.text_field(:title)
      f.fields_for('comment[]', @comment) do |c|
        concat c.text_field(:name)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
               "<input name='post[123][comment][][name]' size='30' type='text' id='post_123_comment__name' value='new comment' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_and_parent_fields
    form_for('post', @post, :index => 1) do |c|
      concat c.text_field(:title)
      c.fields_for('comment', @comment, :index => 1) do |r|
        concat r.text_field(:name)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[1][title]' size='30' type='text' id='post_1_title' value='Hello World' />" +
               "<input name='post[1][comment][1][name]' size='30' type='text' id='post_1_comment_1_name' value='new comment' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_index_and_nested_fields_for
    form_for(:post, @post, :index => 1) do |f|
      f.fields_for(:comment, @post) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[1][comment][title]' size='30' type='text' id='post_1_comment_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_on_both
    form_for(:post, @post, :index => 1) do |f|
      f.fields_for(:comment, @post, :index => 5) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[1][comment][5][title]' size='30' type='text' id='post_1_comment_5_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_auto_index
    form_for("post[]", @post) do |f|
      f.fields_for(:comment, @post) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[123][comment][title]' size='30' type='text' id='post_123_comment_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_radio_button
    form_for(:post, @post) do |f|
      f.fields_for(:comment, @post, :index => 5) do |c|
        concat c.radio_button(:title, "hello")
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[comment][5][title]' type='radio' id='post_comment_5_title_hello' value='hello' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_auto_index_on_both
    form_for("post[]", @post) do |f|
      f.fields_for("comment[]", @post) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[123][comment][123][title]' size='30' type='text' id='post_123_comment_123_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_index_and_auto_index
    form_for("post[]", @post) do |f|
      f.fields_for(:comment, @post, :index => 5) do |c|
        concat c.text_field(:title)
      end
    end

    form_for(:post, @post, :index => 1) do |f|
      f.fields_for("comment[]", @post) do |c|
        concat c.text_field(:title)
      end
    end

    expected = "<form action='http://www.example.com' method='post'>" +
               "<input name='post[123][comment][5][title]' size='30' type='text' id='post_123_comment_5_title' value='Hello World' />" +
               "</form>" +
               "<form action='http://www.example.com' method='post'>" +
               "<input name='post[1][comment][123][title]' size='30' type='text' id='post_1_comment_123_title' value='Hello World' />" +
               "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_a_new_record_on_a_nested_attributes_one_to_one_association
    @post.author = Author.new

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:author) do |af|
        concat af.text_field(:name)
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="new author" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_explicitly_passed_object_on_a_nested_attributes_one_to_one_association
    form_for(:post, @post) do |f|
      f.fields_for(:author, Author.new(123)) do |af|
        assert_not_nil af.object
        assert_equal 123, af.object.id
      end
    end
  end

  def test_nested_fields_for_with_an_existing_record_on_a_nested_attributes_one_to_one_association
    @post.author = Author.new(321)

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:author) do |af|
        concat af.text_field(:name)
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
               '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end
  
  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_one_to_one_association_with_explicit_hidden_field_placement
    @post.author = Author.new(321)

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:author) do |af|
        concat af.hidden_field(:id)
        concat af.text_field(:name)
      end
    end
    
    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_author_attributes_id" name="post[author_attributes][id]" type="hidden" value="321" />' +
               '<input id="post_author_attributes_name" name="post[author_attributes][name]" size="30" type="text" value="author #321" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        f.fields_for(:comments, comment) do |cf|
          concat cf.text_field(:name)
        end
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
               '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
               '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_nested_attributes_collection_association_with_explicit_hidden_field_placement
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        f.fields_for(:comments, comment) do |cf|
          concat cf.hidden_field(:id)
          concat cf.text_field(:name)
        end
      end
    end
    
    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
               '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_new_records_on_a_nested_attributes_collection_association
    @post.comments = [Comment.new, Comment.new]

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        f.fields_for(:comments, comment) do |cf|
          concat cf.text_field(:name)
        end
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="new comment" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_and_new_records_on_a_nested_attributes_collection_association
    @post.comments = [Comment.new(321), Comment.new]

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      @post.comments.each do |comment|
        f.fields_for(:comments, comment) do |cf|
          concat cf.text_field(:name)
        end
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #321" />' +
               '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="321" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_an_empty_supplied_attributes_collection
    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:comments, []) do |cf|
        concat cf.text_field(:name)
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_with_existing_records_on_a_supplied_nested_attributes_collection
    @post.comments = Array.new(2) { |id| Comment.new(id + 1) }

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:comments, @post.comments) do |cf|
        concat cf.text_field(:name)
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #1" />' +
               '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="1" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="comment #2" />' +
               '<input id="post_comments_attributes_1_id" name="post[comments_attributes][1][id]" type="hidden" value="2" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_for_on_a_nested_attributes_collection_association_yields_only_builder
    @post.comments = [Comment.new(321), Comment.new]
    yielded_comments = []

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      f.fields_for(:comments) do |cf|
        concat cf.text_field(:name)
        yielded_comments << cf.object
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input name="post[title]" size="30" type="text" id="post_title" value="Hello World" />' +
               '<input id="post_comments_attributes_0_name" name="post[comments_attributes][0][name]" size="30" type="text" value="comment #321" />' +
               '<input id="post_comments_attributes_0_id" name="post[comments_attributes][0][id]" type="hidden" value="321" />' +
               '<input id="post_comments_attributes_1_name" name="post[comments_attributes][1][name]" size="30" type="text" value="new comment" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
    assert_equal yielded_comments, @post.comments
  end

  def test_nested_fields_for_with_child_index_option_override_on_a_nested_attributes_collection_association
    @post.comments = []

    form_for(:post, @post) do |f|
      f.fields_for(:comments, Comment.new(321), :child_index => 'abc') do |cf|
        concat cf.text_field(:name)
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
               '<input id="post_comments_attributes_abc_name" name="post[comments_attributes][abc][name]" size="30" type="text" value="comment #321" />' +
               '<input id="post_comments_attributes_abc_id" name="post[comments_attributes][abc][id]" type="hidden" value="321" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_nested_fields_uses_unique_indices_for_different_collection_associations
    @post.comments = [Comment.new(321)]
    @post.tags = [Tag.new(123), Tag.new(456)]
    @post.comments[0].relevances = []
    @post.tags[0].relevances = []
    @post.tags[1].relevances = []
    form_for(:post, @post) do |f|
      f.fields_for(:comments, @post.comments[0]) do |cf|
        concat cf.text_field(:name)
        cf.fields_for(:relevances, CommentRelevance.new(314)) do |crf|
          concat crf.text_field(:value)
        end
      end
      f.fields_for(:tags, @post.tags[0]) do |tf|
        concat tf.text_field(:value)
        tf.fields_for(:relevances, TagRelevance.new(3141)) do |trf|
          concat trf.text_field(:value)
        end
      end
      f.fields_for('tags', @post.tags[1]) do |tf|
        concat tf.text_field(:value)
        tf.fields_for(:relevances, TagRelevance.new(31415)) do |trf|
          concat trf.text_field(:value)
        end
      end
    end

    expected = '<form action="http://www.example.com" method="post">' +
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
               '<input id="post_tags_attributes_1_id" name="post[tags_attributes][1][id]" type="hidden" value="456" />' +
               '</form>'

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for
    fields_for(:post, @post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_index
    fields_for("post[]", @post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[123][title]' size='30' type='text' id='post_123_title' value='Hello World' />" +
      "<textarea name='post[123][body]' id='post_123_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[123][secret]' type='hidden' value='0' />" +
      "<input name='post[123][secret]' checked='checked' type='checkbox' id='post_123_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_nil_index_option_override
    fields_for("post[]", @post, :index => nil) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[][title]' size='30' type='text' id='post__title' value='Hello World' />" +
      "<textarea name='post[][body]' id='post__body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[][secret]' type='hidden' value='0' />" +
      "<input name='post[][secret]' checked='checked' type='checkbox' id='post__secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_index_option_override
    fields_for("post[]", @post, :index => "abc") do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[abc][title]' size='30' type='text' id='post_abc_title' value='Hello World' />" +
      "<textarea name='post[abc][body]' id='post_abc_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[abc][secret]' type='hidden' value='0' />" +
      "<input name='post[abc][secret]' checked='checked' type='checkbox' id='post_abc_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_without_object
    fields_for(:post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_only_object
    fields_for(@post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />"

    assert_dom_equal expected, output_buffer
  end

  def test_fields_for_object_with_bracketed_name
    fields_for("author[post]", @post) do |f|
      concat f.label(:title)
      concat f.text_field(:title)
    end

    assert_dom_equal "<label for=\"author_post_title\">Title</label>" +
    "<input name='author[post][title]' size='30' type='text' id='author_post_title' value='Hello World' />",
      output_buffer
  end

  def test_fields_for_object_with_bracketed_name_and_index
    fields_for("author[post]", @post, :index => 1) do |f|
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
    form_for(:post, @post, :html => { :id => 'create-post' }) do |post_form|
      concat post_form.text_field(:title)
      concat post_form.text_area(:body)

      fields_for(:parent_post, @post) do |parent_fields|
        concat parent_fields.check_box(:secret)
      end
    end

    expected =
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='parent_post[secret]' type='hidden' value='0' />" +
      "<input name='parent_post[secret]' checked='checked' type='checkbox' id='parent_post_secret' value='1' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_and_fields_for_with_object
    form_for(:post, @post, :html => { :id => 'create-post' }) do |post_form|
      concat post_form.text_field(:title)
      concat post_form.text_area(:body)

      post_form.fields_for(@comment) do |comment_fields|
        concat comment_fields.text_field(:name)
      end
    end

    expected =
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[comment][name]' type='text' id='post_comment_name' value='new comment' size='30' />" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    (field_helpers - %w(hidden_field)).each do |selector|
      src, line = <<-END_SRC, __LINE__ + 1
        def #{selector}(field, *args, &proc)
          ("<label for='\#{field}'>\#{field.to_s.humanize}:</label> " + super + "<br/>").html_safe
        end
      END_SRC
      class_eval src, __FILE__, line
    end
  end

  def test_form_for_with_labelled_builder
    form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' method='post'>" +
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>" +
      "</form>"

    assert_dom_equal expected, output_buffer
  end

  def test_default_form_builder
    old_default_form_builder, ActionView::Base.default_form_builder =
      ActionView::Base.default_form_builder, LabelledFormBuilder

    form_for(:post, @post) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<form action='http://www.example.com' method='post'>" +
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>" +
      "</form>"

    assert_dom_equal expected, output_buffer
  ensure
    ActionView::Base.default_form_builder = old_default_form_builder
  end

  def test_default_form_builder_with_active_record_helpers
    form_for(:post, @post) do |f|
       concat f.error_message_on('author_name')
       concat f.error_messages
    end

    expected = %(<form action='http://www.example.com' method='post'>) +
               %(<div class='formError'>can't be empty</div>) +
               %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>) +
               %(</form>)

    assert_dom_equal expected, output_buffer

  end

  def test_default_form_builder_no_instance_variable
    post = @post
    @post = nil

    form_for(:post, post) do |f|
       concat f.error_message_on('author_name')
       concat f.error_messages
    end

    expected = %(<form action='http://www.example.com' method='post'>) +
               %(<div class='formError'>can't be empty</div>) +
               %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>) +
               %(</form>)

    assert_dom_equal expected, output_buffer

  end
  
  def test_default_form_builder_without_object

    form_for(:post) do |f|
       concat f.error_message_on('author_name')
       concat f.error_messages
    end

    expected = %(<form action='http://www.example.com' method='post'>) +
               %(<div class='formError'>can't be empty</div>) +
               %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>) +
               %(</form>)

    assert_dom_equal expected, output_buffer

  end

  # Perhaps this test should be moved to prototype helper tests.
  def test_remote_form_for_with_labelled_builder
    self.extend ActionView::Helpers::PrototypeHelper

     remote_form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
       concat f.text_field(:title)
       concat f.text_area(:body)
       concat f.check_box(:secret)
     end

     expected =
       %(<form action="http://www.example.com" onsubmit="new Ajax.Request('http://www.example.com', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;" method="post">) +
       "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
       "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
       "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>" +
       "</form>"

     assert_dom_equal expected, output_buffer
  end

  def test_fields_for_with_labelled_builder
    fields_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      concat f.text_field(:title)
      concat f.text_area(:body)
      concat f.check_box(:secret)
    end

    expected =
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' /><br/>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_labelled_builder_with_nested_fields_for_without_options_hash
    klass = nil

    form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new) do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilder, klass
  end

  def test_form_for_with_labelled_builder_with_nested_fields_for_with_options_hash
    klass = nil

    form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new, :index => 'foo') do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilder, klass
  end

  class LabelledFormBuilderSubclass < LabelledFormBuilder; end

  def test_form_for_with_labelled_builder_with_nested_fields_for_with_custom_builder
    klass = nil

    form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      f.fields_for(:comments, Comment.new, :builder => LabelledFormBuilderSubclass) do |nested_fields|
        klass = nested_fields.class
        ''
      end
    end

    assert_equal LabelledFormBuilderSubclass, klass
  end

  def test_form_for_with_html_options_adds_options_to_form_tag
    form_for(:post, @post, :html => {:id => 'some_form', :class => 'some_class'}) do |f| end
    expected = "<form action=\"http://www.example.com\" class=\"some_class\" id=\"some_form\" method=\"post\"></form>"

    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_string_url_option
    form_for(:post, @post, :url => 'http://www.otherdomain.com') do |f| end

    assert_equal '<form action="http://www.otherdomain.com" method="post"></form>', output_buffer
  end

  def test_form_for_with_hash_url_option
    form_for(:post, @post, :url => {:controller => 'controller', :action => 'action'}) do |f| end

    assert_equal 'controller', @controller.url_for_options[:controller]
    assert_equal 'action', @controller.url_for_options[:action]
  end

  def test_form_for_with_record_url_option
    form_for(:post, @post, :url => @post) do |f| end

    expected = "<form action=\"/posts/123\" method=\"post\"></form>"
    assert_equal expected, output_buffer
  end

  def test_form_for_with_existing_object
    form_for(@post) do |f| end

    expected = "<form action=\"/posts/123\" class=\"edit_post\" id=\"edit_post_123\" method=\"post\"><div style=\"margin:0;padding:0;display:inline\"><input name=\"_method\" type=\"hidden\" value=\"put\" /></div></form>"
    assert_equal expected, output_buffer
  end

  def test_form_for_with_new_object
    post = Post.new
    post.new_record = true
    def post.id() nil end

    form_for(post) do |f| end

    expected = "<form action=\"/posts\" class=\"new_post\" id=\"new_post\" method=\"post\"></form>"
    assert_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_in_list
    @post.new_record = false
    @comment.save

    form_for([@post, @comment]) {}

    expected = %(<form action="#{comment_path(@post, @comment)}" class="edit_comment" id="edit_comment_1" method="post"><div style="margin:0;padding:0;display:inline"><input name="_method" type="hidden" value="put" /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_new_object_in_list
    @post.new_record = false

    form_for([@post, @comment]) {}

    expected = %(<form action="#{comments_path(@post)}" class="new_comment" id="new_comment" method="post"></form>)
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_and_namespace_in_list
    @post.new_record = false
    @comment.save

    form_for([:admin, @post, @comment]) {}

    expected = %(<form action="#{admin_comment_path(@post, @comment)}" class="edit_comment" id="edit_comment_1" method="post"><div style="margin:0;padding:0;display:inline"><input name="_method" type="hidden" value="put" /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_new_object_and_namespace_in_list
    @post.new_record = false

    form_for([:admin, @post, @comment]) {}

    expected = %(<form action="#{admin_comments_path(@post)}" class="new_comment" id="new_comment" method="post"></form>)
    assert_dom_equal expected, output_buffer
  end

  def test_form_for_with_existing_object_and_custom_url
    form_for(@post, :url => "/super_posts") do |f| end

    expected = "<form action=\"/super_posts\" class=\"edit_post\" id=\"edit_post_123\" method=\"post\"><div style=\"margin:0;padding:0;display:inline\"><input name=\"_method\" type=\"hidden\" value=\"put\" /></div></form>"
    assert_equal expected, output_buffer
  end

  def test_remote_form_for_with_html_options_adds_options_to_form_tag
    self.extend ActionView::Helpers::PrototypeHelper

    remote_form_for(:post, @post, :html => {:id => 'some_form', :class => 'some_class'}) do |f| end
    expected = "<form action=\"http://www.example.com\" class=\"some_class\" id=\"some_form\" method=\"post\" onsubmit=\"new Ajax.Request('http://www.example.com', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\"></form>"

    assert_dom_equal expected, output_buffer
  end

  protected
    def comments_path(post)
      "/posts/#{post.id}/comments"
    end
    alias_method :post_comments_path, :comments_path

    def comment_path(post, comment)
      "/posts/#{post.id}/comments/#{comment.id}"
    end
    alias_method :post_comment_path, :comment_path

    def admin_comments_path(post)
      "/admin/posts/#{post.id}/comments"
    end
    alias_method :admin_post_comments_path, :admin_comments_path

    def admin_comment_path(post, comment)
      "/admin/posts/#{post.id}/comments/#{comment.id}"
    end
    alias_method :admin_post_comment_path, :admin_comment_path

    def posts_path
      "/posts"
    end

    def post_path(post)
      "/posts/#{post.id}"
    end

    def protect_against_forgery?
      false
    end
end
