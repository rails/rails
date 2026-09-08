# frozen_string_literal: true

require "rails/generators/erb"

module Erb # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      hide!

      def create_files
        template "app/views/passwords/new.html.erb"
        template "app/views/passwords/edit.html.erb"
        template "app/views/sessions/new.html.erb"
      end
    end
  end
end
