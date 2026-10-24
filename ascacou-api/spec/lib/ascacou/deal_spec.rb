require "rails_helper"

RSpec.describe Ascacou::Deal do
  def whites(hand)
    hand.sum { |card| card.digits(2).sum }
  end

  it "répartit les 16 cartes en deux mains de 8" do
    (described_class::METHODS - [ :draft ]).each do |method|
      first, second = described_class.call(method)
      expect(first.size).to eq(8)
      expect((first + second).sort).to eq((0..15).to_a)
    end
  end

  it "inverse : la seconde main est l'inverse des couleurs de la première" do
    first, second = described_class.call(:inverse)
    expect(first.map { |card| 15 - card }).to match_array(second)
  end

  it "fifty : autant de pions blancs dans chaque main" do
    first, second = described_class.call(:fifty)
    expect(whites(first)).to eq(whites(second))
  end

  it "max : la première main est la plus noire possible" do
    first, = described_class.call(:max)
    expect(whites(first)).to eq((0..15).map { |card| card.digits(2).sum }.sort.first(8).sum)
  end

  it "random : dépend du générateur" do
    expect(described_class.call(:random, random: Random.new(1))).to eq(described_class.call(:random, random: Random.new(1)))
  end

  it "draft : mains vides" do
    expect(described_class.call(:draft)).to eq([ [], [] ])
  end

  it "refuse une distribution inconnue" do
    expect { described_class.call(:extrem) }.to raise_error(ArgumentError)
  end
end
