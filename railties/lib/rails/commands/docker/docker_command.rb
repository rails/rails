# frozen_string_literal: true

require "rails/dockerfile_helpers"

module Rails
  module Command
    class DockerCommand < Base # :nodoc:
      desc "render", "Render Dockerfile template to Dockerfile"
      option :template, banner: "PATH", type: :string, default: "config/Dockerfile.erb",
        desc: "The template to render (path relative to app root)."
      option :dockerfile, banner: "PATH", type: :string, default: "Dockerfile",
        desc: "The output file (path relative to app root)."
      option :environments, banner: "LIST", aliases: "-e", type: :string, default: "production,test",
        desc: "Comma-separated list of RAILS_ENV values to support with the Dockerfile."
      def render
        ENV["RAILS_GROUPS"] = options[:environments]
        ENV["RAILS_ENV"] = options[:environments][/[^,]+/]
        require_application!

        result = Object.new.extend(DockerfileHelpers).render(options[:template])
        result.prepend("# syntax = docker/dockerfile:1\n\n") unless result.start_with?("# syntax = ")
        result.sub!(/\A# syntax.+\n/) { |directive| "#{directive}\n#{this_file_was_rendered_message}" }

        Rails.root.join(options[:dockerfile]).write(result)
      end

      private
        def this_file_was_rendered_message
          render_command = executable(:render).dup
          [:template, :dockerfile, :environments].each do |option|
            render_command << " --#{option}=#{options[option]}" if nondefault?(option)
          end

          <<~MESSAGE
            ########################################################################
            # This file was rendered from `#{options[:template]}`.
            #
            # Instead of editing this file, edit `#{options[:template]}`, then run
            # `#{render_command}`.
            ########################################################################
          MESSAGE
        end

        def nondefault?(option)
          options[option] != self.class.commands[current_subcommand].options[option].default
        end
    end
  end
end
