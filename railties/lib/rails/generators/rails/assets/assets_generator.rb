module Rails
  module Generators
    class AssetsGenerator < NamedBase
      class_option :javascripts, :type => :boolean, :desc => "Generate JavaScripts"
      class_option :stylesheets, :type => :boolean, :desc => "Generate Stylesheets"

      class_option :javascript_engine, :desc => "Engine for JavaScripts"
      class_option :stylesheet_engine, :desc => "Engine for Stylesheets"

      def create_javascript_files
        return unless options.javascripts?
        copy_file "javascript.#{javascript_extension}",
          File.join('app/assets/javascripts', class_path, "#{asset_name}.#{javascript_extension}")
      end

      protected

      def asset_name
        file_name
      end

      def javascript_extension
        options.javascript_engine.present? ?
          "js.#{options.javascript_engine}" : "js"
      end

      hook_for :stylesheet_engine do |stylesheet_engine|
        invoke stylesheet_engine, [name] if options[:stylesheets]
      end
    end
  end
end
