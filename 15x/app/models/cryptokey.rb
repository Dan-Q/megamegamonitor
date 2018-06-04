class Cryptokey < ActiveRecord::Base
  belongs_to :subreddit

  validates :secret_key, presence: true, uniqueness: true
  before_validation :generate_secret_key

  protected
  def generate_secret_key
    return unless self.secret_key.blank?
    self.secret_key = SecureRandom.hex(32)
  end
end
