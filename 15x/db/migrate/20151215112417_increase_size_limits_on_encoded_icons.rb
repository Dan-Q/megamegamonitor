class IncreaseSizeLimitsOnEncodedIcons < ActiveRecord::Migration
  def up
    %w{encoded_icon_default encoded_icon_current encoded_icon_higher}.each do |c|
      change_column :subreddits, c, :string, limit: 16.kilobytes
    end
  end

  def down
    %w{encoded_icon_default encoded_icon_current encoded_icon_higher}.each do |c|
      change_column :subreddits, c, :string, limit: 4.kilobytes
    end
  end
end
