#  class Notifier < ActionMailer::Base
#    delivers_from 'notifications@example.com'
#    
#    def welcome(user)
#      @user = user # available to the view
#      mail(:subject => 'Welcome!', :to => user.email_address)
#      # auto renders both welcome.text.erb and welcome.html.erb
#    end
#    
#    def goodbye(user)
#      headers["Reply-To"] = 'cancelations@example.com'
#      mail(:subject => 'Goodbye', :to => user.email_address) do |format|
#        format.html { render "shared_template "}
#        format.text # goodbye.text.erb
#      end
#    end
#    
#    def surprise(user, gift)
#      attachments[gift.name] = File.read(gift.path)
#      mail(:subject => 'Surprise!', :to => user.email_address) do |format|
#        format.html(:charset => "ascii")            # surprise.html.erb
#        format.text(:transfer_encoding => "base64") # surprise.text.erb
#      end
#    end
#    
#    def special_surprise(user, gift)
#      attachments[gift.name] = { :content_type => "application/x-gzip", :content => File.read(gift.path) }
#      mail(:to => 'special@example.com') # subject not required
#      # auto renders both special_surprise.text.erb and special_surprise.html.erb
#    end
#  end
#   
#  Notifier.welcome(user)         # => returns a Mail object
#  Notifier.welcome(user).deliver # => creates and sends the Mail in one step
class BaseTest < ActionMailer::Base
  
  
  
end
