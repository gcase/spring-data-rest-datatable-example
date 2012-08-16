#!/usr/bin/env ruby

require "json"
require "net/http"

client = Net::HTTP.new("localhost", 8080)

File.open("names.txt").each_line do |name|
	name.chomp!
	email = name.downcase.split(' ').reverse.join('.') + '@example.com'
	client.post("/sdrdemo/rest/customer", JSON.dump({:name => name, :email => email}), {"Content-Type"=>"application/json"})
end

puts "All done!"

