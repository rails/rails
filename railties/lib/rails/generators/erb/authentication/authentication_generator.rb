# frozen_string_literal: true

require "rails/generators/erb"

module Erb # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      def create_files
        template "views/sessions/new.html.erb", File.join("app/views/sessions/new.html.erb")
      end
    end
  end
end
