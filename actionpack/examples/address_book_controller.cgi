#!/usr/local/bin/ruby

require "address_book_controller"

begin
  AddressBookController.process_cgi(CGI.new)
rescue Exception => e
  CGI.new.out { e.message }
end 