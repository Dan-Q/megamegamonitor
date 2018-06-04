class Contributor < ActiveRecord::Base
  belongs_to :user
  belongs_to :subreddit
  before_save :precache_display_name, on: :create

  delegate :name, to: :user

  validates :user_id, uniqueness: { scope: :subreddit_id }

  def precached_display_name
    if self.display_name.nil?
      precache_display_name
      save
    end
    self.display_name
  end

  def precache_display_name
    self.display_name = user.display_name
  end
end
