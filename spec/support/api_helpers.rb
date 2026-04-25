module ApiHelpers
  TOKEN = "test-token-123".freeze

  def auth_headers(token = TOKEN)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def stub_api_token(value = TOKEN)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("API_TOKEN").and_return(value)
  end

  def seed_plan(slug:, **overrides)
    Plan.find_or_create_by!(slug: slug) do |p|
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
