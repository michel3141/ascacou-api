FactoryBot.define do
  factory :room do
    host factory: :user
    deal_method { "max" }

    # Salon complet, première partie lancée.
    factory :playing_room do
      transient do
        random { Random.new(1) }
      end

      after(:create) do |room, context|
        room.join!(create(:user), random: context.random)
      end
    end
  end
end
