module Rails
  module Generators
    class StylesheetsGenerator < Base
      def copy_stylesheets_file
        copy_file "scaffold.css", "public/stylesheets/scaffold.css"
      end
    end
  end
end
