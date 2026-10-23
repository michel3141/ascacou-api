# Distributions des 16 cartes-motifs entre les deux joueurs.
#
# Les distributions préparées sont celles du livret de règles ; chacune renvoie
# [main du premier joueur, main du second joueur].
module Ascacou
  module Deal
    CARDS = (0..15).to_a.freeze
    HAND_SIZE = 8

    PREPARED = {
      # Mêmes motifs, couleurs inversées.
      inverse: [ 0, 1, 2, 3, 5, 6, 7, 11 ],
      # Les deux jeux ont autant de pions noirs que de blancs.
      fifty: [ 2, 3, 5, 8, 9, 11, 12, 14 ],
      # Un jeu a un maximum de pions noirs, l'autre un maximum de blancs.
      max: [ 0, 1, 2, 3, 4, 5, 6, 8 ]
    }.transform_values(&:freeze).freeze

    # "draft" : distribution pioche, les mains sont constituées en cours de partie.
    METHODS = (%i[random draft] + PREPARED.keys).freeze

    module_function

    def call(method, random: Random)
      method = method.to_sym
      case method
      when :random then split(CARDS.shuffle(random:).first(HAND_SIZE))
      when :draft then [ [], [] ]
      when *PREPARED.keys then split(PREPARED.fetch(method))
      else raise ArgumentError, "distribution inconnue : #{method.inspect}"
      end
    end

    def split(first_hand)
      [ first_hand.sort, (CARDS - first_hand).sort ]
    end
  end
end
