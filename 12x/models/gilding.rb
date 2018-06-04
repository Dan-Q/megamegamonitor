class Gilding < ActiveRecord::Base
  belongs_to :subreddit
  belongs_to :user
end
