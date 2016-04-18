module ActionController
  module TemplateAssertions
    def assert_template(options = {}, message = nil)
      raise NoMethodError,
        "assert_template has been extracted to a gem. To continue using it,
        add `gem 'rails-controller-testing'` to your Gemfile."
    end
  end
end
