# frozen_string_literal: true

require "active_support/concern"

module ActionTextIntegrationTestHelper
  extend ActiveSupport::Concern

  included do
    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/actiontext/test/fixtures/files"

    setup :action_text_setup

    teardown :teardown_app
  end

  def action_text_setup
    build_app

    rails %w(generate scaffold Message subject:string content:rich_text body:rich_text)
    rails %w(g migration CreatePeople name:string)

    rails %w(g scaffold admin/messages --model-name=Message)

    rails "active_storage:install"
    rails "importmap:install"
    rails "action_text:install"
    rails "db:migrate"

    app_file "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
        resources :messages

        namespace :admin do
          resources :messages, only: [:show]
        end
      end
    RUBY

    content = File.read("#{app_path}/app/controllers/messages_controller.rb")
    content.sub!(
      "class MessagesController < ApplicationController",
      <<~RUBY
        class MessagesController < ActionController::Base
          # This class intentionally does not extend ApplicationController, so the
          # layout must be set manually. See commit 614e813 for details
          layout "application"
      RUBY
    )
    File.write("#{app_path}/app/controllers/messages_controller.rb", content)

    app_file "app/views/messages/_form.html.erb", <<~ERB
      <%= form_with(model: message) do |form| %>
        <% if message.errors.any? %>
          <div id="error_explanation">
            <h2><%= pluralize(message.errors.count, "error") %> prohibited this message from being saved:</h2>

            <ul>
            <% message.errors.full_messages.each do |message| %>
              <li><%= message %></li>
            <% end %>
            </ul>
          </div>
        <% end %>

        <div class="field">
          <%= form.label :subject %>
          <%= form.text_field :subject %>
        </div>

        <div class="field">
          <%= form.label :content, "Message content label" %>
          <%= form.rich_textarea :content, class: "trix-content",
                placeholder: "Your message here", aria: { label: "Message content aria-label" } %>
        </div>

        <div class="actions">
          <%= form.submit %>
        </div>
      <% end %>
    ERB

    app_file "app/views/messages/edit.json.erb", <<~ERB
      {
        "id": <%= @message.id %>,
        "form": "<%= j render partial: "form", formats: :html, locals: { message: @message } %>"
      }
    ERB

    app_file "app/views/messages/show.html.erb", <<~ERB
      <p id="notice"><%= notice %></p>

      <h1 id="subject"><%= @message.subject %></h1>

      <div id="content"><%= @message.content %></div>

      <%= link_to 'Edit', edit_message_path(@message) %> |
      <%= link_to 'Back', messages_path %>
    ERB

    app_file "app/views/messages/show.json.erb", <<~ERB
      {
        "id": <%= @message.id %>,
        "subject": "<%= j @message.subject %>",
        "content": "<%= j @message.content %>"
      }
    ERB

    app_file "app/views/admin/messages/show.html.erb", <<~ERB
      <dl>
        <dt>Subject</dt>
        <dd>
          <span id="subject"><%= @message.subject %></span>
        </dd>

        <dt>Content (Plain Text)</dt>
        <dd>
          <pre id="content-plain"><%= @message.content.to_plain_text %></pre>
        </dd>

        <dt>Content (HTML)</dt>
        <dd>
          <div id="content-html"><%= @message.content %></div>
        </dd>
      </dl>
    ERB

    app_file "app/views/people/_attachable.html.erb", <<~ERB
      <span class="mentioned-person"><%= person.name %></span>
    ERB

    app_file "app/views/people/_missing_attachable.html.erb", <<~ERB
      <span class="missing-attachable">Missing person</span>
    ERB

    app_file "app/views/people/_trix_content_attachment.html.erb", <<~ERB
      <span class="mentionable-person" gid="<%= person.to_gid %>">
        <%= person.name %>
      </span>
    ERB

    app_file "app/jobs/broadcast_job.rb", <<~RUBY
      class BroadcastJob < ActiveJob::Base
        def perform(file, message)
          File.write(file, <<~HTML)
            <turbo-stream action="replace" target="message_\#{message.id}">
              <template>\#{message.content}</template>
            </turbo-stream>
          HTML
        end
      end
    RUBY

    app_file "app/models/message.rb", <<~RUBY
      class Message < ApplicationRecord
        has_rich_text :content
        has_rich_text :body

        has_one :review
        accepts_nested_attributes_for :review
      end
    RUBY

    app_file "app/models/person.rb", <<~RUBY
      class Person < ApplicationRecord
        include ActionText::Attachable

        def self.to_missing_attachable_partial_path
          "people/missing_attachable"
        end

        def to_trix_content_attachment_partial_path
          "people/trix_content_attachment"
        end

        def to_attachable_partial_path
          "people/attachable"
        end
      end
    RUBY

    app_file "app/mailers/messages_mailer.rb", <<~RUBY
      class MessagesMailer < ApplicationMailer
        def notification
          @message = params[:message]
          mail to: params[:recipient], subject: "NEW MESSAGE: \#{@message.subject}"
        end
      end
    RUBY

    app_file "app/views/messages_mailer/notification.html.erb", <<~ERB
      <div id="message-content"><%= @message.content %></div>
    ERB

    app_file "test/application_system_test_case.rb", <<~RUBY
      require "test_helper"
      require "socket"

      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        options = {
          browser: ENV["SELENIUM_DRIVER_URL"].blank? ? :chrome : :remote,
          url: ENV["SELENIUM_DRIVER_URL"].blank? ? nil : ENV["SELENIUM_DRIVER_URL"]
        }
        driven_by :selenium, using: :headless_chrome, options: options
      end

      Capybara.server = :puma, { Silent: true }
      Capybara.server_host = "0.0.0.0"
      Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}" if ENV["SELENIUM_DRIVER_URL"].present?
    RUBY

    FileUtils.cp_r "#{RAILS_FRAMEWORK_ROOT}/actiontext/test/fixtures/files", "#{app_path}/test/fixtures"
  end

  private
    def create_file_blob(filename:, content_type:, metadata: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata
    end

    def assert_successful_test_run(name)
      result = run_test_file(name)
      assert_equal 0, $?.to_i, result
      result
    end

    def run_test_file(name)
      rails "test", "#{app_path}/test/#{name}", allow_failure: true
    end
end

ActiveSupport::TestCase.include(ActionTextIntegrationTestHelper)
