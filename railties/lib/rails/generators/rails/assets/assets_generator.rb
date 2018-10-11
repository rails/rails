# frozen_string_literal: true

module Rails
  module Generators
    class AssetsGenerator < NamedBase # :nodoc:
      class_option :stylesheets, type: :boolean, desc: "Generate Stylesheets"
      class_option :stylesheet_engine, desc: "Engine for Stylesheets"

      private
        def asset_name
          file_name
        end

        hook_for :stylesheet_engine do |stylesheet_engine|
          invoke stylesheet_engine, [name] if options[:stylesheets]
        end
    end
  end
end
