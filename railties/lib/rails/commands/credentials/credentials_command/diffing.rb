# frozen_string_literal: true

module Rails::Command::CredentialsCommand::Diffing # :nodoc:
  GITATTRIBUTES_ENTRY = <<~END
    config/credentials/*.yml.enc diff=rails_credentials
    config/credentials.yml.enc diff=rails_credentials
  END

  def enroll_project_in_credentials_diffing
    if enrolled_in_credentials_diffing?
      say "Project is already enrolled in credentials file diffing."
    else
      gitattributes.write(GITATTRIBUTES_ENTRY, mode: "a")

      say "Enrolled project in credentials file diffing!"
      say ""
      say "Rails will configure the Git diff driver for credentials when running `#{executable(:edit)}`. See `#{executable(:help)}` for more information."
    end
  end

  def disenroll_project_from_credentials_diffing
    if enrolled_in_credentials_diffing?
      gitattributes.write(gitattributes.read.gsub(GITATTRIBUTES_ENTRY, ""))
      gitattributes.delete if gitattributes.empty?

      say "Disenrolled project from credentials file diffing!"
    else
      say "Project is not enrolled in credentials file diffing."
    end
  end

  def ensure_diffing_driver_is_configured
    configure_diffing_driver if enrolled_in_credentials_diffing? && !diffing_driver_configured?
  end

  private
    def enrolled_in_credentials_diffing?
      gitattributes.file? && gitattributes.read.include?(GITATTRIBUTES_ENTRY)
    end

    def diffing_driver_configured?
      system "git config --get diff.rails_credentials.textconv", out: File::NULL
    end

    def configure_diffing_driver
      system "git config diff.rails_credentials.textconv '#{executable(:diff)}'"
      say "Configured Git diff driver for credentials."
    end

    def gitattributes
      @gitattributes ||= (Rails::Command.root || Pathname.pwd).join(".gitattributes")
    end
end
