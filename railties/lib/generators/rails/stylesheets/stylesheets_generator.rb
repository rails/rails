module Rails
  module Generators
    class StylesheetsGenerator < Base
      def copy_stylesheets_file
        template "scaffold.css", "public/stylesheets/scaffold.css" if behavior == :invoke
      end
    end
  end
end
