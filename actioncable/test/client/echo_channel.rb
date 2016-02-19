class EchoChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "global"
  end

  def unsubscribed
    'Goodbye from EchoChannel!'
  end

  def ding(data)
    transmit(dong: data['message'])
  end

  def delay(data)
    sleep 1
    transmit(dong: data['message'])
  end

  def bulk(data)
    ActionCable.server.broadcast "global", wide: data['message']
  end
end
