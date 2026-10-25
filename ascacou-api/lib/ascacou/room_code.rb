# Mots des codes de salon : un mot de nature, un animal, un mot du ciel ou des sciences.
# Mots courants, au singulier, sans piège d'orthographe à la dictée.
# La forme « à plat » (sans accents) sert d'identifiant dans les URL.
module Ascacou
  module RoomCode
    WORDS = [
      # Nature
      %w[
        arbre forêt rivière montagne rocher falaise prairie savane volcan glacier océan plage dune
        vallée sentier jardin verger source cascade clairière orage nuage neige pluie brume tempête
        givre rose aurore oasis corail lagon banquise galet sable cristal bambou cèdre érable olivier
        sapin roseau fougère tulipe lavande jasmin muguet trèfle pivoine mimosa
      ].freeze,
      # Animaux
      %w[
        renard loup ours lion tigre lama guépard zèbre chèvre castor lapin biche sanglier loutre
        baleine dauphin requin tortue pieuvre méduse crabe saumon truite hibou aigle faucon corbeau
        colombe pélican toucan cigogne héron fourmi criquet escargot lézard crapaud serpent koala
        panda taupe bison morse otarie pingouin autruche antilope jaguar puma hermine
      ].freeze,
      # Ciel et sciences
      %w[
        étoile comète planète galaxie lune soleil orbite fusée astre météore nébuleuse éclipse
        horizon compas télescope prisme aimant atome laser radar signal spirale cercle triangle
        losange électron neutron molécule carbone hélium néon mercure vénus mars jupiter saturne
        neptune pluton orion solstice horloge sablier pendule levier globe loupe microscope cosmos
        sonde robot
      ].freeze
    ].freeze

    # Pas de point : Graphiti le prendrait pour une extension de format dans l'URL.
    SEPARATOR = "-".freeze
    MAX_ATTEMPTS = 20

    module_function

    # Tire un code au hasard (un mot par liste, en reprenant les listes au-delà de 3)
    # dont le bloc confirme qu'il est libre. Ajoute un mot si l'espace se remplit.
    def generate(size: WORDS.size, random: Random)
      MAX_ATTEMPTS.times do
        code = Array.new(size) { |i| flatten(WORDS[i % WORDS.size].sample(random:)) }.join(SEPARATOR)
        return code if !block_given? || yield(code)
      end
      generate(size: size + 1, random:) { |code| !block_given? || yield(code) }
    end

    # Forme saisie ou dictée (« Forêt Renard comète ») vers la forme stockée.
    def normalize(text)
      words = flatten_text(text.to_s).split(/[^a-z]+/).reject(&:empty?)
      words.join(SEPARATOR) if words.size >= WORDS.size
    end

    # Forme affichée, avec les accents : « forêt · renard · comète ».
    def label(code)
      code.to_s.split(SEPARATOR).each_with_index.map do |word, i|
        WORDS[i % WORDS.size].find { |candidate| flatten(candidate) == word } || word
      end.join(" · ")
    end

    def flatten(word)
      flatten_text(word).gsub(/[^a-z]/, "")
    end

    def flatten_text(text)
      text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
    end
  end
end
