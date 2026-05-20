module ApiHelpers
  TOKEN = "test-token-123".freeze

  def auth_headers(token = TOKEN)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  # Creates a real ApiToken row with a known plaintext so request specs can
  # send `Bearer <TOKEN>` and exercise the actual digest lookup. Idempotent
  # across examples in the same example group.
  def stub_api_token(value = TOKEN)
    ApiToken.where(name: "spec").destroy_all
    user = Current.user || User.first || create(:user)
    ApiToken.create!(name: "spec", token: value, user: user)
  end

  def seed_plan(slug:, **overrides)
    user = Current.user || User.first || create(:user)
    Plan.find_or_create_by!(slug: slug, user: user) do |p|
      p.name = slug.titleize + " day"
      p.target_kcal = overrides[:target_kcal] || 2000
      p.target_protein_g = overrides[:target_protein_g] || 180
      p.target_carbs_g = overrides[:target_carbs_g] || 180
      p.target_fat_g = overrides[:target_fat_g] || 70
    end
  end

  def seed_food(name:, **overrides)
    Food.find_or_create_by!(name: name, category: overrides[:category] || "protein") do |f|
      f.serving_grams = overrides[:serving_grams] || 100
      f.kcal = overrides[:kcal] || 165
      f.protein_g = overrides[:protein_g] || 31
      f.carbs_g = overrides[:carbs_g] || 0
      f.fat_g = overrides[:fat_g] || 3.6
    end
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
