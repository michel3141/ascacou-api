module Refusable
  private

  def refuse!(code)
    raise CommandRefused, code
  end
end
