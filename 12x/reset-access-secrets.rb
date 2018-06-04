#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
require './megamegamonitor'

do_all = true
if ARGV != ['all']
  puts "To reset ALL secrets, call: ./reset-access-secrets.rb all"
  do_all = false
end

SHORT_DELAY = 2

Account.all.each do |account|
  r = MegaMegaMonitor.connect(account)

  subs = account.subreddits
  subs = subs.where('access_secret IS NULL') if !do_all
  subs::all.each do |n|
    s = r.subreddit(n.display_name)
    print '.'
    n.access_secret = Digest::MD5.hexdigest(s.attributes[:created_utc].to_i.to_s)
    puts n.display_name if n.changed?
    n.save
    sleep(SHORT_DELAY)
  end
end

puts ' done'
