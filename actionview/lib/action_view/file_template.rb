# frozen_string_literal: true

require "action_view/template"

module ActionView
  class FileTemplate < Template
    def initialize(filename, handler, details)
      source = ActionView::Template::Sources::File.new(filename)
      super(source, filename, handler, details)
    end
  end
end
