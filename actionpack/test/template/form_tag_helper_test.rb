require 'abstract_unit'

class FormTagHelperTest < ActionView::TestCase
  tests ActionView::Helpers::FormTagHelper

  def setup
    @controller = Class.new do
      def url_for(options)
        "http://www.example.com"
      end
    end
    @controller = @controller.new
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
    expected = %(<form action="http://www.example.com" method="post">)
    assert_dom_equal expected, actual
  end

  def test_form_tag_multipart
    actual = form_tag({}, { 'multipart' => true })
    expected = %(<form action="http://www.example.com" enctype="multipart/form-data" method="post">)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_put
    actual = form_tag({}, { :method => :put })
    expected = %(<form action="http://www.example.com" method="post"><div style='margin:0;padding:0;display:inline'><input type="hidden" name="_method" value="put" /></div>)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_delete
    actual = form_tag({}, { :method => :delete })
    expected = %(<form action="http://www.example.com" method="post"><div style='margin:0;padding:0;display:inline'><input type="hidden" name="_method" value="delete" /></div>)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_block_in_erb
    __in_erb_template = ''
    form_tag("http://example.com") { concat "Hello world!" }

    expected = %(<form action="http://example.com" method="post">Hello world!</form>)
    assert_dom_equal expected, output_buffer
  end

  def test_form_tag_with_block_and_method_in_erb
    __in_erb_template = ''
    form_tag("http://example.com", :method => :put) { concat "Hello world!" }

    expected = %(<form action="http://example.com" method="post"><div style='margin:0;padding:0;display:inline'><input type="hidden" name="_method" value="put" /></div>Hello world!</form>)
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

  def test_select_tag_with_array_options
    assert_deprecated /array/ do
      select_tag "people", ["<option>david</option>"]
    end
  end

  def test_text_area_tag_size_string
    actual = text_area_tag "body", "hello world", "size" => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">hello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_size_symbol
    actual = text_area_tag "body", "hello world", :size => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">hello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_should_disregard_size_if_its_given_as_an_integer
    actual = text_area_tag "body", "hello world", :size => 20
    expected = %(<textarea id="body" name="body">hello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_id_sanitized
    input_elem = root_elem(text_area_tag("item[][description]"))
    assert_match VALID_HTML_ID, input_elem['id']
  end

  def test_text_area_tag_escape_content
    actual = text_area_tag "body", "<b>hello world</b>", :size => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">&lt;b&gt;hello world&lt;/b&gt;</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_unescaped_content
    actual = text_area_tag "body", "<b>hello world</b>", :size => "20x40", :escape => false
    expected = %(<textarea cols="20" id="body" name="body" rows="40"><b>hello world</b></textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_area_tag_unescaped_nil_content
    actual = text_area_tag "body", nil, :escape => false
    expected = %(<textarea id="body" name="body"></textarea>)
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
      %(<input name='commit' onclick="if (window.hiddenCommit) { window.hiddenCommit.setAttribute('value', this.value); }else { hiddenCommit = document.createElement('input');hiddenCommit.type = 'hidden';hiddenCommit.value = this.value;hiddenCommit.name = this.name;this.form.appendChild(hiddenCommit); }this.setAttribute('originalValue', this.value);this.disabled = true;this.value='Saving...';alert('hello!');result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());if (result == false) { this.value = this.getAttribute('originalValue');this.disabled = false; }return result;" type="submit" value="Save" />),
      submit_tag("Save", :disable_with => "Saving...", :onclick => "alert('hello!')")
    )
  end

  def test_submit_tag_with_no_onclick_options
    assert_dom_equal(
      %(<input name='commit' onclick="if (window.hiddenCommit) { window.hiddenCommit.setAttribute('value', this.value); }else { hiddenCommit = document.createElement('input');hiddenCommit.type = 'hidden';hiddenCommit.value = this.value;hiddenCommit.name = this.name;this.form.appendChild(hiddenCommit); }this.setAttribute('originalValue', this.value);this.disabled = true;this.value='Saving...';result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());if (result == false) { this.value = this.getAttribute('originalValue');this.disabled = false; }return result;" type="submit" value="Save" />),
      submit_tag("Save", :disable_with => "Saving...")
    )
  end

  def test_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input name='commit' type='submit' value='Save' onclick="if (!confirm('Are you sure?')) return false; return true;"/>),
      submit_tag("Save", :confirm => "Are you sure?")
    )
  end

  def test_submit_tag_with_confirmation_and_with_disable_with
    assert_dom_equal(
      %(<input name="commit" onclick="if (!confirm('Are you sure?')) return false; if (window.hiddenCommit) { window.hiddenCommit.setAttribute('value', this.value); }else { hiddenCommit = document.createElement('input');hiddenCommit.type = 'hidden';hiddenCommit.value = this.value;hiddenCommit.name = this.name;this.form.appendChild(hiddenCommit); }this.setAttribute('originalValue', this.value);this.disabled = true;this.value='Saving...';result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());if (result == false) { this.value = this.getAttribute('originalValue');this.disabled = false; }return result;" type="submit" value="Save" />),
      submit_tag("Save", :disable_with => "Saving...", :confirm => "Are you sure?")
    )
  end

  def test_image_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input type="image" src="/images/save.gif" onclick="return confirm('Are you sure?');"/>),
      image_submit_tag("save.gif", :confirm => "Are you sure?")
    )
  end

  def test_pass
    assert_equal 1, 1
  end

  def test_field_set_tag_in_erb
    __in_erb_template = ''
    field_set_tag("Your details") { concat "Hello world!" }

    expected = %(<fieldset><legend>Your details</legend>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    self.output_buffer = ''.html_safe
    field_set_tag { concat "Hello world!" }

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    self.output_buffer = ''.html_safe
    field_set_tag('') { concat "Hello world!" }

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    self.output_buffer = ''.html_safe
    field_set_tag('', :class => 'format') { concat "Hello world!" }

    expected = %(<fieldset class="format">Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer
  end

  def protect_against_forgery?
    false
  end

  private

  def root_elem(rendered_content)
    HTML::Document.new(rendered_content).root.children[0]
  end
end
