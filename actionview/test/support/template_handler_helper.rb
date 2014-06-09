module TemplateHandlerHelper
  def with_template_handler(*extensions, handler)
    ActionView::Template.register_template_handler(*extensions, handler)
    yield
  ensure
    ActionView::Template.unregister_template_handler(*extensions)
  end
end
