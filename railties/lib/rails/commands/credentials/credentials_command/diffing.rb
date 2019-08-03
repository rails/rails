# frozen_string_literal: true

module Rails::Command::CredentialsCommand::Diffing # :nodoc:
  class Error < StandardError; end

  def enable_credentials_diffing
    unless already_answered? || enabled?
      answer = yes?("Would you like to make the credentials diff from git more readable in the future? [Y/n]")
    end

    enable if answer
    FileUtils.touch(tracker) unless answer.nil?
  rescue Error
    say "Couldn't setup git to enable credentials diffing"
  end

  private
    def already_answered?
      tracker.exist?
    end

    def enabled?
      system_call("git config --get 'diff.rails_credentials.textconv'", accepted_codes: [0, 1])
    end

    def enable
      system_call("git config diff.rails_credentials.textconv 'bin/rails credentials:diff'", accepted_codes: [0])

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
