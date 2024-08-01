class BroadcastJob < ApplicationJob
  def perform(file, message)
    File.write(file, <<~HTML)
      <turbo-stream action="replace" target="message_#{message.id}">
        <template>#{message.content}</template>
      </turbo-stream>
    HTML
  end
end
