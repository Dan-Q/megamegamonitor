class Subreddit < ActiveRecord::Base
  belongs_to :account  
  has_many :contributors
  has_many :users, through: :contributors
  has_many :cryptokeys
  has_many :gildings

  has_attached_file :icon_default
  has_attached_file :icon_current
  has_attached_file :icon_higher
  validates_attachment :icon_default, content_type: { content_type: ['image/png'] }
  validates_attachment :icon_current, content_type: { content_type: ['image/png'] }
  validates_attachment :icon_higher, content_type: { content_type: ['image/png'] }

  attr_accessor :reencode_existing_icons, :new_cryptokey
  before_save :cache_encoded_icons
  after_save :create_cryptokey_if_requested

  scope :with_monitored_contributors, -> { where('subreddits.monitor_contributors = ?', true) }

  protected
  # Precaches and stores in the database base64 ("data: URI") encoded versions of each changed icon type
  def cache_encoded_icons
    if (@reencode_existing_icons === 1) || (@reencode_existing_icons === '1') || (@reencode_existing_icons === true)
      @reencode_existing_icons = false
      self.encoded_icon_default = 'data:image/png;base64,'+Base64.strict_encode64(File.read(self.icon_default.path || "#{Rails.root}/public/icon_defaults/original/missing.png"))
      self.encoded_icon_current = 'data:image/png;base64,'+Base64.strict_encode64(File.read(self.icon_current.path || "#{Rails.root}/public/icon_currents/original/missing.png"))
      self.encoded_icon_higher  = 'data:image/png;base64,'+Base64.strict_encode64(File.read(self.icon_higher.path  || "#{Rails.root}/public/icon_highers/original/missing.png"))
    end
  end

  # Adds a new cryptokey, if one was desired
  def create_cryptokey_if_requested
    return unless new_cryptokey == '1'
    cryptokeys.create
  end
end
