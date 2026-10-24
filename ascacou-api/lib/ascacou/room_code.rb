# Mots des codes de salon, repris de la première version de l'app.
# Chaque code est un mot de chaque liste ; la forme « à plat » (sans accents)
# sert d'identifiant dans les URL.
module Ascacou
  module RoomCode
    WORDS = [
      %w[
        aurore nébuleuse dorade saturne comète flèche vénus télescope licorne paon cassiopée vierge
        chien sculpteur étoile arbre triangle bélier pégase loup écu orion éclaircie ourse fleuve
        colline dauphin couronne brouillard nuage fourneau centaure lièvre grêle éridan poissons
        balance lac chevelure horloge terre ophiuchus octant lynx oiseau
      ].freeze,
      %w[
        halo étang soleil océan colombe uranus jupiter peintre giboulées compas cheval rocher
        château sagittaire plateau autel carène tonnerre forêt poisson mars serpent grue toucan
        baleine neige voiles capricorne satellite falaise titan coupe caillou constellation lune mer
        croix microscope sextant renard plante mercure cygne tempête galaxie
      ].freeze,
      %w[
        règle corbeau phénix pluton andromède girafe verseau massif sommet eau hercule indien éclair
        dôme astéroïde persée pluie taureau table buisson neptune scorpion caméléon vent poupe lyre
        lion bouvier mouche machine pic réticule volcan lézard dragon gémeaux mirage burin rivière
        cocher phobos boussole hydre montagne cancer
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

    # Forme saisie ou dictée (« Aurore Halo règle ») vers la forme stockée.
    def normalize(text)
      words = flatten_text(text.to_s).split(/[^a-z]+/).reject(&:empty?)
      words.join(SEPARATOR) if words.size >= WORDS.size
    end

    # Forme affichée, avec les accents : « aurore · halo · règle ».
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
