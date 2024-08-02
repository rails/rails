# frozen_string_literal: true

require "rails/generators/erb"

module Erb # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      def create_files
        template "views/passwords/new.html.erb", File.join("app/views/passwords/new.html.erb")
        template "views/passwords/edit.html.erb", File.join("app/views/passwords/edit.html.erb")
        template "views/sessions/new.html.erb", File.join("app/views/sessions/new.html.erb")
      end
    end
  end
end
