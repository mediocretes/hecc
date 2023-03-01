require 'bundler/setup'
Bundler.require

SYSTEMS = [].uniq

SYSTEM_URL_BASE = "http://www.roguewar.org/system"

def public_static_void_main
  ours = []
  contested = []
  targets = []
  controlled = []

  SYSTEMS.each do |system|
    package = scan_system(system)
    if package[:control].any? { |(faction, percent)| faction == "Terran Hegemony" && percent.to_i >= 100 }
      ours << package
    elsif package[:control].any? { |(faction, percent)| faction == "Terran Hegemony" }
      contested << package
    else
      targets << package
    end

    controlled << package if package[:owner] == "Terran Hegemony"
  end

  puts "-- Secure: --"
  puts ours.map{ |x| x[:name] }.join(", ")
  puts "-- Contested: --"
  contested.sort_by! { |x| x[:control].detect { |faction| faction.first == "Terran Hegemony" }.last.to_i }
  contested.reverse.each do |c|
    faction_string = c[:control].sort { |a, b| b.last <=> a.last }.map { |faction| "#{faction.first}: #{faction.last}" }.join(", ")
    puts "#{c[:name]}: #{faction_string}"
  end
  puts "-- Targets -- "
  puts targets.map { |x| "#{x[:name]} (#{x[:owner]})" }.join(", ")

  puts "-- Recommended Drops --"

  recommended_drops = contested + targets
  border_worlds = controlled.map { |p| p[:nearby] }.flatten.uniq

  recommended_drops.select! do |p|
    border_worlds.include?(p[:name])
  end

  drop_vs = Hash.new { |h, k| h[k] = [] }
  recommended_drops.each do |x|
    faction_string = x[:control].sort { |a, b| b.last <=> a.last }.reject{ |f| f.first == "Terran Hegemony" }.first.first
    drop_vs[faction_string || x[:owner]] << x[:name]
  end

  drop_vs.each do |faction, planet|
    puts "vs #{faction} on #{planet.join(', ')}"
  end
end

def scan_system(system_id)
  page = HTTParty.get("#{SYSTEM_URL_BASE}/#{system_id}").body
  document = Nokogiri::HTML(page)
  report = { :name => document.at('div[class=container]/h2').text }
  report[:owner] = document.at('th:contains("Current Owner")').next_element.text
  report[:control] = document.at('h3:contains("Control Levels")').next_element.search('tr').map do |row|
    cells = row.search('td').map(&:text)
  end.reject(&:empty?)
  report[:nearby] = document.at('h3:contains("Nearby Systems")').next_element.search('tr').map do |row|
    cells = row.search('td').map(&:text)
  end.reject(&:empty?).map(&:first)

  report
end

public_static_void_main
