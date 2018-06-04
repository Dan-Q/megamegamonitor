#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
#!/usr/bin/env ruby
require './megamegamonitor'

INTERVAL = '1 WEEK' # how long ago to look back when saying who's "new" to each level

filename = "ladder/#{Date::today}.html"
puts "Generating #{filename}..."

result = ActiveRecord::Base.connection.execute <<-END_OF_SQL
SELECT
  subreddits.id AS id,
  IF(   subreddits.override_display_name IS NOT NULL
  OR subreddits.chain_number > 26,
  IF(subreddits.override_display_name IS NOT NULL,
     subreddits.override_display_name,
     CONCAT('Gilded &times;', subreddits.chain_number + 1)
  ),
  subreddits.display_name) AS name,
  (SELECT COUNT(*) FROM contributors WHERE contributors.subreddit_id = subreddits.id) AS contributors,
  (SELECT COUNT(*) FROM contributors WHERE contributors.subreddit_id = subreddits.id AND contributors.created_at > DATE_SUB(curdate(), INTERVAL #{INTERVAL})) AS new_contributors,
  (SELECT users.display_name FROM contributors LEFT JOIN users ON contributors.user_id = users.id WHERE contributors.subreddit_id = subreddits.id AND contributors.created_at > DATE_SUB(curdate(), INTERVAL #{INTERVAL}) ORDER BY RAND() LIMIT 1) AS sample_new_contributor,
  subreddits.chain_number as chain_number

FROM subreddits

WHERE subreddits.chain_number IS NOT NULL
ORDER BY subreddits.chain_number DESC

END_OF_SQL

File::open(filename, 'w') do |f|
  f.puts <<-EOH
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>MegaLounge Ladder for #{Date.today}</title>
        <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" />
        <script type="text/javascript" src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
        <style type="text/css">
          body {
            margin-top: 15px;
          }
          .sub, .step {
            width: 300px;
            text-align: center;
          }
          .sub {
          }
          .sub .name {
            font-weight: bold;
          }
          .sub .members {
            text-style: italic;
          }
          .step {
            position: relative;
            height: 60px;
            margin: 25px 0 15px;
          }
          .step .glyphicon, .step .climbers {
            position: absolute;
            width: 100%;
            height: 100%;
            top: 0;
            left: 0;
          }
          .step .climbers {
            text-align: center;
            padding-top: 20px;
          }
          .step .glyphicon {
            font-size: 50px;
            color: transparent;
            text-shadow: 0 0 5px rgba(0,0,0,0.2);
          }
          .step .climbers {
            z-index: 10;
          }
          .step.0-climbers .climbers {
            display: none;
          }
          .sub-chain-37 {
            background-color: #9ff;
          }
        </style>
      </head>
      <body>
        <div class="container-fluid">
  EOH
  result.each do |row|
    f.puts <<-EOH
      <div class="sub sub-#{row[0]} sub-chain-#{row[5]} well" style="height: #{(row[2] / 3) + 82}px;">
        <p class="name">#{row[1]}</p>
        <p calss="members">#{row[2].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} members</p>
      </div>
      <div class="step #{row[3]}-climbers step-to-#{row[5]}">
        <span class="glyphicon glyphicon-arrow-up" aria-hidden="true"></span>
        <p class="climbers">
          #{row[3]} climber#{'s' if row[3] != 1}
          <span class="identity">
            #{"(including <strong>#{row[4]}</strong>)" if row[3] > 1}
            #{"(<strong>#{row[4]}</strong>)" if row[3] == 1}
          </span>
        </p>
      </div>
    EOH
  end
  f.puts <<-EOH
        </div>
      </body>
    </html>
  EOH
end
