module Admin
  class PayoutsDashboardController < ApplicationController
    before_action :admin_required

    def index
      @cap = Payout.sum(:amount)

      yesterday = 24.hours.ago
      recent = Payout.where(created_at: yesterday..)

      @created = recent.where("amount > 0").sum(:amount)
      @destroyed = recent.where("amount < 0").sum(:amount).abs
      @txns = recent.count
      @volume = recent.sum("ABS(amount)")

      spenders = Payout.joins(:user)
                      .where(created_at: yesterday.., amount: ...0, payable_type: "ShopOrder")
                      .group("users.id", "users.display_name", "users.avatar")
                      .sum("payouts.amount")

      @spenders = spenders.map { |user_data, amount| [ user_data, amount.abs ] }
                         .sort_by { |_, amount| -amount }
                         .first(10)

      holder_balances = Payout.joins(:user)
                             .group("users.id", "users.display_name", "users.avatar")
                             .sum(:amount)
                             .select { |_, balance| balance > 0 }
                             .sort_by { |_, balance| -balance }
                             .first(10)

      @holders = holder_balances

      @sources = {}
      recent.group(:payable_type).group("amount > 0").sum(:amount).each do |key, amount|
        @sources[key] = amount
      end

      thirty_days_ago = 30.days.ago.beginning_of_day
      daily_data = Payout.where(created_at: thirty_days_ago..)
                         .group("DATE(created_at)")
                         .group("CASE WHEN amount >= 0 THEN 'created' ELSE 'destroyed' END")
                         .sum("ABS(amount)")

      @creation = {}
      @destruction = {}

      30.times do |i|
        date = i.days.ago.to_date
        date_str = date.to_s
        @creation[date] = daily_data[[ date_str, "created" ]] || 0
        @destruction[date] = daily_data[[ date_str, "destroyed" ]] || 0
      end

      circulation_data = Payout.where("created_at < ?", 31.days.ago.beginning_of_day)
                              .sum(:amount)

      daily_changes = Payout.where(created_at: thirty_days_ago..)
                           .group("DATE(created_at)")
                           .sum(:amount)

      @circulation = {}
      total = circulation_data

      30.times do |i|
        date = i.days.ago.to_date
        change = daily_changes[date.to_s] || 0
        total += change
        @circulation[date] = total
      end

      @creation = @creation.sort.to_h
      @destruction = @destruction.sort.to_h
      @circulation = @circulation.sort.to_h

      @types = {}
      Payout.where(created_at: 7.days.ago..).group(:payable_type).sum("ABS(amount)").each do |type, volume|
        @types[type&.humanize || "Unknown"] = volume
      end
    end

    private

    def admin_required
      redirect_to root_path unless current_user&.is_admin?
    end
  end
end
