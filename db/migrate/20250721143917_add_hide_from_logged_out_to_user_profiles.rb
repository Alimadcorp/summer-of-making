class AddHideFromLoggedOutToUserProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :user_profiles, :hide_from_logged_out, :boolean, default: false
  end
end
