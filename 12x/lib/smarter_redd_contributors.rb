#!/usr/bin/env ruby
module SmarterReddContributors
  def supersleep(delay)
    tf = Time::now + delay
    while tf > Time::now
      sleep(delay)
    end
  end

  SHORT_DELAY = 3
  LONG_DELAY = 10
  CONSECUTIVE_TIMEOUT_LIMIT = 10

  # Redd::Client::Authenticated::Subreddits#get_special_users is inadequate because it
  # doesn't make available the "other values" returned - 'after', 'before', etc., which
  # we need if we're going to paginate through the results. This simplified method
  # only gets 'contributors', because that's all we care about.
  def get_contributors(subreddit, params = {})
    name = extract_attribute(subreddit, :display_name)
    response = get "/r/#{name}/about/contributors.json", params

    things = response[:data][:children].map! do |user|
      object_from_body(kind: "t2", data: user)
    end
    other_values = response[:data].reject{|k,v| k == :children}
    { list: Redd::Object::Listing.new(data: {children: things}) }.merge(other_values)
  end

  # Iterates paginated calls to get_contributors, leaving a short delay (in seconds)
  # between each call, in order to get a full list of contributors to a specified subreddit
  # Returns an array of the usernames of all contributors.
  # Prints a . for each 'block' returned, for use in progress meters
  def get_all_contributors(subreddit, page_limit = 9999)
    after = nil
    page = 0
    result = []
    consecutive_timeouts = 0
    loop do
      begin
        block = get_contributors(subreddit, limit: 100, after: after)
        result += block[:list].collect{|u| { name: u.id, display_name: u[:name], date: DateTime.strptime(u.attributes[:date].to_i.to_s,'%s') } }
        print '<'
        page += 1
        break if (after = block[:after]).nil? || page >= page_limit
        consecutive_timeouts = 0
      rescue Redd::Error::ServiceUnavailable, Redd::Error::TimedOut => e
        print '?'
        consecutive_timeouts += 1
        raise e if consecutive_timeouts > CONSECUTIVE_TIMEOUT_LIMIT
        supersleep(LONG_DELAY)
      end
      supersleep(SHORT_DELAY)
    end
    supersleep(SHORT_DELAY)
    result
  end
end
Redd::Client::Authenticated.include(SmarterReddContributors)
