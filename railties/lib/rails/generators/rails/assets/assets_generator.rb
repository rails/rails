module Rails
  module Generators
    class AssetsGenerator < NamedBase
      class_option :javascripts, :type => :boolean, :desc => "Generate javascripts"
      class_option :stylesheets, :type => :boolean, :desc => "Generate stylesheets"

      class_option :javascript_engine, :desc => "Engine for javascripts"
      class_option :stylesheet_engine, :desc => "Engine for stylesheets"

      def create_javascript_files
        return unless options.javascripts?
        copy_file "javascript.#{javascript_extension}",
          File.join('app/assets/javascripts', class_path, "#{asset_name}.#{javascript_extension}")
      end

      def create_stylesheet_files
        return unless options.stylesheets?
        copy_file "stylesheet.#{stylesheet_extension}",
          File.join('app/assets/stylesheets', class_path, "#{asset_name}.#{stylesheet_extension}")
      end

      protected

      def asset_name
        file_name
      end

      def javascript_extension
        options.javascript_engine.present? ?
          "js.#{options.javascript_engine}" : "js"
      end

      def stylesheet_extension
        options.stylesheet_engine.present? ?
          "css.#{options.stylesheet_engine}" : "css"
      end
    end
  end
end
