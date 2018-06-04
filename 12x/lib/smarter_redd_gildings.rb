#!/usr/bin/env ruby
module SmarterReddGildings
  def supersleep(delay)
    tf = Time::now + delay
    while tf > Time::now
      sleep(delay)
    end
  end
  
  SHORT_DELAY = 4
  LONG_DELAY = 10
  CONSECUTIVE_TIMEOUT_LIMIT = 10

  def get_gildings(subreddits, params = {})
    response = get "/r/#{subreddits.join('+')}/gilded.json", params

    things = response[:data][:children].map do |child|
      if(child[:kind] == 't3') # post
        { kind: 't3', id: child[:data][:id], author: child[:data][:author], subreddit: child[:data][:subreddit], url: "http://www.reddit.com/#{child[:data][:id]}", created_utc: child[:data][:created_utc], gilded: child[:data][:gilded] }
      elsif(child[:kind] == 't1') # comment
        { kind: 't1', id: child[:data][:id], author: child[:data][:author], subreddit: child[:data][:subreddit], url: "http://www.reddit.com/#{child[:data][:link_id][3..-1]}##{child[:data][:id]}", created_utc: child[:data][:created_utc], gilded: child[:data][:gilded] }
      end
    end
    other_values = response[:data].reject{|k,v| k == :children}
    { list: things }.merge(other_values)
  end

  def get_all_gildings(subreddits, page_limit: nil, until_kind: nil, until_name: nil)
    after, pages = nil, 0
    result = []
    consecutive_timeouts = 0
    loop do
      begin
        block = get_gildings(subreddits, limit: 100, after: after)
        result += block[:list]
        print '<'
        break if (after = block[:after]).nil? # break if run out of content
        break if (until_kind && until_name) && block[:list].any?{|t| t[:kind] == until_kind && t[:id] == until_name } # break if found "until_name"
        pages += 1
        break if page_limit && (pages >= page_limit) # break if beyond page limit
        consecutive_timeouts = 0
      rescue Redd::Error::ServiceUnavailable => e
        puts "\n#{e.inspect}"
        exit
      rescue Redd::Error::TimedOut
        print '?'
        consecutive_timeouts += 1
        exit if consecutive_timeouts > CONSECUTIVE_TIMEOUT_LIMIT
        supersleep(LONG_DELAY)
      end
      supersleep(SHORT_DELAY)
    end
    supersleep(SHORT_DELAY)
    result
  end
end
Redd::Client::Authenticated.include(SmarterReddGildings)
