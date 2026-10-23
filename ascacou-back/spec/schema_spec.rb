require "rails_helper"

# Le schéma commité (doc/schema.json) est la référence de l'API publiée. Cette spec
# ne l'écrit pas : elle échoue si l'API courante casse la compatibilité avec lui,
# ce qui signale un changement à commiter en `feat!`.
RSpec.describe "Schéma de l'API" do
  it "reste compatible avec doc/schema.json" do
    check = Graphiti::Schema.check

    skip "doc/schema.json absent" if check.missing?
    expect(check.compatible?).to be(true), check.message
  end
end
