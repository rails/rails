module Rails
  module Generators
    class StylesheetsGenerator < Base
      def copy_stylesheets_file
        template "scaffold.css", "app/assets/stylesheets/scaffold.css" if behavior == :invoke
      end
    end
  end
end
