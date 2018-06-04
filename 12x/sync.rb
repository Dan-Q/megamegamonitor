#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
#!/usr/bin/env ruby
require './megamegamonitor'
require 'fileutils'

# Constants
VERSION                                = File::read('VERSION').to_i
UPDATE_SUBREDDIT_LIST_FREQUENCY        = 60 * 60 * 3 # 3 hours
UPDATE_SUBREDDIT_CONTRIBUTOR_FREQUENCY = 60 * 60 * 3 # 3 hours
UPDATE_SUBREDDIT_GILDINGS_FREQUENCY    = 60 * 60 * 3 # 3 hours
OUTPUT_DIR                             = 'output2'
NINJA_SUB_ID                           = 81
NINJA_SPRITE_ID                        = 71
PIRATE_SUB_ID                          = 99999999999 # TODO
PIRATE_SPRITE_ID                       = 72
SHORT_DELAY = 4
LONG_DELAY = 10

CONNECT_TO_REDDIT                      = true 

requested_permutations                 = ARGV.empty? ? nil : ARGV

puts '-'*80
puts "Starting sync. I am process #{Process.pid}."
puts Time::now

if !requested_permutations
  if File::exists?('sync.lock')
    puts 'Lockfile exists. Exiting.'
    failure_count = 0
    if File::exists?('sync.failures')
      failure_count = File::read('sync.failures').strip.to_i
    end
    File::open('sync.failures', 'w') do |f|
      f.print (failure_count += 1)
    end
    if(failure_count > 2)
      `echo "#{Time::now}: MegaMegaMonitor's sync has failed #{failure_count} times in a row. Something's probably up." | mailx -s "MegaMegaMonitor sync failed" dan@danq.me`
    end
    exit
  else
    File::open('sync.lock', 'w') do |f|
      f.print Process.pid
    end
    if File::exists?('sync.failures')
      failure_count = File::read('sync.failures').strip.to_i
      if(failure_count > 2)
        `echo "#{Time::now}: Looks like it's working again now." | mailx -s "MegaMegaMonitor sync failed" dan@danq.me`
      end
      FileUtils::rm('sync.failures')
    end
  end
end

if CONNECT_TO_REDDIT && !requested_permutations
  Account::eager_load(:subreddits).all.each do |account|
    puts "Acting as #{account.username}:"

    begin
      r = MegaMegaMonitor::connect(account)
    rescue Redd::Error::ServiceUnavailable
      puts "WARNING: no connection to Reddit. Doing 'offline' stuff only."
      r = nil # no connection - can't do "hot" things right now, but carry on with the rest
      sleep(LONG_DELAY)
    rescue TypeError
      puts "WARNING: TypeError - this can occur when we're making too many requests at once. Treating as no connection and doing 'offline' stuff only."
      r = nil # no connection - can't do "hot" things right now, but carry on with the rest
      sleep(LONG_DELAY)
    end
    sleep(SHORT_DELAY)

    if r
      # Update list of subreddits that this account is a contributor to, if
      # the oldest of the subs in the list is out of date
      least_updated = account.subreddits.where('user_list_updated_at IS NOT NULL').order('user_list_updated_at ASC').first
      age = least_updated ? (Time::now - least_updated.user_list_updated_at) : (UPDATE_SUBREDDIT_LIST_FREQUENCY + 1)
      if r && (age >= UPDATE_SUBREDDIT_LIST_FREQUENCY)
        # old enough - let's do the update
        begin
          print 'Updating list of subreddits: '
          all_my_subs = r.get_all_my_subs
          all_my_subs.each do |s|
            sub = Subreddit::find_by_name(s[:name]) || account.subreddits.new(name: s[:name])
            sub.display_name = s[:display_name]
            sub.updated_at = Time::now
            print sub.new_record? ? '+' : '.'
            sub.save
          end
          # delete any subs missing from the list
          account.subreddits.where('name NOT IN (?)', all_my_subs.collect{|s|s[:name]}).each do |sub|
            print '-'
            sub.destroy
          end
        rescue Redd::Error::ServiceUnavailable, Redd::Error::TimedOut => e
          print " Connection failed (#{e.class}). Carrying on without updating."
          sleep(LONG_DELAY)
        end
        sleep(SHORT_DELAY)
        print "\n"
      end

      # Update list of contributors for each subreddit that this account monitors
      all_users = {}
      User.all.each do |user|
        all_users[user.name] = user.id
      end
      account.subreddits.where('monitor_contributors = 1').where('user_list_updated_at < ? OR user_list_updated_at IS NULL', Time::now - UPDATE_SUBREDDIT_CONTRIBUTOR_FREQUENCY).all.each do |sub|
        existing_contributors_user_ids = sub.contributors.pluck(:user_id)
        begin
          print "/r/#{sub.display_name}: "
          only_adding = (sub.user_list_updated_at.try(:to_date) == Date::today)
          page_limit = only_adding ? 2 : 9999
          all_contributors = r.get_all_contributors(sub.display_name, page_limit)
          sleep(SHORT_DELAY)
          sub_user_ids = []
          all_contributors.each do |c|
            # New, O(1) approach:
            if !(user_id = all_users[c[:name]])
              user = User::new(name: c[:name], display_name: c[:display_name])
              raise "Failed to save new user #{user.display_name}." unless user.save
              print '@'
              user_id = all_users[user.name] = user.id
            end
            # Old, O(N) approach
            #user = User::find_by_name(c[:name]) || User::new(name: c[:name], display_name: c[:display_name])
            #if user.new_record?
            #  print '@'
            #  user.save
            #end
            #sub_user_ids << user.id
            # New, O(1) approach:
            if(existing_contributors_user_ids.include?(user_id))
              print '.'
            else
              contributor = Contributor::new(user_id: user_id, subreddit_id: sub.id, date: c[:date])
              contributor.date, contributor.updated_at = c[:date], Time::now
              raise "Failed to save new contributor #{user_id}/#{sub.id}" unless contributor.save
              print '+'
            end
            sub_user_ids << user_id
            # Old, O(N) approach:
            #contributor = Contributor::find_by_user_id_and_subreddit_id(user.id, sub.id) || Contributor::new(user_id: user.id, subreddit_id: sub.id, date: c[:date])
            #if contributor.new_record?
            #  print '+'
            #  contributor.save
            #else
            #  print '.'
            #  contributor.date, contributor.updated_at = c[:date], Time::now
            #  contributor.save
            #end
          end
          if !only_adding
            sub.contributors.where('user_id NOT IN (?)', sub_user_ids).each do |contributor|
              print '-'
              contributor.destroy
            end
          end
          sub.touch(:user_list_updated_at)
        rescue Redd::Error::ServiceUnavailable
          print " Connection failed (Redd::Error::ServiceUnavailable). Carrying on without updating."
        end
        print "\n"
      end

      if(subs_for_gild_monitoring = account.subreddits.select{|s|s.monitor_gildings?}.select{|s|s.gildings_updated_at.nil? || s.gildings_updated_at < (Time::now - UPDATE_SUBREDDIT_GILDINGS_FREQUENCY)}).any?
        puts "Fetching gildings:"
        subs_for_gild_monitoring.each do |sub|
          begin
            print " * #{account.username}@#{sub.display_name}: "
            last_gilding = sub.gildings.last
            last_gilding_kind, last_gilding_name = last_gilding.try(:kind), last_gilding.try(:name)
            new_gildings = r.get_all_gildings([sub.display_name], until_kind: last_gilding_kind, until_name: last_gilding_name)
            new_gildings.reverse.each do |g|
              if gilding = sub.gildings.find_by_kind_and_name(g[:kind], g[:id]) # existing
                if g[:author] == '[deleted]'
                  gilding.destroy # existing in DB, but deleted from Reddit; delete from DB
                  print '-'
                else
                  print '.' # existing in DB and Reddit; leave
                end
              elsif g[:author] == '[deleted]'
                # not in DB, and already deleted from Reddit; ignore
              elsif u = User::find_by_display_name(g[:author]) # new one; user found
                gilding = sub.gildings.create(kind: g[:kind], name: g[:id], user: u, url: g[:url], created_utc: g[:created_utc].to_i, gilded: g[:gilded])
                print '+'
              else # new one and user not found! better create a user for them, I guess
                u_thing = r.user(g[:author])
                u = User::new(name: "#{u_thing[:kind]}_#{u_thing[:id]}", display_name: u_thing[:name])
                raise "Error when saving user!" unless u.save
                print '@'
                gilding = sub.gildings.create(kind: g[:kind], name: g[:id], user: u, url: g[:url], created_utc: g[:created_utc].to_i, gilded: g[:gilded])
                print '+'
              end
            end
            sub.gildings_updated_at = Time::now
            sub.save
            print "\n"
          rescue Redd::Error::ServiceUnavailable
            print " Connection failed (Redd::Error::ServiceUnavailable). Carrying on without updating."
          end
        end
      end # if(subs_for_gild_monitoring = account.subreddits.select{|s|s.monitor_gildings?}).any?

    end # if r
  end # Account::all.each do |account|
end # if !requested_permutations

# Generate membership lists for installations
results = {}
Subreddit::where('spriteset_position IS NOT NULL').order(:display_name).all.each do |s|
  s.users.pluck(:display_name).each{|c| (results[c] ||= []) << s.display_name }
end
# Generate permutations of subs represented for those lists
permutations = results.values.uniq.sort.collect{|p| { filename: Digest::MD5::hexdigest(p.join('-').downcase), subreddits: p } }.sort_by{|p| p[:subreddits] }

# If we asked for a specific permutation, filter down to just that (or those)
if requested_permutations
  permutations.select!{|p| requested_permutations.include?(p[:filename])}
  puts "Generating only the following permutations: #{permutations.map{|p|p[:filename]}.join(', ')}"
  if permutations.empty?
    puts "No permutations! Exiting."
    exit
  end
end

# Precache MegaMegaMonitor users
mega_mega_mega_monitor ||= Subreddit::find_by_display_name('MegaMegaMegaMonitor')
mmm_users = {}
User::where('installation_seen_at >= ?', 1.week.ago).each do |user|
  username = user.display_name
  if(user.contributors.where('subreddit_id = ?', mega_mega_mega_monitor.id).any?)
    mmm_users[username] = ["mmm-icon-68", 'Uses MegaMegaMonitor and is super special!', 'MegaMegaMonitor', 'mmm']
  else
    mmm_users[username] = ["mmm-icon-64", 'Uses MegaMegaMonitor', 'MegaMegaMonitor', 'mmm']
  end
end

# Precache subreddits by name
subs_precached = {}
subs_by_chain_number_precached = {}
unchained_sprited_subs_by_display_name = {}
print 'Precaching subs: '
Subreddit::where('spriteset_position IS NOT NULL').pluck(:id).each do |id|
  s = Subreddit::eager_load(:contributors, :cryptokeys).find_by_id(id)
  print "."
  subs_precached[s.display_name] = s
  if s.chain_number?
    subs_by_chain_number_precached[s.chain_number] = s
  elsif s.spriteset_position?
    unchained_sprited_subs_by_display_name[s.display_name] = s
  end
end
puts ' done'

# Precache visible ninjas and pirates
visible_ninjas = [] # spriteset 71
visible_pirates = [] # spriteset 72
#print 'Precaching visible ninjas and pirates: '
#User::where('ninja_pirate_visible = ?', true).eager_load(:subreddits).all.each do |user|
#  print '.'
#  visible_ninjas << user.display_name if user.subreddits.any?{|s| s.display_name == 'NinjaLounge' }
#  visible_pirates << user.display_name if user.subreddits.any?{|s| s.display_name == 'PirateLounge' }
#end
#puts "\n"

# Precache cryptos by sub id
#cryptos_precached = {}
#Cryptokey.eager_load(:subreddit)::all.each do |c|
#  x = (cryptos_precached[c.subreddit_id] ||= {})
#  if x.any? # invalidate any earlier keys
#    x.values.each{|v| v[:revoked] = true}
#  end
#  x[c.id] = { key: c.secret_key, name: c.subreddit.display_name, subreddit_id: c.subreddit_id }
#end

# TODO: add something that runs the tidyup-after-deleted-subs thing:
# DELETE FROM contributors WHERE subreddit_id NOT IN (SELECT id FROM subreddits);

# Generate output
puts "Generating JSON: "
#`rm #{OUTPUT_DIR}/*.json`
permutations.each do |p|
  my_sub_ids = p[:subreddits].collect{|s| subs_precached[s].id }
  i_am_a_pirate, i_am_a_ninja = my_sub_ids.include?(PIRATE_SUB_ID), my_sub_ids.include?(NINJA_SUB_ID)
  # Don't re-write files that have JUST been written, to allow "continuing" from failed writes
  if File::exists?("#{OUTPUT_DIR}/#{p[:filename]}.json") && ((Time::now - File.stat("#{OUTPUT_DIR}/#{p[:filename]}.json").mtime).seconds < 15.minutes) && !requested_permutations
    puts " * SKIPPING #{OUTPUT_DIR}/#{p[:filename]}.json - file only recently written"
    next
  end
  puts " * #{OUTPUT_DIR}/#{p[:filename]}.json"
  # Generate customised membership lists for this permutation, based on CSS classes
  users = {}
  # 1. MegaChain - same and lower
  if (my_highest_chain = Subreddit::where('chain_number IS NOT NULL AND display_name IN (?)', p[:subreddits]).order('chain_number DESC').first)
    (1..my_highest_chain.chain_number).to_a.each do |i|
      (s = subs_by_chain_number_precached[i]).contributors.each do |contributor|
        username = contributor.precached_display_name
        tooltip = s.override_display_name || s.display_name
        tooltip += " (#{contributor.tooltip_suffix})" if contributor.tooltip_suffix?
        users[username] = [["mmm-icon-#{s.spriteset_position}", tooltip, (s.name_is_secret? ? '' : s.display_name), 'chain']]
      end
    end
    # 2. MegaChain - my superiors
    if(s = subs_by_chain_number_precached[my_highest_chain.chain_number + 1])
      s.contributors.collect(&:precached_display_name).each do |username|
        if users[username]
          users[username][0][0] += '-plus'
          users[username][0][1] += '-plus'
        end
      end
    end
  end
  # 3. Other lounges
  p[:subreddits].each do |ps|
    if s = unchained_sprited_subs_by_display_name[ps]
      s.contributors.each do |contributor|
        username = contributor.precached_display_name
        tooltip = s.override_display_name || s.display_name
        tooltip += " (#{contributor.tooltip_suffix})" if contributor.tooltip_suffix?
        (users[username] ||= []) << ["mmm-icon-#{s.spriteset_position}", tooltip, (s.name_is_secret? ? '' : s.display_name), s.id]
      end
    end
  end
  # 4. Fellow users of MegaMegaMonitor
  mmm_users.each do |key, value|
    (users[key] ||= []) << value
  end
  # 5. Publicly-visible pirates and ninjas
  if(i_am_a_pirate || i_am_a_ninja)
    visible_ninjas.each do |ninja|
      if users[ninja]
        users[ninja].reject!{|s| s[0] == "mmm-icon-#{NINJA_SPRITE_ID}"}
        users[ninja] << ["mmm-icon-#{NINJA_SPRITE_ID}-plus", "NinjaLounge (openly-armed!)", 'NinjaLounge', NINJA_SUB_ID]
      end
    end
    visible_pirates.each do |pirate|
      if users[pirate]
        users[pirate].reject!{|s| s[0] == "mmm-icon-#{PIRATE_SPRITE_ID}"}
        users[pirate] << ["mmm-icon-#{PIRATE_SPRITE_ID}-plus", "PirateLounge (openly-armed!)", 'PirateLounge', PIRATE_SUB_ID]
      end
    end
  end

  File::open("#{OUTPUT_DIR}/#{p[:filename]}.json", 'w') do |f|
    f.puts({
      createdAtStart: Subreddit::where('display_name IN (?)', p[:subreddits]).minimum(:user_list_updated_at),
        createdAtEnd: Time::now,
          apiVersion: VERSION,
        mySubreddits: p[:subreddits].collect{|s| subs_precached[s].attributes.select{|k,v| %w{id display_name spriteset_position chain_number}.include?(k)}.merge({ cryptos: subs_precached[s].cryptos }) },
#             cryptos: cryptos_precached.select{|k,v| my_sub_ids.include?(k) }.values.flatten.inject(&:merge),
       myChainHeight: my_highest_chain.try(:chain_number) || 0,
               users: users
    }.to_json)
  end
end

if !requested_permutations
  FileUtils::rm('sync.lock') if File::exists?('sync.lock')
end
