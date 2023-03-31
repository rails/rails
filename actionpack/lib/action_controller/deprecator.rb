# frozen_string_literal: true

module ActionController
  def self.deprecator # :nodoc:
    AbstractController.deprecator
  end
end
