module AdminHelper
  def admin_action_label(action)
    { "coins_granted" => "Coins gutgeschrieben", "destroy" => "Gelöscht", "create" => "Erstellt", "update" => "Bearbeitet", "permissions" => "Berechtigungen geändert", "moderate" => "Angebot entfernt" }.fetch(action, action)
  end

  def admin_subject_label(type)
    { "User" => "Benutzer", "BrainrotType" => "Kartentyp", "Pack" => "Pack", "Rank" => "Rank", "MarketOffer" => "Angebot" }.fetch(type, type)
  end

  def admin_field_label(field)
    { "coins" => "Guthaben", "amount" => "Gutschrift", "reason" => "Begründung", "image" => "Hochgeladenes Bild", "image_url" => "Bild-URL", "name" => "Name", "description" => "Beschreibung", "rarity" => "Seltenheit", "base_value" => "Grundwert",
      "active" => "Verfügbar", "price" => "Preis", "cards_count" => "Kartenanzahl", "starter" => "Starter-Pack",
      "multiplier" => "Multiplikator", "weight" => "Ziehgewicht", "role" => "Rolle", "suspended" => "Gesperrt",
      "status" => "Status", "id" => "Nummer" }.fetch(field, field)
  end

  def admin_value(value)
    return "Ja" if value == true
    return "Nein" if value == false
    return "—" if value.nil?

    { "trader" => "Trader", "admin" => "Admin", "active" => "Aktiv", "withdrawn" => "Zurückgezogen" }.fetch(value.to_s, value.to_s)
  end
end
