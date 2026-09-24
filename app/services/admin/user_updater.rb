class Admin::UserUpdater
  def self.call(actor:, user:, attributes:)
    User.transaction do
      # Serialize role changes, including concurrent demotions of two admins.
      User.connection.execute("SELECT pg_advisory_xact_lock(7241901)")
      User.where(id: [ actor.id, user.id ]).order(:id).lock.load
      actor.reload
      user.reload
      policy = UserPolicy.new(actor, user)
      raise Admin::Forbidden unless policy.update?

      user.assign_attributes(attributes.slice(:role, :suspended))
      if user.suspended? && !policy.suspend?
        user.errors.add(:base, "Du kannst dein eigenes Konto nicht sperren.")
        raise ActiveRecord::RecordInvalid, user
      end
      if user.role_in_database == "admin" && (!user.admin? || user.suspended?) &&
          !User.admin.where(suspended: false).where.not(id: user.id).exists?
        user.errors.add(:base, "Mindestens ein aktiver Admin muss erhalten bleiben.")
        raise ActiveRecord::RecordInvalid, user
      end
      user.save!
      AdminActivity.record!(admin: actor, subject: user, action: "permissions",
        details: user.saved_changes.slice("role", "suspended"))
      user
    end
  end
end
