# frozen_string_literal: true

module Rails::Command::CredentialsCommand::Diffing # :nodoc:
  class Error < StandardError; end

  def enable_diffing
    if enabled?
      say "Already enabled!"
    else
      enable
      say "Diffing enabled! Editing a credentials file will display a diff of what actually changed."
    end
  rescue Error
    say "Couldn't setup Git to enable credentials diffing."
  end

  private
    def enabled?
      system "git config --get diff.rails_credentials.textconv", out: File::NULL
    end

    def enable
      raise Error unless system("git config diff.rails_credentials.textconv 'bin/rails credentials:diff'")

      Rails.root.join(".gitattributes").write(<<~end_of_template, mode: "a")
        config/credentials/*.yml.enc diff=rails_credentials
        config/credentials.yml.enc diff=rails_credentials
      end_of_template
    end
end
