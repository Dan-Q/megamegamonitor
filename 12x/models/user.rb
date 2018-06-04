class User < ActiveRecord::Base
  has_many :contributors
  has_many :subreddits, through: :contributors
  has_many :gildings
  has_many :accesskeys
end
