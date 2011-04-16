module Rails
  module Generators
    class StylesheetsGenerator < Base
      def copy_stylesheets_file
        if behavior == :invoke
          template "scaffold.#{stylesheet_extension}", "app/assets/stylesheets/scaffold.#{stylesheet_extension}"
        end
      end

    private
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
