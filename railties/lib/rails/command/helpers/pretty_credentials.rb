# frozen_string_literal: true

require "fileutils"

module Rails
  module Command
    module Helpers
      module PrettyCredentials
        Error = Class.new(StandardError)

        def opt_in_pretty_credentials
          unless already_answered? || already_opted_in?
            answer = yes?("Would you like to make the credentials diff from git more readable in the future? [Y/n]")
          end

          opt_in! if answer
          FileUtils.touch(tracker) unless answer.nil?
        rescue Error
          say("Couldn't setup git to prettify the credentials diff")
        end

        private
          def already_answered?
            tracker.exist?
          end

          def already_opted_in?
            system_call("git config --get 'diff.rails_credentials.textconv'", accepted_codes: [0, 1])
          end

          def opt_in!
            system_call("git config diff.rails_credentials.textconv 'bin/rails credentials:show'", accepted_codes: [0])

            git_attributes = Rails.root.join(".gitattributes")
            File.open(git_attributes, "a+") do |file|
              file.write(<<~EOM)
                config/credentials/*.yml.enc diff=rails_credentials
                config/credentials.yml.enc diff=rails_credentials
              EOM
            end
          end

          def tracker
            Rails.root.join("tmp", "rails_pretty_credentials")
          end

          def system_call(command_line, accepted_codes:)
            result = system(command_line)
            raise(Error) if accepted_codes.exclude?($?.exitstatus)
            result
          end
      end
    end
  end
end
