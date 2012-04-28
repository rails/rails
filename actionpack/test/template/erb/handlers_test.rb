require "abstract_unit"

class HandlersTest < ActiveSupport::TestCase
  HANDLER  = ActionView::Template::Handlers::ERB
  Template = Struct.new(:source)
  
  extend ActiveSupport::Testing::Declarative

  test "content is not trimmed without a trim mode" do
    with_erb_trim_mode nil do
      assert_equal("   \ntest", render(" <% 'IGNORED' %>  \ntest"))
    end
  end

  test "content around tags is trimmed if the trim mode includes a dash" do
    with_erb_trim_mode '-' do
      assert_equal("test", render(" <% 'IGNORED' %>  \ntest"))
    end
  end

  test "percent lines are normal content without a trim mode" do
    with_erb_trim_mode nil do
      assert_equal( "% if false\noops\n% end\n",
                    render("% if false\noops\n% end\n") )
    end
  end

  test "percent lines count as ruby if trim mode includes a percent" do
    with_erb_trim_mode "%" do
      assert_equal("", render("% if false\noops\n% end\n"))
    end
  end

  test "both trim modes can be used at the same time" do
    with_erb_trim_mode "%-" do
      assert_equal( "test", render( "% if false\noops\n% end\n" +
                                    " <% 'IGNORED' %>  \ntest" ) )
    end
  end

  private

  def with_erb_trim_mode(mode)
    @old_erb_trim_mode    = HANDLER.erb_trim_mode
    HANDLER.erb_trim_mode = mode
    yield
  ensure
    HANDLER.erb_trim_mode = @old_erb_trim_mode
  end

  def render(template)
    eval("output_buffer = nil; " + HANDLER.call(Template.new(template)))
  end
end
