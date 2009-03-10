require 'abstract_unit'

class ActiveRecordHelperTest < ActionView::TestCase
  tests ActionView::Helpers::ActiveRecordHelper

  silence_warnings do
    Post = Struct.new("Post", :title, :author_name, :body, :secret, :written_on)
    Post.class_eval do
      alias_method :title_before_type_cast, :title unless respond_to?(:title_before_type_cast)
      alias_method :body_before_type_cast, :body unless respond_to?(:body_before_type_cast)
      alias_method :author_name_before_type_cast, :author_name unless respond_to?(:author_name_before_type_cast)
    end

    User = Struct.new("User", :email)
    User.class_eval do
      alias_method :email_before_type_cast, :email unless respond_to?(:email_before_type_cast)
    end

    Column = Struct.new("Column", :type, :name, :human_name)
  end

  class DirtyPost
    class Errors
      def empty?
        false
      end

      def count
        1
      end

      def full_messages
        ["Author name can't be <em>empty</em>"]
      end

      def on(field)
        "can't be <em>empty</em>"
      end
    end

    def errors
      Errors.new
    end
  end

  def setup_post
    @post = Post.new
    def @post.errors
      Class.new {
        def on(field)
          case field.to_s
          when "author_name"
            "can't be empty"
          when "body"
            true
          else
            false
          end
        end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "Author name can't be empty" ] end
      }.new
    end

    def @post.new_record?() true end
    def @post.to_param() nil end

    def @post.column_for_attribute(attr_name)
      Post.content_columns.select { |column| column.name == attr_name }.first
    end

    silence_warnings do
      def Post.content_columns() [ Column.new(:string, "title", "Title"), Column.new(:text, "body", "Body") ] end
    end

    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret = 1
    @post.written_on  = Date.new(2004, 6, 15)
  end

  def setup_user
    @user = User.new
    def @user.errors
      Class.new {
        def on(field) field == "email" end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "User email can't be empty" ] end
      }.new
    end

    def @user.new_record?() true end
    def @user.to_param() nil end

    def @user.column_for_attribute(attr_name)
      User.content_columns.select { |column| column.name == attr_name }.first
    end

    silence_warnings do
      def User.content_columns() [ Column.new(:string, "email", "Email") ] end
    end

    @user.email = ""
  end

  def protect_against_forgery?
    @protect_against_forgery ? true : false
  end
  attr_accessor :request_forgery_protection_token, :form_authenticity_token

  def setup
    setup_post
    setup_user

    @response = ActionController::TestResponse.new

    @controller = Object.new
    def @controller.url_for(options)
      options = options.symbolize_keys

      [options[:action], options[:id].to_param].compact.join('/')
    end
  end

  def test_generic_input_tag
    assert_dom_equal(
      %(<input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />), input("post", "title")
    )
  end

  def test_text_area_with_errors
    assert_dom_equal(
      %(<div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div>),
      text_area("post", "body")
    )
  end

  def test_text_field_with_errors
    assert_dom_equal(
      %(<div class="fieldWithErrors"><input id="post_author_name" name="post[author_name]" size="30" type="text" value="" /></div>),
      text_field("post", "author_name")
    )
  end

  def test_form_with_string
    assert_dom_equal(
      %(<form action="create" method="post"><p><label for="post_title">Title</label><br /><input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /></p>\n<p><label for="post_body">Body</label><br /><div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div></p><input name="commit" type="submit" value="Create" /></form>),
      form("post")
    )

    silence_warnings do
      class << @post
        def new_record?() false end
        def to_param() id end
        def id() 1 end
      end
    end

    assert_dom_equal(
      %(<form action="update/1" method="post"><input id="post_id" name="post[id]" type="hidden" value="1" /><p><label for="post_title">Title</label><br /><input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /></p>\n<p><label for="post_body">Body</label><br /><div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div></p><input name="commit" type="submit" value="Update" /></form>),
      form("post")
    )
  end

  def test_form_with_protect_against_forgery
    @protect_against_forgery = true
    @request_forgery_protection_token = 'authenticity_token'
    @form_authenticity_token = '123'
    assert_dom_equal(
      %(<form action="create" method="post"><div style='margin:0;padding:0'><input type='hidden' name='authenticity_token' value='123' /></div><p><label for="post_title">Title</label><br /><input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /></p>\n<p><label for="post_body">Body</label><br /><div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div></p><input name="commit" type="submit" value="Create" /></form>),
      form("post")
    )
  end

  def test_form_with_method_option
    assert_dom_equal(
      %(<form action="create" method="get"><p><label for="post_title">Title</label><br /><input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /></p>\n<p><label for="post_body">Body</label><br /><div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div></p><input name="commit" type="submit" value="Create" /></form>),
      form("post", :method=>'get')
    )
  end

  def test_form_with_action_option
    @response.body = form("post", :action => "sign")
    assert_select "form[action=sign]" do |form|
      assert_select "input[type=submit][value=Sign]"
    end
  end

  def test_form_with_date
    silence_warnings do
      def Post.content_columns() [ Column.new(:date, "written_on", "Written on") ] end
    end

    assert_dom_equal(
      %(<form action="create" method="post"><p><label for="post_written_on">Written on</label><br /><select id="post_written_on_1i" name="post[written_on(1i)]">\n<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n</select>\n<select id="post_written_on_2i" name="post[written_on(2i)]">\n<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n</select>\n<select id="post_written_on_3i" name="post[written_on(3i)]">\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n</select>\n</p><input name="commit" type="submit" value="Create" /></form>),
      form("post")
    )
  end

  def test_form_with_datetime
    silence_warnings do
      def Post.content_columns() [ Column.new(:datetime, "written_on", "Written on") ] end
    end
    @post.written_on  = Time.gm(2004, 6, 15, 16, 30)

    assert_dom_equal(
      %(<form action="create" method="post"><p><label for="post_written_on">Written on</label><br /><select id="post_written_on_1i" name="post[written_on(1i)]">\n<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n</select>\n<select id="post_written_on_2i" name="post[written_on(2i)]">\n<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n</select>\n<select id="post_written_on_3i" name="post[written_on(3i)]">\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n</select>\n &mdash; <select id="post_written_on_4i" name="post[written_on(4i)]">\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n</select>\n : <select id="post_written_on_5i" name="post[written_on(5i)]">\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30" selected="selected">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n</select>\n</p><input name="commit" type="submit" value="Create" /></form>),
      form("post")
    )
  end

  def test_error_for_block
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post")
    assert_equal %(<div class="errorDeathByClass" id="errorDeathById"><h1>1 error prohibited this post from being saved</h1><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post", :class => "errorDeathByClass", :id => "errorDeathById", :header_tag => "h1")
    assert_equal %(<div id="errorDeathById"><h1>1 error prohibited this post from being saved</h1><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post", :class => nil, :id => "errorDeathById", :header_tag => "h1")
    assert_equal %(<div class="errorDeathByClass"><h1>1 error prohibited this post from being saved</h1><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post", :class => "errorDeathByClass", :id => nil, :header_tag => "h1")
  end

  def test_error_messages_for_escapes_html
    @dirty_post = DirtyPost.new
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this dirty post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be &lt;em&gt;empty&lt;/em&gt;</li></ul></div>), error_messages_for("dirty_post")
  end

  def test_error_messages_for_handles_nil
    assert_equal "", error_messages_for("notthere")
  end

  def test_error_message_on_escapes_html
    @dirty_post = DirtyPost.new
    assert_dom_equal "<div class=\"formError\">can't be &lt;em&gt;empty&lt;/em&gt;</div>", error_message_on(:dirty_post, :author_name)
  end

  def test_error_message_on_handles_nil
    assert_equal "", error_message_on("notthere", "notthere")
  end

  def test_error_message_on
    assert_dom_equal "<div class=\"formError\">can't be empty</div>", error_message_on(:post, :author_name)
  end

  def test_error_message_on_no_instance_variable
    other_post = @post
    assert_dom_equal "<div class=\"formError\">can't be empty</div>", error_message_on(other_post, :author_name)
  end

  def test_error_message_on_with_options_hash
    assert_dom_equal "<div class=\"differentError\">beforecan't be emptyafter</div>", error_message_on(:post, :author_name, :css_class => 'differentError', :prepend_text => 'before', :append_text => 'after')
  end

  def test_error_messages_for_many_objects
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li><li>User email can't be empty</li></ul></div>), error_messages_for("post", "user")

    # reverse the order, error order changes and so does the title
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this user from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post")

    # add the default to put post back in the title
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post", :object_name => "post")

    # symbols work as well
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => :post)

    # any default works too
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this monkey from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => "monkey")

    # should space object name
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this chunky bacon from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => "chunky_bacon")

    # hide header and explanation messages with nil or empty string
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :header_message => nil, :message => "")

    # override header and explanation messages
    header_message = "Yikes! Some errors"
    message = "Please fix the following fields and resubmit:"
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>#{header_message}</h2><p>#{message}</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :header_message => header_message, :message => message)
  end

  def test_error_messages_for_non_instance_variable
    actual_user = @user
    actual_post = @post
    @user = nil
    @post = nil

  #explicitly set object
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post", :object => actual_post)

  #multiple objects
    assert_dom_equal %(<div class="errorExplanation" id="errorExplanation"><h2>2 errors prohibited this user from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post", :object => [actual_user, actual_post])

  #nil object
    assert_equal '', error_messages_for('user', :object => nil)
  end

  def test_form_with_string_multipart
    assert_dom_equal(
      %(<form action="create" enctype="multipart/form-data" method="post"><p><label for="post_title">Title</label><br /><input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /></p>\n<p><label for="post_body">Body</label><br /><div class="fieldWithErrors"><textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea></div></p><input name="commit" type="submit" value="Create" /></form>),
      form("post", :multipart => true)
    )
  end
end
