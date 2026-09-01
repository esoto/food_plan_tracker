require "rails_helper"

RSpec.describe "FoodsController", type: :request do
  before { sign_in_as(create(:user, password: "password12345", food_tracking_enabled: true)) }

  it_behaves_like "food-gated page" do
    let(:make_request) { -> { get "/foods/new" } }
  end

  describe "GET /foods/new" do
    it "renders the form with the requested category preselected" do
      get "/foods/new?category=carb"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="carb" checked')
    end

    it "falls back to protein when category is missing or invalid" do
      get "/foods/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="protein" checked')

      get "/foods/new?category=destroy_all"
      expect(response.body).to include('value="protein" checked')
    end
  end

  describe "POST /foods" do
    let(:valid_params) do
      {
        food: {
          name: "Greek yogurt 5%",
          category: "protein",
          serving_grams: 100,
          kcal: 95,
          protein_g: 10,
          carbs_g: 4,
          fat_g: 5,
          notes: "plain, unsweetened"
        }
      }
    end

    it "creates a food and redirects to /exchanges?category=" do
      expect { post "/foods", params: valid_params }.to change(Food, :count).by(1)
      expect(response).to redirect_to(exchanges_path(category: "protein"))
      follow_redirect!
      expect(flash[:notice]).to eq("Added Greek yogurt 5%.")
    end

    it "re-renders the form on validation failure" do
      bad = valid_params.deep_merge(food: { name: "" })
      expect { post "/foods", params: bad }.not_to change(Food, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank")
    end
  end
end
