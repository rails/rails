# frozen_string_literal: true

module Rails
  module Generators
    class AssetsGenerator < NamedBase # :nodoc:
      class_option :javascripts, type: :boolean, desc: "Generate JavaScripts"
      class_option :stylesheets, type: :boolean, desc: "Generate Stylesheets"

      class_option :javascript_engine, desc: "Engine for JavaScripts"
      class_option :stylesheet_engine, desc: "Engine for Stylesheets"

      private
        def asset_name
          file_name
        end

        hook_for :javascript_engine do |javascript_engine|
          invoke javascript_engine, [name] if options[:javascripts]
        end

        hook_for :stylesheet_engine do |stylesheet_engine|
          invoke stylesheet_engine, [name] if options[:stylesheets]
        end
    end
  end
end
