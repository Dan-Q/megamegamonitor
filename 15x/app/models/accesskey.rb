class Accesskey < ActiveRecord::Base
  belongs_to :user

  validates :secret_key, presence: true, uniqueness: true

  before_validation :set_secret_key, on: :create

  private

  def set_secret_key
    new_token = nil
    loop do
      new_token = SecureRandom.base64.tr('+/=', 'M3w')
      break new_token unless Accesskey.where(secret_key: new_token).any?
    end
    self.secret_key = new_token
  end
end
