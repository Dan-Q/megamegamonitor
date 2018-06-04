class Account < ActiveRecord::Base
  has_many :subreddits
end
