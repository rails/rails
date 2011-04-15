module Rails
  module Generators
    # TODO: Add hooks for using other asset pipelines, like Less
    class AssetsGenerator < NamedBase
      def create_asset_files
        copy_file "javascript.#{javascript_extension}",
          File.join('app/assets/javascripts', "#{file_name}.#{javascript_extension}")

        copy_file "stylesheet.#{stylesheet_extension}",
          File.join('app/assets/stylesheets', "#{file_name}.#{stylesheet_extension}")
      end
      
    private
      def javascript_extension
        using_coffee? ? "js.coffee" : "js"
      end
    
      def using_coffee?
        require 'coffee-script'
        defined?(CoffeeScript)
      rescue LoadError
        false
      end
      
      def stylesheet_extension
        using_sass? ? "css.scss" : "css"
      end
      
      def using_sass?
        require 'sass'
        defined?(Sass)
      rescue LoadError
        false
      end
    end
  end
end
