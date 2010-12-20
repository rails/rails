require 'abstract_unit'

class BodyHelperTest < ActionView::TestCase
  tests ActionView::Helpers::BodyHelper

  MockController = Struct.new(:controller_path, :action_name)

  attr_accessor :controller

  def setup
    @controller = MockController.new("foo", "bar")
  end

  def teardown
    @controller = nil
    @body_attributes = nil
  end

  def test_controller_class_names
    assert_equal("foo bar", controller_class_names)
  end

  def test_controller_class_names_for_complex_controllers
    @controller.controller_path = "scoped/camel_cased"
    assert_equal("scoped camel-cased bar", controller_class_names)
  end

  def test_unspecified_body_attributes_just_class_names
    assert_equal({:class => controller_class_names}, body_attributes)
  end

  def test_body_attributes_can_be_overridden
    # The default attributes are there unless specified
    add_body_attributes(:style=>"color:#333;")
    assert_equal({:class=>"foo bar", :style=>"color:#333;"}, body_attributes)

    # can specify only some of the default attributes
    add_body_attributes(:id=>"special-id")
    assert_equal({:class=>"foo bar", :id=>"special-id", :style=>"color:#333;"}, body_attributes)
    add_body_attributes(:class=>"special-class")
    assert_equal({:class=>"special-class", :id=>"special-id", :style=>"color:#333;"}, body_attributes)

    # tag attributes are merged when they can be
    add_body_attributes(:class=>"another-special-class")
    assert_equal({:class=>"another-special-class special-class", :id=>"special-id", :style=>"color:#333;"}, body_attributes)
  end

  def test_body_tag
    buffer = body_tag { concat "Hello world!" }
    assert_dom_equal %Q{<body class="foo bar">Hello world!</body>}, buffer

    buffer = body_tag(:style => "color:red;") { concat "Hello world!" }
    assert_dom_equal %Q{<body class="foo bar" style="color:red;">Hello world!</body>}, buffer

    buffer = body_tag(:class=>"hi", :id=>"world") { concat "Hello world, again!" }
    assert_dom_equal %Q{<body id="world" class="hi">Hello world, again!</body>}, buffer
  end
end