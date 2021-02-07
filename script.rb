require 'json'
require 'csv'
require 'nokogiri'

FOOD_GROUPS = [
  'Vegetables',
  'Eggs',
  'Fishes',
  'Meats',
  'Fruits',
  'Monster Foods',
  'Dairy',
  'Bugs',
  'Inedibles'
].freeze

VEGETABLES = [
  'Aloe', 'Asparagus', 'Blue Cap', 'Cactus Flesh', 'Cactus Flower', 'Carrot',
  'Corn', 'Corn Cod', 'Dark Petals', 'Eggplant', 'Foliage', 'Garlic',
  'Glow Berry', 'Green Cap', 'Kelp Fronds', 'Lichen', 'Mandrake', 'Moon Shroom',
  'Onion', 'Pepper', 'Petals', 'Popperfish', 'Potato', 'Pumpkin', 'Radish',
  'Red Cap', 'Ripe Stone Fruit', 'Seaweed', 'Succulent', 'Sweet Potato',
  'Toma Root'
].freeze

MEATS = [
  'Barnacles', 'Batilisk Wing', 'Dead Dogfish', 'Dead Swordfish',
  'Deerclops Eyeball', 'Dragoon Heart', 'Drumstick', 'Eel',
  'Eye of the Tiger Shark', 'Fish', 'Fish Meat', 'Fish Morsel', 'Flytrap Stalk',
  'Frog Legs', "Guardian's Horn", 'Koalefant Trunk', 'Leafy Meat', 'Meat',
  'Monster Meat', 'Morsel', 'Naked Nostrils', 'Neon Quattro', 'Pierrot Fish',
  'Poison Dartfrog Legs', 'Purple Grouper', 'Raw Fish', 'Roe', 'Shark Fin',
  'Tropical Fish', 'Winter Koalefant Trunk'
].freeze

module Shared
  def html_to_csv(input, output)
    f = File.open(input)
    doc = Nokogiri::HTML(f)
    csv = CSV.open(output, 'w', col_sep: ',', quote_char: '"', force_quotes: true, encoding: 'ISO8859-1:utf-8')
    yield doc, csv
    csv.close
  end

  def csv_to_json(input, output)
    content = CSV.read(input, col_sep: ',', headers: true)
    transformed = content.map { |r| r.to_h.map { |k, v| normalize(k, v) }.to_h }.sort_by { |r| r['name'] }
    File.open(output, 'w:ISO8859-1:utf-8') { |f| f.write(JSON.pretty_generate({ data: transformed })) }
  end

  def normalize(key, value)
    [key, value]
  end
end

class Crockpot
  include Shared

  def convert_html_to_csv(input, output)
    html_to_csv(input, output) do |doc, csv|
      csv << ['name', 'dlc', 'health', 'hunger', 'sanity', 'perish_time', 'cook_time', 'priority', 'requirements', 'filler_restrictions']

      doc.xpath('//table/tbody/tr').each do |row|
        tarray = []
        row.xpath('td').each_with_index do |cell, index|
          next if index.zero?

          if [2].include?(index)
            carray = []
            cell.children.each do |child|
              if child.name == 'a'
                carray << child.attr('title').to_s.gsub('icon', '').strip
              end
            end
            tarray << carray.join(', ')
          elsif [9, 10].include?(index)
            carray = []
            cell.children.each do |child|
              if child.name == 'a'
                carray << child.attr('title')
              else
                carray << child.text
                carray << ','
              end
            end
            tarray << carray.join('').split(',').map(&:strip).reject(&:empty?).join(' ')
          else
            tarray << cell.text.strip
          end
        end
        csv << tarray
      end
    end
  end

  def normalize(key, value)
    normalized = if key == 'dlc'
      value.split(',').map(&:strip)
                 elsif %w(health hunger sanity).include?(key)
                   value.to_f
                 elsif key == 'requirements'
                   value.split(',').map do |ingredient|
                     captures = ingredient.match(/(\b[\w\s]+\b)×([\d\.]+)/).captures
                     "#{captures[0]} (#{captures[1]})"
                   end
                 elsif key == 'filler_restrictions'
                   value.split(',').map do |restriction|
                     matches = restriction.match(/(\b[\w\s]+\b)×([\d\.]+)/)
                     if matches
                       captures = matches.captures
                       "#{captures[0]} (#{captures[1]})"
                     else
                       restriction
                     end
                   end
                 else
                   value
                 end
    [key, normalized]
  end
end

class Vegetable
  include Shared

  def convert_html_to_csv(input, output)
    html_to_csv(input, output) do |doc, csv|
      csv << ['name', 'sources', 'cooked', 'dried', 'dlc', 'value', 'crockpot']

      doc.xpath('//table/tbody/tr').each do |row|
        tarray = []
        row.xpath('td').each_with_index do |cell, index|
          next if [0, 2, 4].include?(index)

          if [6].include?(index)
            tarray << cell.xpath('a').attr('title')
          elsif [8].include?(index)
            tarray << (cell.text.strip == 'Yes')
          elsif [7].include?(index)
            tarray << cell.text.strip.to_f
          elsif [1, 3, 5].include?(index)
            tarray << cell.text.strip
          end
        end
        tarray.insert(1, tarray[0])
        next if tarray.all?(&:nil?)

        csv << tarray
      end
    end
  end
end

class Meat
  include Shared

  def convert_html_to_csv(input, output)
    html_to_csv(input, output) do |doc, csv|
      csv << ['name', 'sources', 'cooked', 'dried', 'dlc', 'value', 'crockpot']

      raw_array = []
      doc.xpath('//table/tbody/tr').each do |row|
        tarray = []
        row.xpath('td').each_with_index do |cell, index|
          next if [0, 2, 4, 6].include?(index)

          if [8].include?(index)
            tarray << cell.xpath('a').attr('title')
          elsif [10].include?(index)
            tarray << (cell.text.strip == 'Yes')
          elsif [9].include?(index)
            tarray << cell.text.strip.to_f
          elsif [1, 3, 5, 7].include?(index)
            tarray << cell.text.strip
          end
        end
        raw_array << tarray
      end

      raw_array.reject { |r| r.all?(&:empty?) }.group_by { |r| r[1] }.each do |name, meats|
        sources = meats.reject { |m| m[0] == 'N/A' }.map { |m| m[0] }.join(',')
        csv << [name, sources.empty? ? name : sources, *meats.first[2..]]
      end
    end
  end
end