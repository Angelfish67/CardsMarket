class Admin::CoinGranter
  def self.call(actor:, user:, amount:, reason: nil)
    User.transaction do
      # Use the same wallet lock order as purchases; reload permissions under lock.
      User.where(id: [ actor.id, user.id ]).order(:id).lock.load
      actor.reload
      user.reload
      raise Admin::Forbidden unless UserPolicy.new(actor, user).grant_coins?

      value = amount.to_s.strip
      unless value.match?(/\A[0-9]{1,10}\z/) && (coins = value.to_i).between?(1, User::MAX_COINS)
        raise GameplayError, "Bitte einen positiven Betrag in ganzen Coins eingeben."
      end
      note = reason.to_s.strip
      raise GameplayError, "Die Begründung darf maximal 250 Zeichen lang sein." if note.length > 250
      if user.coins + coins > User::MAX_COINS
        raise GameplayError, "Die Gutschrift würde das Guthabenlimit von #{User::MAX_COINS} Coins überschreiten."
      end

      before = user.coins
      user.update!(coins: before + coins)
      AdminActivity.record!(admin: actor, subject: user, action: "coins_granted",
        details: { "coins" => [ before, user.coins ], "amount" => [ nil, coins ], "reason" => [ nil, note.presence ] })
      user
    end
  end
end
