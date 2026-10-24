FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Joueur #{n}" }
  end
end
