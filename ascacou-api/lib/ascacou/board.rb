# Plateau 5x5 immuable.
#
# Les cases sont adressées par des coordonnées "LxC" (ligne, colonne de 1 à 5),
# comme dans le front. Un motif est la valeur (0..15) d'un carré 2x2 complet :
# bits HG HD BG BD, noir = 0, blanc = 1.
module Ascacou
  class Board
    SIZE = 5
    COLORS = %i[black white].freeze
    COORDS = (1..SIZE).flat_map { |row| (1..SIZE).map { |col| "#{row}x#{col}" } }.freeze

    # Les 16 carrés 2x2, chacun sous forme d'index [HG, HD, BG, BD].
    WINDOWS = (0...SIZE - 1).flat_map do |row|
      (0...SIZE - 1).map do |col|
        top_left = row * SIZE + col
        [ top_left, top_left + 1, top_left + SIZE, top_left + SIZE + 1 ].freeze
      end
    end.freeze

    attr_reader :cells

    def self.empty
      new(Array.new(SIZE * SIZE))
    end

    # moves : liste de [coord, color] dans l'ordre de jeu.
    def self.from_moves(moves)
      moves.reduce(empty) { |board, (coord, color)| board.place(coord, color) }
    end

    def self.index(coord)
      COORDS.index(coord.to_s) or raise ArgumentError, "coordonnée invalide : #{coord.inspect}"
    end

    def initialize(cells)
      @cells = cells.freeze
    end

    def [](coord)
      cells[self.class.index(coord)]
    end

    def empty?(coord)
      self[coord].nil?
    end

    def empty_coords
      COORDS.select { |coord| empty?(coord) }
    end

    def full?
      cells.none?(&:nil?)
    end

    def place(coord, color)
      color = color.to_sym
      raise ArgumentError, "couleur invalide : #{color.inspect}" unless COLORS.include?(color)
      raise ArgumentError, "case occupée : #{coord}" unless empty?(coord)

      self.class.new(cells.dup.tap { |copy| copy[self.class.index(coord)] = color })
    end

    # Motifs des carrés complets, doublons compris, dans l'ordre des carrés.
    def patterns
      WINDOWS.filter_map { |window| self.class.pattern_of(window.map { |i| cells[i] }) }
    end

    def realized_patterns
      patterns.uniq
    end

    def duplicates?
      patterns.size != realized_patterns.size
    end

    # Un coup est légal sur une case vide tant qu'aucun motif n'apparaît deux fois
    # (sauf en variante motif multiple).
    def legal?(coord, color, multiple: false)
      return false unless empty?(coord)
      return true if multiple

      !place(coord, color).duplicates?
    end

    def legal_moves(multiple: false)
      empty_coords.product(COLORS).select { |coord, color| legal?(coord, color, multiple:) }
    end

    # Case vide où ni noir ni blanc ne sont jouables : le « pion vert ».
    def blocked?(coord, multiple: false)
      empty?(coord) && COLORS.none? { |color| legal?(coord, color, multiple:) }
    end

    def blocked_coords(multiple: false)
      empty_coords.select { |coord| blocked?(coord, multiple:) }
    end

    # La partie se termine lorsque plus aucun nouveau motif ne peut être reproduit.
    #
    # Pour chaque carré incomplet, on essaie tous les remplissages de ses cases vides.
    # En règle de base, un remplissage sans doublon suffit : les états intermédiaires
    # n'ont que moins de carrés complets, donc aucun doublon non plus, quel que soit
    # l'ordre de pose. En motif multiple, il faut que le motif obtenu soit nouveau.
    def new_pattern_possible?(multiple: false)
      realized = realized_patterns
      WINDOWS.any? do |window|
        holes = window.select { |i| cells[i].nil? }
        next false if holes.empty?

        COLORS.repeated_permutation(holes.size).any? do |colors|
          filled = cells.dup
          holes.zip(colors) { |i, color| filled[i] = color }
          board = self.class.new(filled)
          if multiple
            !realized.include?(self.class.pattern_of(window.map { |i| filled[i] }))
          else
            !board.duplicates?
          end
        end
      end
    end

    def finished?(multiple: false)
      !new_pattern_possible?(multiple:)
    end

    def self.pattern_of(colors)
      return nil if colors.any?(&:nil?)

      colors.reduce(0) { |value, color| value * 2 + (color == :white ? 1 : 0) }
    end

    # Représentation compacte "bw.../..." par ligne, "." pour une case vide.
    def to_s
      cells.each_slice(SIZE).map { |row| row.map { |c| { black: "b", white: "w" }.fetch(c, ".") }.join }.join("/")
    end

    def self.parse(text)
      rows = text.split("/")
      raise ArgumentError, "plateau invalide : #{text}" unless rows.size == SIZE && rows.all? { |r| r.size == SIZE }

      new(rows.join.chars.map { |c| { "b" => :black, "w" => :white }[c] })
    end

    def ==(other)
      other.is_a?(Board) && cells == other.cells
    end
  end
end
