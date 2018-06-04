class User < ActiveRecord::Base
  has_many :accesskeys
  has_many :contributors
  has_many :subreddits, through: :contributors
  has_many :gildings
end
