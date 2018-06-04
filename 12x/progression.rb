#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
require './megamegamonitor'

# Command-line parameters
raise 'Need to specify a username on the command line e.g. ./progression.rb avapoet' if (username = ARGV[0]).blank?
raise "User #{username} not found" unless user = User::find_by_display_name(username)
filename = "progression/#{username}-timeline.html"
puts "Generating #{filename}..."

progression = user.contributors.includes(:subreddit).where('subreddits.chain_number IS NOT NULL').references(:subreddits).order('subreddits.chain_number').all
timeline_colors = progression.reverse.collect do |c|
  if(c.subreddit.chain_number <= 10)
    # MegaLounge through MegaLoungeX
    '#002d2a'
  elsif(c.subreddit.chain_number <= 16)
    # Gems
    '#570493'
  elsif(c.subreddit.chain_number <= 25)
    # solar system
    '#508682'
  elsif(c.subreddit.chain_number == 26)
    # the secret megalounge
    '#ffce00'
  else
    '#073a91'
  end
end

File::open(filename, 'w') do |f|
  f.puts <<-EOF
    <html>
      <head>
        <script type="text/javascript" src="https://www.google.com/jsapi"></script>
        <script type="text/javascript">
          google.load("visualization", "1", {packages:["timeline"]});
          google.setOnLoadCallback(drawCharts);

          function drawCharts(){
            // Timeline
            var container = document.getElementById('timeline');
            var chart = new google.visualization.Timeline(container);
            var dataTable = new google.visualization.DataTable();
            dataTable.addColumn({ type: 'string', id: 'MegaLounge' });
            dataTable.addColumn({ type: 'date', id: 'Start' });
            dataTable.addColumn({ type: 'date', id: 'End' });
            dataTable.addRows([
  EOF
  first_row = true
  progression.reverse.each_with_index do |c, i|
    date = c.date
    sub_name = c.subreddit.override_display_name || c.subreddit.display_name
    sub_name = "Gilded x#{c.subreddit.chain_number + 1}" if c.subreddit.chain_number > 26 # hide names above the secret MegaLounge
    if first_row
      f.print "#{' '*14}[ '#{sub_name}', new Date(#{date.year}, #{date.month - 1}, #{date.day}), new Date(Date.now()) ]"
      first_row = false
    else
      next_date = progression.reverse[i - 1].date
      f.print ",\n#{' '*14}[ '#{sub_name}', new Date(#{date.year}, #{date.month - 1}, #{date.day}), new Date(#{next_date.year}, #{next_date.month - 1}, #{next_date.day}) ]"
    end
  end
  f.puts <<-EOF
            ]);
            chart.draw(dataTable, { colors: [#{timeline_colors.collect{|hex|"'#{hex}'"}.join(', ')}] });
          }
        </script>
      </head>
      <body>
        <div id="timeline" style="width: 100%; height: 100%;"></div>
      </body>
    </html>
  EOF
end
