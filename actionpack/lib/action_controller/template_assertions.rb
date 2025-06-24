# frozen_string_literal: true

# :markup: markdown

module ActionController
  module TemplateAssertions # :nodoc:
    def assert_template(options = {}, message = nil)
      raise NoMethodError,
        'assert_template has been extracted to a gem. To continue using it,
        add `gem "rails-controller-testing"` to your Gemfile.'
    end
  end
end
