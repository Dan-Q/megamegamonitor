#!/usr/bin/env ruby
module SmarterReddMine
  SHORT_DELAY = 4
  LONG_DELAY = 10
  CONSECUTIVE_TIMEOUT_LIMIT = 10

  def get_my_subs(params = {})
    response = get "/subreddits/mine/contributor.json", params

    things = response[:data][:children].map! do |sub|
      object_from_body(kind: "t5", data: sub[:data])
    end
    other_values = response[:data].reject{|k,v| k == :children}
    { list: Redd::Object::Listing.new(data: {children: things}) }.merge(other_values)
  end

  def get_all_my_subs
    after = nil
    result = []
    consecutive_timeouts = 0
    loop do
      begin
        block = get_my_subs(limit: 100, after: after)
        result += block[:list].collect{|sub| { name: sub.id, display_name: sub[:display_name] } }
        print '<'
        break if (after = block[:after]).nil?
        consecutive_timeouts = 0
      rescue Redd::Error::ServiceUnavailable => e
        puts "\n#{e.inspect}"
        exit
      rescue Redd::Error::TimedOut
        print '?'
        consecutive_timeouts += 1
        exit if consecutive_timeouts > CONSECUTIVE_TIMEOUT_LIMIT
        sleep(LONG_DELAY)
      end
      sleep(SHORT_DELAY)
    end
    result
  end
end
Redd::Client::Authenticated.include(SmarterReddMine)
