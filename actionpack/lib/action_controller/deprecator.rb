# frozen_string_literal: true

# :markup: markdown

module ActionController
  def self.deprecator # :nodoc:
    AbstractController.deprecator
  end
end
