# Levée quand une commande de jeu est refusée (pas son tour, coup illégal…).
# Le code est stable et destiné au front, qui le traduit.
class CommandRefused < StandardError
  attr_reader :code

  def initialize(code)
    @code = code.to_sym
    super(@code.to_s)
  end
end
