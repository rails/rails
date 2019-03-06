# frozen_string_literal: true

require "rails/code_statistics"

class Rails::Conductor::StatisticsController < Rails::Conductor::BaseController
  def show
    @statistics = compute_statistics
  end

  private
    def compute_statistics
      capture_stdout { CodeStatistics.new(*statistics_directories).to_s }
    end

    def capture_stdout
      original_stdout, $stdout = $stdout, StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    def statistics_directories
      [
        %w(Controllers        app/controllers),
        %w(Helpers            app/helpers),
        %w(Jobs               app/jobs),
        %w(Models             app/models),
        %w(Mailers            app/mailers),
        %w(Mailboxes          app/mailboxes),
        %w(Channels           app/channels),
        %w(JavaScripts        app/assets/javascripts),
        %w(JavaScript         app/javascript),
        %w(Libraries          lib/),
        %w(APIs               app/apis),
        %w(Controller\ tests  test/controllers),
        %w(Helper\ tests      test/helpers),
        %w(Model\ tests       test/models),
        %w(Mailer\ tests      test/mailers),
        %w(Mailbox\ tests     test/mailboxes),
        %w(Channel\ tests     test/channels),
        %w(Job\ tests         test/jobs),
        %w(Integration\ tests test/integration),
        %w(System\ tests      test/system),
      ].collect do |name, dir|
        [ name, Rails.root.join(dir) ]
      end.select { |name, dir| File.directory?(dir) }
    end
end
