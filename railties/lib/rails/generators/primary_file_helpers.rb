# frozen_string_literal: true

require "active_support/concern"

module Rails
  module Generators
    module PrimaryFileHelpers # :nodoc:
      extend ActiveSupport::Concern

      included do
        class_option :editor, type: :string, aliases: "-e", lazy_default: ENV["EDITOR"],
                              required: false, banner: "editor",
                              desc: "Open generated primary file in the specified editor (Default: $EDITOR)"
      end

      private
        def primary_file(filename)
          open_file_in_editor(filename) if primary_file? && options[:editor].present?
        end

        def primary_file?
          self.instance_of?(shell.base.class)
        end
    end
  end
end
