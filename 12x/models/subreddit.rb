class Subreddit < ActiveRecord::Base
  belongs_to :account
  has_many :contributors
  has_many :users, through: :contributors
  has_many :gildings
  has_many :cryptokeys

  def cryptos
    cryptokeys.pluck(:id, :secret_key)
  end
end
