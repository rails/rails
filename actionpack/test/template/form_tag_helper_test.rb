require 'abstract_unit'

class FormTagHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::FormTagHelper

  def setup
    super
    @controller = BasicController.new
  end

  def hidden_fields(options = {})
    method = options[:method]

    txt =  %{<div style="margin:0;padding:0;display:inline">}
    txt << %{<input name="utf8" type="hidden" value="&#x2713;" />}
    if method && !%w(get post).include?(method.to_s)
      txt << %{<input name="_method" type="hidden" value="#{method}" />}
    end
    txt << %{</div>}
  end

  def form_text(action = "http://www.example.com", options = {})
    remote, enctype, html_class, id, method = options.values_at(:remote, :enctype, :html_class, :id, :method)

    method = method.to_s == "get" ? "get" : "post"

    txt =  %{<form accept-charset="UTF-8" action="#{action}"}
    txt << %{ enctype="multipart/form-data"} if enctype
    txt << %{ data-remote="true"} if remote
    txt << %{ class="#{html_class}"} if html_class
    txt << %{ id="#{id}"} if id
    txt << %{ method="#{method}">}
  end

  def whole_form(action = "http://www.example.com", options = {})
    out = form_text(action, options) + hidden_fields(options)

    if block_given?
      out << yield << "</form>"
    end

    out
  end

  def url_for(options)
    if options.is_a?(Hash)
      "http://www.example.com"
    else
      super
    end
  end

  VALID_HTML_ID = /^[A-Za-z][-_:.A-Za-z0-9]*$/ # see http://www.w3.org/TR/html4/types.html#type-name

  def test_check_box_tag
    actual = check_box_tag "admin"
    expected = %(<input id="admin" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_check_box_tag_id_sanitized
    label_elem = root_elem(check_box_tag("project[2][admin]"))
    assert_match VALID_HTML_ID, label_elem['id']
  end

  def test_form_tag
    actual = form_tag
    expected = whole_form
    assert_dom_equal expected, actual
  end

  def test_form_tag_multipart
    actual = form_tag({}, { 'multipart' => true })
    expected = whole_form("http://www.example.com", :enctype => true)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_patch
    actual = form_tag({}, { :method => :patch })
    expected = whole_form("http://www.example.com", :method => :patch)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_put
    actual = form_tag({}, { :method => :put })
    expected = whole_form("http://www.example.com", :method => :put)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_delete
    actual = form_tag({}, { :method => :delete })

    expected = whole_form("http://www.example.com", :method => :delete)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_remote
    actual = form_tag({}, :remote => true)

    expected = whole_form("http://www.example.com", :remote => true)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_remote_false
    actual = form_tag({}, :remote => false)

    expected = whole_form
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_block_in_erb
    output_buffer = render_erb("<%= form_tag('http://www.example.com') do %>Hello world!<% end %>")

    expected = whole_form { "Hello world!" }
    assert_dom_equal expected, output_buffer
  end

  def test_form_tag_with_block_and_method_in_erb
    output_buffer = render_erb("<%= form_tag('http://www.example.com', :method => :put) do %>Hello world!<% end %>")

    expected = whole_form("http://www.example.com", :method => "put") do
      "Hello world!"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_hidden_field_tag
    actual = hidden_field_tag "id", 3
    expected = %(<input id="id" name="id" type="hidden" value="3" />)
    assert_dom_equal expected, actual
  end

  def test_hidden_field_tag_id_sanitized
    input_elem = root_elem(hidden_field_tag("item[][title]"))
    assert_match VALID_HTML_ID, input_elem['id']
  end

  def test_file_field_tag
    assert_dom_equal "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" />", file_field_tag("picsplz")
  end

  def test_file_field_tag_with_options
    assert_dom_equal "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" class=\"pix\"/>", file_field_tag("picsplz", :class => "pix")
  end

  def test_password_field_tag
    actual = password_field_tag
    expected = %(<input id="password" name="password" type="password" />)
    assert_dom_equal expected, actual
  end

  def test_radio_button_tag
    actual = radio_button_tag "people", "david"
    expected = %(<input id="people_david" name="people" type="radio" value="david" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("num_people", 5)
    expected = %(<input id="num_people_5" name="num_people" type="radio" value="5" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("gender", "m") + radio_button_tag("gender", "f")
    expected = %(<input id="gender_m" name="gender" type="radio" value="m" /><input id="gender_f" name="gender" type="radio" value="f" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("opinion", "-1") + radio_button_tag("opinion", "1")
    expected = %(<input id="opinion_-1" name="opinion" type="radio" value="-1" /><input id="opinion_1" name="opinion" type="radio" value="1" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("person[gender]", "m")
    expected = %(<input id="person_gender_m" name="person[gender]" type="radio" value="m" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag('ctrlname', 'apache2.2')
    expected = %(<input id="ctrlname_apache2.2" name="ctrlname" type="radio" value="apache2.2" />)
    assert_dom_equal expected, actual
  end

  def test_select_tag
    actual = select_tag "people", "<option>david</option>".html_safe
    expected = %(<select id="people" name="people"><option>david</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_multiple
    actual = select_tag "colors", "<option>Red</option><option>Blue</option><option>Green</option>".html_safe, :multiple => :true
    expected = %(<select id="colors" multiple="multiple" name="colors"><option>Red</option><option>Blue</option><option>Green</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_disabled
    actual = select_tag "places", "<option>Home</option><option>Work</option><option>Pub</option>".html_safe, :disabled => :true
    expected = %(<select id="places" disabled="disabled" name="places"><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_id_sanitized
    input_elem = root_elem(select_tag("project[1]people", "<option>david</option>"))
    assert_match VALID_HTML_ID, input_elem['id']
  end

  def test_select_tag_with_include_blank
    actual = select_tag "places", "<option>Home</option><option>Work</option><option>Pub</option>".html_safe, :include_blank => true
    expected = %(<select id="places" name="places"><option value=""></option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_prompt
    actual = select_tag "places", "<option>Home</option><option>Work</option><option>Pub</option>".html_safe, :prompt => "string"
    expected = %(<select id="places" name="places"><option value="">string</option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_escapes_prompt
    actual = select_tag "places", "<option>Home</option><option>Work</option><option>Pub</option>".html_safe, :prompt => "<script>alert(1337)</script>"
    expected = %(<select id="places" name="places"><option value="">&lt;script&gt;alert(1337)&lt;/script&gt;</option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_prompt_and_include_blank
    actual = select_tag "places", "<option>Home</option><option>Work</option><option>Pub</option>".html_safe, :prompt => "string", :include_blank => true
    expected = %(<select name="places" id="places"><option value="">string</option><option value=""></option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_nil_option_tags_and_include_blank
    actual = select_tag "places", nil, :include_blank => true
    expected = %(<select id="places" name="places"><option value=""></option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_nil_option_tags_and_prompt
    actual = select_tag "places", nil, :prompt => "string"
    expected = %(<select id="places" name="places"><option value="">string</option></select>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_size_string
    actual = text_area_tag "body", "hello world", "size" => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_size_symbol
    actual = text_area_tag "body", "hello world", :size => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_should_disregard_size_if_its_given_as_an_integer
    actual = text_area_tag "body", "hello world", :size => 20
    expected = %(<textarea id="body" name="body">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_id_sanitized
    input_elem = root_elem(text_area_tag("item[][description]"))
    assert_match VALID_HTML_ID, input_elem['id']
  end

  def test_text_area_tag_escape_content
    actual = text_area_tag "body", "<b>hello world</b>", :size => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\n&lt;b&gt;hello world&lt;/b&gt;</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_unescaped_content
    actual = text_area_tag "body", "<b>hello world</b>", :size => "20x40", :escape => false
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\n<b>hello world</b></textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_unescaped_nil_content
    actual = text_area_tag "body", nil, :escape => false
    expected = %(<textarea id="body" name="body">\n</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag
    actual = text_field_tag "title", "Hello!"
    expected = %(<input id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_class_string
    actual = text_field_tag "title", "Hello!", "class" => "admin"
    expected = %(<input class="admin" id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_size_symbol
    actual = text_field_tag "title", "Hello!", :size => 75
    expected = %(<input id="title" name="title" size="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_size_string
    actual = text_field_tag "title", "Hello!", "size" => "75"
    expected = %(<input id="title" name="title" size="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_maxlength_symbol
    actual = text_field_tag "title", "Hello!", :maxlength => 75
    expected = %(<input id="title" name="title" maxlength="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_maxlength_string
    actual = text_field_tag "title", "Hello!", "maxlength" => "75"
    expected = %(<input id="title" name="title" maxlength="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_disabled
    actual = text_field_tag "title", "Hello!", :disabled => :true
    expected = %(<input id="title" name="title" disabled="disabled" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_with_multiple_options
    actual = text_field_tag "title", "Hello!", :size => 70, :maxlength => 80
    expected = %(<input id="title" name="title" size="70" maxlength="80" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_id_sanitized
    input_elem = root_elem(text_field_tag("item[][title]"))
    assert_match VALID_HTML_ID, input_elem['id']
  end

  def test_label_tag_without_text
    actual = label_tag "title"
    expected = %(<label for="title">Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_with_symbol
    actual = label_tag :title
    expected = %(<label for="title">Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_with_text
    actual = label_tag "title", "My Title"
    expected = %(<label for="title">My Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_class_string
    actual = label_tag "title", "My Title", "class" => "small_label"
    expected = %(<label for="title" class="small_label">My Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_id_sanitized
    label_elem = root_elem(label_tag("item[title]"))
    assert_match VALID_HTML_ID, label_elem['for']
  end

  def test_label_tag_with_block
    assert_dom_equal('<label>Blocked</label>', label_tag { "Blocked" })
  end

  def test_label_tag_with_block_and_argument
    output = label_tag("clock") { "Grandfather" }
    assert_dom_equal('<label for="clock">Grandfather</label>', output)
  end

  def test_label_tag_with_block_and_argument_and_options
    output = label_tag("clock", :id => "label_clock") { "Grandfather" }
    assert_dom_equal('<label for="clock" id="label_clock">Grandfather</label>', output)
  end

  def test_boolean_options
    assert_dom_equal %(<input checked="checked" disabled="disabled" id="admin" name="admin" readonly="readonly" type="checkbox" value="1" />), check_box_tag("admin", 1, true, 'disabled' => true, :readonly => "yes")
    assert_dom_equal %(<input checked="checked" id="admin" name="admin" type="checkbox" value="1" />), check_box_tag("admin", 1, true, :disabled => false, :readonly => nil)
    assert_dom_equal %(<input type="checkbox" />), tag(:input, :type => "checkbox", :checked => false)
    assert_dom_equal %(<select id="people" multiple="multiple" name="people[]"><option>david</option></select>), select_tag("people", "<option>david</option>".html_safe, :multiple => true)
    assert_dom_equal %(<select id="people_" multiple="multiple" name="people[]"><option>david</option></select>), select_tag("people[]", "<option>david</option>".html_safe, :multiple => true)
    assert_dom_equal %(<select id="people" name="people"><option>david</option></select>), select_tag("people", "<option>david</option>".html_safe, :multiple => nil)
  end

  def test_stringify_symbol_keys
    actual = text_field_tag "title", "Hello!", :id => "admin"
    expected = %(<input id="admin" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_submit_tag
    assert_dom_equal(
      %(<input name='commit' data-disable-with="Saving..." onclick="alert(&#39;hello!&#39;)" type="submit" value="Save" />),
      submit_tag("Save", :onclick => "alert('hello!')", :data => { :disable_with => "Saving..." })
    )
  end

  def test_submit_tag_with_no_onclick_options
    assert_dom_equal(
      %(<input name='commit' data-disable-with="Saving..." type="submit" value="Save" />),
      submit_tag("Save", :data => { :disable_with => "Saving..." })
    )
  end

  def test_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input name='commit' type='submit' value='Save' data-confirm="Are you sure?" />),
      submit_tag("Save", :data => { :confirm => "Are you sure?" })
    )
  end

  def test_submit_tag_with_deprecated_confirmation
    assert_deprecated ":confirm option is deprecated and will be removed from Rails 4.1. Use ':data => { :confirm => \'Text\' }' instead" do
      assert_dom_equal(
        %(<input name='commit' type='submit' value='Save' data-confirm="Are you sure?" />),
        submit_tag("Save", :confirm => "Are you sure?")
      )
    end
  end

  def test_button_tag
    assert_dom_equal(
      %(<button name="button" type="submit">Button</button>),
      button_tag
    )
  end

  def test_button_tag_with_submit_type
    assert_dom_equal(
      %(<button name="button" type="submit">Save</button>),
      button_tag("Save", :type => "submit")
    )
  end

  def test_button_tag_with_button_type
    assert_dom_equal(
      %(<button name="button" type="button">Button</button>),
      button_tag("Button", :type => "button")
    )
  end

  def test_button_tag_with_reset_type
    assert_dom_equal(
      %(<button name="button" type="reset">Reset</button>),
      button_tag("Reset", :type => "reset")
    )
  end

  def test_button_tag_with_disabled_option
    assert_dom_equal(
      %(<button name="button" type="reset" disabled="disabled">Reset</button>),
      button_tag("Reset", :type => "reset", :disabled => true)
    )
  end

  def test_button_tag_escape_content
    assert_dom_equal(
      %(<button name="button" type="reset" disabled="disabled">&lt;b&gt;Reset&lt;/b&gt;</button>),
      button_tag("<b>Reset</b>", :type => "reset", :disabled => true)
    )
  end

  def test_button_tag_with_block
    assert_dom_equal('<button name="button" type="submit">Content</button>', button_tag { 'Content' })
  end

  def test_button_tag_with_block_and_options
    output = button_tag(:name => 'temptation', :type => 'button') { content_tag(:strong, 'Do not press me') }
    assert_dom_equal('<button name="temptation" type="button"><strong>Do not press me</strong></button>', output)
  end

  def test_button_tag_with_confirmation
    assert_dom_equal(
      %(<button name="button" type="submit" data-confirm="Are you sure?">Save</button>),
      button_tag("Save", :type => "submit", :data => { :confirm => "Are you sure?" })
    )
  end

  def test_button_tag_with_deprecated_confirmation
    assert_deprecated ":confirm option is deprecated and will be removed from Rails 4.1. Use ':data => { :confirm => \'Text\' }' instead" do
      assert_dom_equal(
        %(<button name="button" type="submit" data-confirm="Are you sure?">Save</button>),
        button_tag("Save", :type => "submit", :confirm => "Are you sure?")
      )
    end
  end

  def test_image_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input type="image" src="/images/save.gif" data-confirm="Are you sure?" />),
      image_submit_tag("save.gif", :data => { :confirm => "Are you sure?" })
    )
  end

  def test_image_submit_tag_with_deprecated_confirmation
    assert_deprecated ":confirm option is deprecated and will be removed from Rails 4.1. Use ':data => { :confirm => \'Text\' }' instead" do
      assert_dom_equal(
        %(<input type="image" src="/images/save.gif" data-confirm="Are you sure?" />),
        image_submit_tag("save.gif", :confirm => "Are you sure?")
      )
    end
  end


  def test_color_field_tag
    expected = %{<input id="car" name="car" type="color" />}
    assert_dom_equal(expected, color_field_tag("car"))
  end

  def test_search_field_tag
    expected = %{<input id="query" name="query" type="search" />}
    assert_dom_equal(expected, search_field_tag("query"))
  end

  def test_telephone_field_tag
    expected = %{<input id="cell" name="cell" type="tel" />}
    assert_dom_equal(expected, telephone_field_tag("cell"))
  end

  def test_date_field_tag
    expected = %{<input id="cell" name="cell" type="date" />}
    assert_dom_equal(expected, date_field_tag("cell"))
  end

  def test_time_field_tag
    expected = %{<input id="cell" name="cell" type="time" />}
    assert_dom_equal(expected, time_field_tag("cell"))
  end

  def test_datetime_field_tag
    expected = %{<input id="appointment" name="appointment" type="datetime" />}
    assert_dom_equal(expected, datetime_field_tag("appointment"))
  end

  def test_datetime_local_field_tag
    expected = %{<input id="appointment" name="appointment" type="datetime-local" />}
    assert_dom_equal(expected, datetime_local_field_tag("appointment"))
  end

  def test_month_field_tag
    expected = %{<input id="birthday" name="birthday" type="month" />}
    assert_dom_equal(expected, month_field_tag("birthday"))
  end

  def test_week_field_tag
    expected = %{<input id="birthday" name="birthday" type="week" />}
    assert_dom_equal(expected, week_field_tag("birthday"))
  end

  def test_url_field_tag
    expected = %{<input id="homepage" name="homepage" type="url" />}
    assert_dom_equal(expected, url_field_tag("homepage"))
  end

  def test_email_field_tag
    expected = %{<input id="address" name="address" type="email" />}
    assert_dom_equal(expected, email_field_tag("address"))
  end

  def test_number_field_tag
    expected = %{<input name="quantity" max="9" id="quantity" type="number" min="1" />}
    assert_dom_equal(expected, number_field_tag("quantity", nil, :in => 1...10))
  end

  def test_range_input_tag
    expected = %{<input name="volume" step="0.1" max="11" id="volume" type="range" min="0" />}
    assert_dom_equal(expected, range_field_tag("volume", nil, :in => 0..11, :step => 0.1))
  end

  def test_field_set_tag_in_erb
    output_buffer = render_erb("<%= field_set_tag('Your details') do %>Hello world!<% end %>")

    expected = %(<fieldset><legend>Your details</legend>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag do %>Hello world!<% end %>")

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('') do %>Hello world!<% end %>")

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('', :class => 'format') do %>Hello world!<% end %>")

    expected = %(<fieldset class="format">Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag %>")

    expected = %(<fieldset></fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('You legend!') %>")

    expected = %(<fieldset><legend>You legend!</legend></fieldset>)
    assert_dom_equal expected, output_buffer
  end

  def test_text_area_tag_options_symbolize_keys_side_effects
    options = { :option => "random_option" }
    text_area_tag "body", "hello world", options
    assert_equal options, { :option => "random_option" }
  end

  def test_submit_tag_options_symbolize_keys_side_effects
    options = { :option => "random_option" }
    submit_tag "submit value", options
    assert_equal options, { :option => "random_option" }
  end

  def test_button_tag_options_symbolize_keys_side_effects
    options = { :option => "random_option" }
    button_tag "button value", options
    assert_equal options, { :option => "random_option" }
  end

  def test_image_submit_tag_options_symbolize_keys_side_effects
    options = { :option => "random_option" }
    image_submit_tag "submit source", options
    assert_equal options, { :option => "random_option" }
  end

  def test_image_label_tag_options_symbolize_keys_side_effects
    options = { :option => "random_option" }
    label_tag "submit source", "title", options
    assert_equal options, { :option => "random_option" }
  end

  def protect_against_forgery?
    false
  end

  private

  def root_elem(rendered_content)
    HTML::Document.new(rendered_content).root.children[0]
  end
end
