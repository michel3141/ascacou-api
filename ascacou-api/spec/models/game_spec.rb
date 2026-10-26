require "rails_helper"

RSpec.describe Game do
  let(:room) { create(:playing_room) }
  let(:game) { room.current_game }
  let(:first) { game.first_player }
  let(:second) { game.second_player }

  # Pose directement les pions d'un plateau "LxC" (sans passer par les commandes),
  # en alternant les joueurs dans l'ordre des cases.
  def seed(game, text)
    board = Ascacou::Board.parse(text)
    Ascacou::Board::COORDS.reject { |coord| board.empty?(coord) }.each.with_index(1) do |coord, rank|
      game.moves.create!(rank:, coord:, color: board[coord])
    end
    game.reload
  end

  describe "#play!" do
    it "fait alterner les joueurs" do
      game.play!(first, coord: "3x3", color: "black")
      expect(game.current_player).to eq(second)
      expect { game.play!(first, coord: "1x1", color: "white") }.to raise_error(CommandRefused, "not_your_turn")
      game.play!(second, coord: "1x1", color: "white")
      expect(game.board.to_s).to eq("w..../...../..b../...../.....")
      expect(game.lock_version).to eq(2)
    end

    it "refuse un spectateur, une case occupée, une coordonnée ou une couleur invalide" do
      expect { game.play!(create(:user), coord: "1x1", color: "black") }.to raise_error(CommandRefused, "not_a_player")
      game.play!(first, coord: "1x1", color: "black")
      expect { game.play!(second, coord: "1x1", color: "white") }.to raise_error(CommandRefused, "illegal_move")
      expect { game.play!(second, coord: "6x1", color: "white") }.to raise_error(CommandRefused, "invalid_coord")
      expect { game.play!(second, coord: "1x2", color: "green") }.to raise_error(CommandRefused, "invalid_color")
    end

    it "refuse un coup qui reproduirait un motif déjà présent" do
      seed(game, "bb.../bb.../...../...../.....")
      game.play!(first, coord: "4x4", color: "black")
      game.play!(second, coord: "4x5", color: "black")
      game.play!(first, coord: "5x4", color: "black")
      expect { game.play!(second, coord: "5x5", color: "black") }.to raise_error(CommandRefused, "illegal_move")
    end

    it "rejette un envoi périmé grâce au rang attendu" do
      game.play!(first, coord: "1x1", color: "black", rank: 1)
      expect { game.play!(second, coord: "1x2", color: "black", rank: 1) }.to raise_error(CommandRefused, "stale")
      game.play!(second, coord: "1x2", color: "black", rank: 2)
    end

    it "termine la partie quand plus aucun motif ne peut être reproduit" do
      # Plateau de fin du livret, sans le pion 5x5.
      seed(game, "wwbww/bbbwb/bbwwb/wwbww/.bw..")
      expect(game.current_player).to eq(first)
      game.play!(first, coord: "5x5", color: "white")
      expect(game).to be_finished
      expect(game).to be_ended_by_score
      expect(game.blocked_coords).to contain_exactly("5x1", "5x4")
      score = game.score
      expect(score.values.sum).to eq(13)
      expected = score["host"] > score["guest"] ? "host" : "guest"
      expect(game.result).to eq(expected)
      expect { game.play!(second, coord: "5x1", color: "black") }.to raise_error(CommandRefused, "not_playing")
    end
  end

  describe "#score" do
    it "compte les motifs reproduits pour le propriétaire de la carte" do
      # Motif 0 (tout noir) : dans la main de l'hôte en distribution max.
      seed(game, "bb.../bb.../...../...../.....")
      expect(game.score).to eq("host" => 1, "guest" => 0)
    end
  end

  describe "#pass_hand!" do
    it "donne la main à l'adversaire avant le premier coup seulement" do
      expect { game.pass_hand!(second) }.to raise_error(CommandRefused, "not_first_player")
      game.pass_hand!(first)
      expect(game.current_player).to eq(second)
      game.play!(second, coord: "1x1", color: "black")
      expect { game.pass_hand!(second) }.to raise_error(CommandRefused, "game_started")
    end
  end

  describe "annulation" do
    before { game.play!(first, coord: "3x3", color: "black") }

    it "est demandée par celui qui vient de jouer et acceptée par l'adversaire" do
      expect { game.request_takeback!(second) }.to raise_error(CommandRefused, "not_last_mover")
      game.request_takeback!(first)
      expect { game.request_takeback!(first) }.to raise_error(CommandRefused, "takeback_pending")
      expect { game.answer_takeback!(first, accept: true) }.to raise_error(CommandRefused, "not_your_turn")
      game.answer_takeback!(second, accept: true)
      expect(game.moves).to be_empty
      expect(game.takeback_requested).to be(false)
      expect(game.current_player).to eq(first)
    end

    it "peut être refusée" do
      game.request_takeback!(first)
      game.answer_takeback!(second, accept: false)
      expect(game.moves.size).to eq(1)
      expect { game.answer_takeback!(second, accept: true) }.to raise_error(CommandRefused, "no_takeback_pending")
    end

    it "tombe quand l'adversaire joue" do
      game.request_takeback!(first)
      game.play!(second, coord: "1x1", color: "white")
      expect(game.takeback_requested).to be(false)
    end
  end

  describe "variante pion imposé" do
    let(:room) { create(:playing_room, imposed_color: true) }

    it "fait choisir la couleur d'ouverture par le second joueur, puis chacun impose la suivante" do
      expect(game).to be_awaiting_opening_color
      expect(game.current_player).to eq(second)
      expect { game.play!(first, coord: "1x1", color: "black") }.to raise_error(CommandRefused, "awaiting_opening_color")
      expect { game.choose_opening_color!(first, "white") }.to raise_error(CommandRefused, "not_your_turn")
      game.choose_opening_color!(second, "white")

      expect { game.play!(first, coord: "1x1", color: "black", next_color: "black") }.to raise_error(CommandRefused, "imposed_color")
      expect { game.play!(first, coord: "1x1", color: "white") }.to raise_error(CommandRefused, "next_color_required")
      game.play!(first, coord: "1x1", color: "white", next_color: "black")
      expect(game.required_color).to eq("black")
      expect { game.play!(second, coord: "1x2", color: "white", next_color: "white") }.to raise_error(CommandRefused, "imposed_color")
      game.play!(second, coord: "1x2", color: "black", next_color: "white")
    end

    it "laisse le choix libre quand la couleur imposée n'est plus jouable nulle part" do
      game.choose_opening_color!(second, "black")
      game.update!(opening_color: "white")
      allow(game).to receive(:board).and_return(Ascacou::Board.empty)
      expect(game.required_color).to eq("white")
      board = instance_double(Ascacou::Board, legal_moves: [ [ "1x1", :black ] ])
      allow(game).to receive(:board).and_return(board)
      expect(game.required_color).to be_nil
    end

    it "« laisser la main » remet le choix de la couleur d'ouverture à zéro" do
      game.choose_opening_color!(second, "black")
      game.pass_hand!(first)
      expect(game.opening_color).to be_nil
      expect(game.current_player).to eq(first)
    end
  end

  describe "distribution pioche" do
    let(:room) { create(:playing_room, deal_method: "draft") }

    it "fait piocher le second joueur en premier, en alternance, jusqu'à 8 + 8" do
      expect(game).to be_drafting
      expect(game.current_player).to eq(second)
      expect { game.pick!(first, card: 0, hand: "host") }.to raise_error(CommandRefused, "not_your_turn")
      game.pick!(second, card: 0, hand: "host")
      expect { game.pick!(first, card: 0, hand: "guest") }.to raise_error(CommandRefused, "card_taken")
      expect { game.play!(first, coord: "1x1", color: "black") }.to raise_error(CommandRefused, "not_playing")

      players = [ first, second ].cycle
      (1..7).each { |card| game.pick!(players.next, card:, hand: "host") }
      expect { game.pick!(players.peek, card: 8, hand: "host") }.to raise_error(CommandRefused, "hand_full")
      (8..15).each { |card| game.pick!(players.next, card:, hand: "guest") }

      expect(game).to be_playing
      expect(game.host_hand).to eq((0..7).to_a)
      expect(game.guest_hand).to eq((8..15).to_a)
      expect(game.picks.size).to eq(16)
      expect(game.current_player).to eq(first)
    end

    it "laisse piocher l'adversaire en premier avant la première carte, puis plus" do
      expect { game.pass_hand!(first) }.to raise_error(CommandRefused, "not_your_turn")
      expect { game.pass_hand!(second, to: first.id) }.to raise_error(CommandRefused, "invalid_player")
      game.pass_hand!(second, to: second.id)
      # Celui qui laisse piocher commencera la partie ; l'autre pioche en premier.
      expect(game.first_player).to eq(second)
      expect(game.current_player).to eq(first)
      game.pass_hand!(first) # et ainsi de suite, tant que personne n'a pioché
      expect(game.current_player).to eq(second)

      game.pick!(second, card: 0, hand: "host")
      expect { game.pass_hand!(first) }.to raise_error(CommandRefused, "game_started")
    end

    it "ne laisse plus la main au premier coup après la pioche" do
      players = [ second, first ].cycle
      (0..7).each { |card| game.pick!(players.next, card:, hand: "host") }
      (8..15).each { |card| game.pick!(players.next, card:, hand: "guest") }
      expect { game.pass_hand!(first) }.to raise_error(CommandRefused, "game_started")
    end
  end

  describe "fin anticipée" do
    it "abandon : l'adversaire gagne" do
      game.resign!(first)
      expect(game.result).to eq(room.role_of(second))
      expect(game).to be_ended_by_resign
      expect { game.resign!(second) }.to raise_error(CommandRefused, "game_finished")
    end

    it "victoire réclamée seulement si l'adversaire est absent" do
      now = Time.current
      RoomPresence.seen!(room, second, at: now - 30.seconds)
      expect { game.claim_victory!(first, now:) }.to raise_error(CommandRefused, "opponent_present")
      game.claim_victory!(first, now: now + RoomPresence::ABSENCE_DELAY)
      expect(game.result).to eq(room.role_of(first))
      expect(game).to be_ended_by_claim
    end
  end
end
