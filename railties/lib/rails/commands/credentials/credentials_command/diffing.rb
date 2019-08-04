# frozen_string_literal: true

module Rails::Command::CredentialsCommand::Diffing # :nodoc:
  def enroll_project_in_credentials_diffing
    if enrolled?
      true
    else
      gitattributes.write(<<~end_of_template, mode: "a")
        config/credentials/*.yml.enc diff=rails_credentials
        config/credentials.yml.enc diff=rails_credentials
      end_of_template

      say "Project successfully enrolled!"
      say "Rails ensures the rails_credentials diff driver is set when running `credentials:edit`. See `credentials:help` for more."
    end
  end

  def ensure_rails_credentials_driver_is_set
    set_driver if enrolled? && !driver_configured?
  end

  private
    def enrolled?
      gitattributes.read.match?(/config\/credentials(\/\*)?\.yml\.enc diff=rails_credentials/)
    rescue Errno::ENOENT
      false
    end

    def driver_configured?
      system "git config --get diff.rails_credentials.textconv", out: File::NULL
    end

    def set_driver
      puts "running"
      system "git config diff.rails_credentials.textconv 'bin/rails credentials:diff'"
    end

    def gitattributes
      Rails.root.join(".gitattributes")
    end
end
