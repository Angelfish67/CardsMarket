class AccountManager
  class Forbidden < StandardError; end

  def self.call(user:, current_password:, action:, attributes: {})
    User.transaction do
      # Share the admin role-change lock so the last admin cannot disappear in a race.
      User.connection.execute("SELECT pg_advisory_xact_lock(7241901)") if action == :deactivate
      user.lock!
      policy = AccountPolicy.new(user, user)
      raise Forbidden unless action == :deactivate ? policy.deactivate? : policy.update?

      unless current_password.is_a?(String) && current_password.bytesize <= 72 && user.authenticate(current_password)
        user.errors.add(:base, "Das aktuelle Passwort ist nicht korrekt.")
        raise ActiveRecord::RecordInvalid, user
      end

      case action
      when :profile
        user.assign_attributes(attributes.slice(:username, :email_address))
      when :password
        if attributes[:password].blank? || attributes[:password_confirmation].blank?
          user.errors.add(:base, "Bitte das neue Passwort zweimal eingeben.")
          raise ActiveRecord::RecordInvalid, user
        end
        user.assign_attributes(attributes.slice(:password, :password_confirmation))
      when :deactivate
        unless attributes[:confirmation] == "1"
          user.errors.add(:base, "Bitte die Deaktivierung ausdrücklich bestätigen.")
          raise ActiveRecord::RecordInvalid, user
        end
        if user.admin? && !User.admin.where(suspended: false).where.not(id: user.id).exists?
          user.errors.add(:base, "Mindestens ein aktiver Admin muss erhalten bleiben. Ernenne zuerst einen weiteren Admin.")
          raise ActiveRecord::RecordInvalid, user
        end
        user.market_offers.active.order(:brainrot_card_id, :id).each do |offer|
          MarketOfferWithdrawer.call(user: user, offer: offer)
        end
        user.suspended = true
      else
        raise ArgumentError, "Unknown account action"
      end

      sign_out = action == :deactivate || user.will_save_change_to_password_digest? || user.will_save_change_to_email_address?
      user.save!
      user.sessions.destroy_all if sign_out
      sign_out
    end
  end
end
