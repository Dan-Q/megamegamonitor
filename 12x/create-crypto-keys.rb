#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
require './megamegamonitor'

PEPPER = 'THIS IS NOT THE REAL PEPPER FROM THE LIVE SYSTEM; ADD YOUR OWN HERE!'

do_all = true
if ARGV != ['all']
  puts "To add crypto keys to ALL subs, call: ./create-crypto-keys.rb all"
  do_all = false
end

SHORT_DELAY = 2

subs = Subreddit.where('monitor_contributors = ?', true).all
subs = subs.reject{|s| s.cryptokeys.any?} if !do_all
subs.each do |s|
  new_key = Digest::SHA256.hexdigest("#{s.name}#{Time::now}#{PEPPER}")
  puts " * #{s.display_name} (#{new_key})"
  s.cryptokeys.create(secret_key: new_key)
end
