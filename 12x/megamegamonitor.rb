#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'redd'
require 'yaml'
require 'json'
require 'active_record'
require 'digest/md5'

# Require libraries and models
%w{lib models}.each do |dir|
  Dir.glob(File.join(File.dirname(__FILE__), dir, '*.rb')) do |model|
    eval(IO.read(model), binding)
  end
end

# Establish database connection
ActiveRecord::Base.establish_connection(adapter: 'mysql2', database: 'megamegamonitor', username: 'mmm', password: 'DATABASE PASSWORD')

module MegaMegaMonitor
  # Constants
  USER_AGENT = 'MegaMegaMonitorBot v1.1 by /u/avapoet'

  # Establish Reddit connection
  def self.connect(account)
    puts "MegaMegaMonitor#connect - connecting as #{account.username}"
    r = Redd::Client::Authenticated.new_from_credentials account.username, account.password, user_agent: USER_AGENT
    r.user_agent = USER_AGENT
    r
  end

  # Console convenience commands
  def self.list_members(subreddit_name)
    puts Subreddit::find_by_display_name(subreddit_name).contributors.sort_by{|c|(c.tooltip_suffix||'').gsub(/[^-\d]/,'').to_i}.map{|c|sprintf('%6i %30s %15s',c.id,c.user.display_name,c.tooltip_suffix)}.join("\n")
  end

  def self.set_tooltip(subreddit_name, username, tooltip)
    Contributor::where('user_id = ? AND subreddit_id = ?', User::find_by_display_name(username).id, Subreddit::find_by_display_name(subreddit_name).id).first.update_attributes(tooltip_suffix: tooltip)
  end
end
