
[
  [ "E", 1.0, 50 ],
  [ "D", 1.2, 25 ],
  [ "C", 1.5, 14 ],
  [ "B", 2.0, 7 ],
  [ "A", 3.0, 3 ],
  [ "SS", 5.0, 1 ]
].each do |name, multiplier, weight|
  Rank.find_or_create_by!(name: name) do |rank|
    rank.multiplier = multiplier
    rank.weight = weight
  end
end

Pack.find_or_create_by!(name: "Starter Pack") do |pack|
  pack.price = 0
  pack.cards_count = 3
  pack.starter = true
end

JSON.parse(Rails.root.join("db/brainrot_catalog.json").read).each do |attributes|
  type = BrainrotType.find_or_create_by!(name: attributes.fetch("name")) do |record|
    record.assign_attributes(attributes)
  end
  type.with_lock do
    type.update!(image_url: attributes.fetch("image_url")) if type.image_url.blank?
  end
end

Pack.find_or_create_by!(name: "Anfänger-Pack") do |pack|
  pack.price = 100
  pack.cards_count = 3
  pack.starter = false
end
