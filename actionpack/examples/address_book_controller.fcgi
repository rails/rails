#!/usr/local/bin/ruby

require "address_book_controller"
require "fcgi"

FCGI.each_cgi { |cgi| AddressBookController.process_cgi(cgi) }