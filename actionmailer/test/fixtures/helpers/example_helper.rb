module ExampleHelper
  def example_format(text)
    "<em><strong><small>#{h(text)}</small></strong></em>".html_safe!
  end
end
