require "rails_helper"

RSpec.describe Ascacou::Board do
  describe ".pattern_of" do
    it "lit les bits HG HD BG BD, blanc = 1" do
      expect(described_class.pattern_of(%i[black black black black])).to eq(0)
      expect(described_class.pattern_of(%i[white white white white])).to eq(15)
      expect(described_class.pattern_of(%i[white black black black])).to eq(8)
      expect(described_class.pattern_of(%i[black black black white])).to eq(1)
      expect(described_class.pattern_of([ :black, nil, :black, :black ])).to be_nil
    end
  end

  describe "#place" do
    it "renvoie un nouveau plateau" do
      board = described_class.empty
      placed = board.place("3x3", :black)
      expect(board["3x3"]).to be_nil
      expect(placed["3x3"]).to eq(:black)
    end

    it "refuse une case occupée ou une coordonnée invalide" do
      board = described_class.empty.place("1x1", :white)
      expect { board.place("1x1", :black) }.to raise_error(ArgumentError)
      expect { board.place("6x1", :black) }.to raise_error(ArgumentError)
      expect { board.place("1x2", :green) }.to raise_error(ArgumentError)
    end
  end

  describe "exemples du livret" do
    # Ligne 2 : trois noirs ; ligne 3 : blanc, vide, blanc.
    let(:board) { described_class.parse(".bbb./.w.w./...../...../.....") }

    # Le pion est joué en 2x3, entre les deux blancs.

    it "un pion noir entre les deux blancs reproduit deux motifs" do
      expect(board.legal?("2x3", :black)).to be(true)
      expect(board.place("2x3", :black).realized_patterns).to contain_exactly(2, 1)
      expect(board.place("2x3", :black).squares)
        .to eq([ { pattern: 2, coord: "1x2" }, { pattern: 1, coord: "1x3" } ])
    end

    it "un pion blanc entre les deux blancs reproduirait deux fois le même motif" do
      expect(board.legal?("2x3", :white)).to be(false)
      expect(board.legal?("2x3", :white, multiple: true)).to be(true)
    end

    it "signale par un pion vert une case où aucune couleur n'est jouable" do
      board = described_class.parse("wbb../w.wbb/..wbw/..ww./b...b")
      expect(board.blocked?("2x2")).to be(true)
      expect(board.blocked_coords).to include("2x2")
      expect(board.blocked?("2x2", multiple: true)).to be(false)
    end

    it "la solution du jeu solo n°1 contient les 16 motifs" do
      board = described_class.parse("wwwbw/wbbbb/wbbww/bwbww/wwwbw")
      expect(board.realized_patterns.sort).to eq((0..15).to_a)
      expect(board.duplicates?).to be(false)
    end

    it "la fin de partie avec deux pions verts compte 13 motifs" do
      board = described_class.parse("wwbww/bbbwb/bbwwb/wwbww/.bw.w")
      expect(board.duplicates?).to be(false)
      expect(board.realized_patterns.size).to eq(13)
      expect(board.blocked_coords).to contain_exactly("5x1", "5x4")
      expect(board.finished?).to be(true)
    end
  end

  describe "#finished?" do
    it "est faux sur un plateau vide" do
      expect(described_class.empty.finished?).to be(false)
    end

    it "est vrai quand les 16 motifs sont faits" do
      expect(described_class.parse("wwwbw/wbbbb/wbbww/bwbww/wwwbw").finished?).to be(true)
      expect(described_class.parse("wwwbw/wbbbb/wbbww/bwbww/wwwbw").finished?(multiple: true)).to be(true)
    end

    it "peut être vrai alors que des cases restent jouables" do
      # Position trouvée par recherche aléatoire : des coups légaux restent,
      # mais aucun ne peut plus mener à un nouveau motif.
      board = described_class.parse("wwbw./bbbbb/.bbwb/wb..b/bw.bb")
      expect(board.legal_moves).not_to be_empty
      expect(board.finished?).to be(true)
    end

    it "en motif multiple, continue tant qu'un motif nouveau reste possible" do
      board = described_class.parse("wwbw./bbbbb/.bbwb/wb..b/bw.bb")
      expect(board.finished?(multiple: true)).to be(false)
      board = described_class.parse("wwwww/wwwww/wwwww/wwwww/wwww.")
      expect(board.finished?(multiple: true)).to be(false)
    end
  end

  describe ".from_moves et #to_s" do
    it "rejoue des coups et se sérialise" do
      board = described_class.from_moves([ [ "1x1", "black" ], [ "5x5", :white ] ])
      expect(board.to_s).to eq("b..../...../...../...../....w")
      expect(described_class.parse(board.to_s)).to eq(board)
    end
  end
end
