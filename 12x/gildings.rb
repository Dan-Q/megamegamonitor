#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
#!/usr/bin/env ruby
require './megamegamonitor'

# MegaLounge chain
SUPPRESS_USERS = %w{Nevare88 AuroraAustralis CBSAclerk}
filename = "megalounge-chain-#{Digest::MD5.hexdigest('e09587nved-megalounge-chain')}.html"
puts "Generating #{filename}..."
subs = Subreddit::where('display_name = ? OR chain_number IS NOT NULL', 'lounge').order('chain_number').all
output = {}
(subs.length - 1).times do |i|
  this_sub, next_sub = subs[i], subs[i+1]
  result = ActiveRecord::Base.connection.execute <<-END_OF_SQL
       SELECT users.display_name AS user,
              gildings.url,
              gildings.gilded
         FROM users
    LEFT JOIN gildings ON users.id = gildings.user_id
        WHERE gildings.subreddit_id = #{this_sub.id}
          AND users.id NOT IN (SELECT user_id FROM contributors WHERE subreddit_id=#{next_sub.id})
  END_OF_SQL
  result.each do |row|
    output[this_sub.display_name] ||= { from: this_sub.display_name, to: next_sub.display_name, data: {} }
    output[this_sub.display_name][:data][row[0]] ||= []
    output[this_sub.display_name][:data][row[0]] << { url: row[1], gilded: row[2] }
  end
end
this_sub = subs.last
result = ActiveRecord::Base.connection.execute <<-END_OF_SQL
     SELECT users.display_name AS user,
            gildings.url,
            gildings.gilded
       FROM users
  LEFT JOIN gildings ON users.id = gildings.user_id
      WHERE gildings.subreddit_id = #{this_sub.id}
END_OF_SQL
result.each do |row|
output[this_sub.display_name] ||= { from: this_sub.display_name, to: '...', data: {} }
  output[this_sub.display_name][:data][row[0]] ||= []
output[this_sub.display_name][:data][row[0]] << { url: row[1], gilded: row[2] }
end
File::open(filename, 'w') do |f|
  f.puts <<-EOH
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>MegaLounge Chain Promotions</title>
        <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" />
        <script type="text/javascript" src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
      </head>
      <body>
        <p><em>Last updated: #{Time::now}</em></p>
        <p>The following users are eligible for consideration for promotion to the next level of the MegaLounge chain for being gilded in the previous level:</p>
        <table class="table table-striped">
          <thead>
            <tr>
              <th>User</th>
              <th>From</th>
              <th>To</th>
              <th>For</th>
            </tr>
          </thead>
        <tbody>
  EOH
  output.each do |from, lvl|
    lvl[:data].each do |user, gs|
      # check that this user is still a part of the level they're being promoted FROM, or else suppress them as a self-remover
      result = ActiveRecord::Base.connection.execute <<-END_OF_SQL
            SELECT COUNT(contributors.id)
              FROM contributors
         LEFT JOIN users      ON contributors.user_id = users.id
         LEFT JOIN subreddits ON contributors.subreddit_id = subreddits.id
             WHERE users.display_name = '#{user}'
               AND subreddits.display_name = '#{lvl[:from]}'
      END_OF_SQL
      if (!SUPPRESS_USERS.include?(user)) && ((result.first[0] == 1) || (lvl[:from] == 'lounge'))
        f.puts <<-EOH
          <tr>
            <td><a href="https://www.reddit.com/u/#{user}/gilded">#{user}</a></td>
            <td><a href="https://www.reddit.com/r/#{lvl[:from]}">/r/#{lvl[:from]}</a></td>
            <td><a href="https://www.reddit.com/r/#{lvl[:to]}">/r/#{lvl[:to]}</a></td>
            <td><ul>
        EOH
        gs.each do |g|
          f.puts <<-EOH
            <li>
            <a href="#{g[:url]}">#{g[:url]}</a>
             #{"&times; #{g[:gilded]}" if(g[:gilded] > 1)}
            </li>
          EOH
        end
        f.puts <<-EOH
          </ul></td>
          </tr>
        EOH
      end
    end
  end
  f.puts <<-EOH
          </tbody>
        </table>
        <p><small>The following users were excluded from the output: #{SUPPRESS_USERS.join(', ')}, and anybody who has removed themselves from the MegaLounge in which they were gilded.</small></p>
      </body>
    </html>
  EOH
end

# MegaEarth
filename = "megaearth-promotions-#{Digest::MD5.hexdigest('e09587nved-megaearth')}.html"
puts "Generating #{filename}..."
result = ActiveRecord::Base.connection.execute <<-END_OF_SQL
     SELECT users.display_name AS user,
            subreddits.display_name AS subreddit,
            SUM(gildings.gilded) AS gildings,
            subreddits.chain_number AS chain_number
       FROM users
  LEFT JOIN gildings ON users.id = gildings.user_id
  LEFT JOIN subreddits ON gildings.subreddit_id = subreddits.id
      WHERE users.id NOT IN (SELECT user_id FROM contributors WHERE subreddit_id=#{Subreddit::find_by_display_name('megaearth').id})
        AND subreddits.chain_number IS NOT NULL
   GROUP BY users.display_name, subreddits.display_name HAVING SUM(gildings.gilded) >= 3 ORDER BY users.display_name, SUM(gildings.gilded) DESC;
END_OF_SQL
File::open(filename, 'w') do |f|
  f.puts <<-EOH
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>MegaEarth Promotions</title>
        <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" />
        <script type="text/javascript" src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
      </head>
      <body>
        <p><em>Last updated: #{Time::now}</em></p>
        <p>The following users are eligible for <em>consideration</em> for invitation to <a href="https://www.reddit.com/r/megaearth">/r/MegaEarth</a> for being thrice gilded in the following chain MegaLounges:</p>
        <table class="table table-striped">
          <thead>
            <tr>
              <th>User</th>
              <th>Subreddit</th>
              <th>Times gilded</th>
            </tr>
          </thead>
          <tbody>
  EOH
  result.each do |row|
    if (row[3] >= 26)
      name, link = "MegaLounge &times;#{row[3]}", false
    else
      name, link = row[1], true
    end
    f.puts <<-EOH
      <tr>
        <td><a href="https://www.reddit.com/u/#{row[0]}/gilded">#{row[0]}</a></td>
        <td>#{link ? "<a href=\"https://www.reddit.com/r/#{name}\">#{name}</a>" : name}</td>
        <td>#{row[2]}</td>
      </tr>
    EOH
  end
  f.puts <<-EOH
    </tbody></table></body></html>
  EOH
end
