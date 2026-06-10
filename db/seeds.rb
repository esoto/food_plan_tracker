# =============================================================================
# Food Plan Tracker — Seed Data
# Source of truth for the nutritional plan. Idempotent (safe to re-run).
# =============================================================================

puts "Seeding foods…"

FOODS = [
  # --- Proteins (1 serving = 25g protein) ---
  { name: "Chicken breast, cooked",      category: :protein,   serving_grams: 80,  kcal: 132, protein_g: 25, carbs_g: 0,   fat_g: 3,   notes: "~110g raw" },
  { name: "Turkey breast, cooked",       category: :protein,   serving_grams: 85,  kcal: 125, protein_g: 25, carbs_g: 0,   fat_g: 2,   notes: nil },
  { name: "Lean beef 90/10",             category: :protein,   serving_grams: 95,  kcal: 194, protein_g: 25, carbs_g: 0,   fat_g: 10,  notes: "cooked" },
  { name: "Salmon, baked",               category: :protein,   serving_grams: 100, kcal: 206, protein_g: 25, carbs_g: 0,   fat_g: 12,  notes: nil },
  { name: "Tuna, canned in water",       category: :protein,   serving_grams: 100, kcal: 116, protein_g: 25, carbs_g: 0,   fat_g: 1,   notes: nil },
  { name: "Tilapia / sea bass",          category: :protein,   serving_grams: 110, kcal: 140, protein_g: 25, carbs_g: 0,   fat_g: 3,   notes: "cooked" },
  { name: "Shrimp, cooked",              category: :protein,   serving_grams: 120, kcal: 125, protein_g: 25, carbs_g: 0,   fat_g: 1,   notes: nil },
  { name: "Whole eggs",                  category: :protein,   serving_grams: 200, kcal: 310, protein_g: 25, carbs_g: 2,   fat_g: 22,  notes: "4 large" },
  { name: "Egg whites",                  category: :protein,   serving_grams: 230, kcal: 120, protein_g: 25, carbs_g: 2,   fat_g: 0,   notes: "~7 whites" },
  { name: "Greek yogurt 0%",             category: :protein,   serving_grams: 250, kcal: 148, protein_g: 25, carbs_g: 9,   fat_g: 0,   notes: nil },
  { name: "Whole-milk kefir",            category: :protein,   serving_grams: 700, kcal: 420, protein_g: 25, carbs_g: 35,  fat_g: 22,  notes: "daily" },
  { name: "Cottage cheese 2%",           category: :protein,   serving_grams: 200, kcal: 170, protein_g: 25, carbs_g: 7,   fat_g: 4,   notes: "pre-sleep casein" },
  { name: "Whey isolate",                category: :protein,   serving_grams: 28,  kcal: 110, protein_g: 25, carbs_g: 2,   fat_g: 0,   notes: "1 scoop" },
  { name: "Micellar casein",             category: :protein,   serving_grams: 30,  kcal: 115, protein_g: 25, carbs_g: 3,   fat_g: 0,   notes: "slow-release" },
  { name: "Lentils, cooked",             category: :protein,   serving_grams: 280, kcal: 325, protein_g: 25, carbs_g: 56,  fat_g: 1,   notes: nil },
  { name: "Firm tofu",                   category: :protein,   serving_grams: 180, kcal: 260, protein_g: 25, carbs_g: 6,   fat_g: 15,  notes: nil },

  # --- Carbs (1 serving = 30g carbs) ---
  { name: "Raw oats",                    category: :carb, serving_grams: 45,  kcal: 170, protein_g: 6,  carbs_g: 30, fat_g: 3,  notes: nil },
  { name: "Brown rice, cooked",          category: :carb, serving_grams: 120, kcal: 140, protein_g: 3,  carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Quinoa, cooked",              category: :carb, serving_grams: 135, kcal: 160, protein_g: 6,  carbs_g: 30, fat_g: 2,  notes: nil },
  { name: "Whole-wheat pasta, cooked",   category: :carb, serving_grams: 115, kcal: 150, protein_g: 6,  carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Sweet potato, roasted",       category: :carb, serving_grams: 150, kcal: 130, protein_g: 2,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Potato, boiled",              category: :carb, serving_grams: 175, kcal: 135, protein_g: 3,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Green plantain, cooked",      category: :carb, serving_grams: 135, kcal: 155, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Corn tortillas",              category: :carb, serving_grams: 60,  kcal: 140, protein_g: 4,  carbs_g: 30, fat_g: 2,  notes: "2 units" },
  { name: "Sprouted whole-grain bread",  category: :carb, serving_grams: 80,  kcal: 150, protein_g: 6,  carbs_g: 30, fat_g: 2,  notes: "2 slices" },
  { name: "Banana",                      category: :carb, serving_grams: 135, kcal: 120, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: "1 large" },
  { name: "Apple",                       category: :carb, serving_grams: 230, kcal: 125, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: "1 large" },
  { name: "Mixed berries",               category: :carb, serving_grams: 220, kcal: 115, protein_g: 2,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Mango",                       category: :carb, serving_grams: 180, kcal: 108, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Papaya",                      category: :carb, serving_grams: 250, kcal: 108, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Black beans, cooked",         category: :carb, serving_grams: 140, kcal: 190, protein_g: 10, carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Chickpeas, cooked",           category: :carb, serving_grams: 115, kcal: 190, protein_g: 9,  carbs_g: 30, fat_g: 3,  notes: nil },

  # --- Fats (1 serving = 10g fat) ---
  { name: "Extra-virgin olive oil",      category: :fat, serving_grams: 11, kcal: 100, protein_g: 0, carbs_g: 0,  fat_g: 10, notes: "1 tbsp" },
  { name: "Avocado",                     category: :fat, serving_grams: 60, kcal: 95,  protein_g: 1, carbs_g: 5,  fat_g: 10, notes: nil },
  { name: "Almonds",                     category: :fat, serving_grams: 18, kcal: 110, protein_g: 4, carbs_g: 4,  fat_g: 10, notes: nil },
  { name: "Walnuts",                     category: :fat, serving_grams: 15, kcal: 100, protein_g: 2, carbs_g: 2,  fat_g: 10, notes: "~7 halves" },
  { name: "Pistachios",                  category: :fat, serving_grams: 20, kcal: 115, protein_g: 4, carbs_g: 5,  fat_g: 10, notes: nil },
  { name: "Natural peanuts",             category: :fat, serving_grams: 20, kcal: 115, protein_g: 5, carbs_g: 4,  fat_g: 10, notes: nil },
  { name: "Chia seeds",                  category: :fat, serving_grams: 20, kcal: 95,  protein_g: 3, carbs_g: 8,  fat_g: 10, notes: "~1.5 tbsp" },
  { name: "Ground flaxseed",             category: :fat, serving_grams: 25, kcal: 135, protein_g: 5, carbs_g: 7,  fat_g: 10, notes: nil },
  { name: "Pumpkin seeds",               category: :fat, serving_grams: 20, kcal: 125, protein_g: 6, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Almond butter",               category: :fat, serving_grams: 15, kcal: 100, protein_g: 3, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Peanut butter",               category: :fat, serving_grams: 15, kcal: 100, protein_g: 4, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Olives",                      category: :fat, serving_grams: 45, kcal: 55,  protein_g: 0, carbs_g: 2,  fat_g: 10, notes: "~10 olives" },
  { name: "Shredded coconut",            category: :fat, serving_grams: 15, kcal: 100, protein_g: 1, carbs_g: 4,  fat_g: 10, notes: nil },

  # --- Vegetables (free consumption, reference portions per 100g) ---
  { name: "Spinach",         category: :vegetable, serving_grams: 100, kcal: 23,  protein_g: 3, carbs_g: 4,  fat_g: 0, notes: "free" },
  { name: "Kale",            category: :vegetable, serving_grams: 100, kcal: 35,  protein_g: 3, carbs_g: 7,  fat_g: 1, notes: "free" },
  { name: "Broccoli",        category: :vegetable, serving_grams: 100, kcal: 34,  protein_g: 3, carbs_g: 7,  fat_g: 0, notes: "free" },
  { name: "Cauliflower",     category: :vegetable, serving_grams: 100, kcal: 25,  protein_g: 2, carbs_g: 5,  fat_g: 0, notes: "free" },
  { name: "Asparagus",       category: :vegetable, serving_grams: 100, kcal: 20,  protein_g: 2, carbs_g: 4,  fat_g: 0, notes: "free" },
  { name: "Tomato",          category: :vegetable, serving_grams: 100, kcal: 18,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "free" },
  { name: "Cucumber",        category: :vegetable, serving_grams: 100, kcal: 16,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "free" },
  { name: "Bell pepper",     category: :vegetable, serving_grams: 100, kcal: 31,  protein_g: 1, carbs_g: 6,  fat_g: 0, notes: "free" },
  { name: "Carrot",          category: :vegetable, serving_grams: 100, kcal: 41,  protein_g: 1, carbs_g: 10, fat_g: 0, notes: "free" },
  { name: "Onion",           category: :vegetable, serving_grams: 100, kcal: 40,  protein_g: 1, carbs_g: 9,  fat_g: 0, notes: "free" },
  { name: "Zucchini",        category: :vegetable, serving_grams: 100, kcal: 17,  protein_g: 1, carbs_g: 3,  fat_g: 0, notes: "free" },
  { name: "Kimchi",          category: :vegetable, serving_grams: 100, kcal: 15,  protein_g: 1, carbs_g: 2,  fat_g: 0, notes: "fermented" },
  { name: "Sauerkraut",      category: :vegetable, serving_grams: 100, kcal: 19,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "fermented" }
].freeze

FOODS.each do |attrs|
  food = Food.find_or_initialize_by(name: attrs[:name], category: attrs[:category])
  food.assign_attributes(
    serving_grams: attrs[:serving_grams],
    kcal:          attrs[:kcal],
    protein_g:     attrs[:protein_g],
    carbs_g:       attrs[:carbs_g],
    fat_g:         attrs[:fat_g],
    notes:         attrs[:notes]
  )
  food.save!
end

puts "  #{Food.count} foods (#{Food.protein.count} protein, #{Food.carb.count} carb, #{Food.fat.count} fat, #{Food.vegetable.count} vegetable)"

# -----------------------------------------------------------------------------
# Default user (must be created before any tenantable records)
# -----------------------------------------------------------------------------

puts "Seeding user…"

email = ENV.fetch("ADMIN_EMAIL", "esoto074@gmail.com")
password =
  if Rails.env.production?
    # No default in production — fail loudly if the deploy forgot to set the env var,
    # rather than silently creating an account with a known credential.
    ENV.fetch("ADMIN_PASSWORD") { raise "ADMIN_PASSWORD must be set in production" }
  else
    ENV.fetch("ADMIN_PASSWORD", "changeme-now-please")
  end

user = User.find_or_initialize_by(email_address: email)
user.password = password if user.new_record?
user.save!

puts "  user: #{user.email_address}"

session = Session.create!(user: user, user_agent: "seeds", ip_address: "127.0.0.1")
Current.set(session: session) do
# -----------------------------------------------------------------------------
# Plans + Meals + MealItems
#
# Three day types:
#   Exercise day — CrossFit (Mon/Wed/Fri). Highest carbs.
#   Active day   — walks / moderate activity (Tue/Thu). Middle carbs.
#   Rest day     — full rest (Sat/Sun). Lowest carbs, highest fat.
# -----------------------------------------------------------------------------

puts "Seeding plans and meals…"

# Wipe old plans only if we're changing the slug layout. Using find_or_initialize
# by slug means old "crossfit" plans stick around. If you see extras, run
# `Plan.where(slug: "crossfit").destroy_all` in the console.

exercise = Plan.find_or_initialize_by(slug: Plan::EXERCISE_SLUG, user: user)
exercise.assign_attributes(
  name: "Exercise day",
  target_kcal: 2100,
  target_protein_g: 180,
  target_carbs_g: 215,
  target_fat_g: 75
)
exercise.save!

active = Plan.find_or_initialize_by(slug: Plan::ACTIVE_SLUG, user: user)
active.assign_attributes(
  name: "Active day",
  target_kcal: 2075,
  target_protein_g: 180,
  target_carbs_g: 180,
  target_fat_g: 80
)
active.save!

rest = Plan.find_or_initialize_by(slug: Plan::REST_SLUG, user: user)
rest.assign_attributes(
  name: "Rest day",
  target_kcal: 2050,
  target_protein_g: 180,
  target_carbs_g: 160,
  target_fat_g: 85
)
rest.save!

# Remove legacy plan slugs if they still exist from earlier seeds.
legacy_plans = Plan.for_user(user).where.not(slug: [ Plan::EXERCISE_SLUG, Plan::ACTIVE_SLUG, Plan::REST_SLUG ])
if legacy_plans.exists?
  # Reassign any daily logs that still point at a legacy plan so we don't trip
  # the restrict_with_error on destroy.
  DailyLog.where(plan_id: legacy_plans.ids).update_all(plan_id: exercise.id)
  legacy_plans.destroy_all
end

def find_food(name)
  Food.find_by!(name: name)
end

def upsert_meal(plan:, position:, name:, time:, kcal:, protein:, carbs:, fat:, items:, user:)
  meal = plan.meals.find_or_initialize_by(position: position, user: user)
  hour, minute = time.split(":").map(&:to_i)
  meal.assign_attributes(
    name: name,
    scheduled_time: Time.utc(2000, 1, 1, hour, minute),
    target_kcal: kcal,
    target_protein_g: protein,
    target_carbs_g: carbs,
    target_fat_g: fat
  )
  meal.save!

  meal.meal_items.destroy_all
  items.each_with_index do |(food_name, qty), idx|
    meal.meal_items.create!(food: find_food(food_name), quantity_grams: qty, display_order: idx, user: user)
  end
  meal
end

# --- Exercise day meals (CrossFit days) ---
upsert_meal(user: user, plan: exercise, position: 1, name: "Breakfast", time: "07:00",
  kcal: 460, protein: 40, carbs: 50, fat: 14,
  items: [
    [ "Whole eggs", 150 ],
    [ "Egg whites", 100 ],
    [ "Raw oats", 40 ],
    [ "Greek yogurt 0%", 200 ],
    [ "Mixed berries", 80 ],
    [ "Ground flaxseed", 12 ]
  ]
)

upsert_meal(user: user, plan: exercise, position: 2, name: "Lunch", time: "12:00",
  kcal: 525, protein: 45, carbs: 65, fat: 15,
  items: [
    [ "Chicken breast, cooked", 150 ],
    [ "Brown rice, cooked", 180 ],
    [ "Black beans, cooked", 100 ],
    [ "Avocado", 60 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Kimchi", 30 ]
  ]
)

upsert_meal(user: user, plan: exercise, position: 3, name: "Pre-workout", time: "15:30",
  kcal: 380, protein: 30, carbs: 55, fat: 6,
  items: [
    [ "Whey isolate", 30 ],
    [ "Banana", 135 ],
    [ "Greek yogurt 0%", 150 ],
    [ "Almonds", 15 ]
  ]
)

upsert_meal(user: user, plan: exercise, position: 4, name: "Post-workout dinner", time: "19:30",
  kcal: 525, protein: 40, carbs: 50, fat: 18,
  items: [
    [ "Salmon, baked", 150 ],
    [ "Sweet potato, roasted", 200 ],
    [ "Broccoli", 150 ],
    [ "Asparagus", 100 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Walnuts", 15 ],
    [ "Sauerkraut", 30 ]
  ]
)

upsert_meal(user: user, plan: exercise, position: 5, name: "Pre-sleep", time: "22:30",
  kcal: 210, protein: 35, carbs: 8, fat: 5,
  items: [
    [ "Cottage cheese 2%", 200 ],
    [ "Micellar casein", 15 ]
  ]
)

# --- Active day meals (walks / moderate activity) ---
upsert_meal(user: user, plan: active, position: 1, name: "Breakfast", time: "07:30",
  kcal: 450, protein: 40, carbs: 45, fat: 15,
  items: [
    [ "Whole eggs", 150 ],
    [ "Egg whites", 100 ],
    [ "Raw oats", 35 ],
    [ "Greek yogurt 0%", 200 ],
    [ "Mixed berries", 80 ],
    [ "Almonds", 15 ]
  ]
)

upsert_meal(user: user, plan: active, position: 2, name: "Lunch", time: "12:30",
  kcal: 510, protein: 45, carbs: 55, fat: 16,
  items: [
    [ "Turkey breast, cooked", 170 ],
    [ "Quinoa, cooked", 135 ],
    [ "Black beans, cooked", 70 ],
    [ "Avocado", 60 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Kimchi", 30 ]
  ]
)

upsert_meal(user: user, plan: active, position: 3, name: "Snack", time: "16:00",
  kcal: 360, protein: 30, carbs: 40, fat: 12,
  items: [
    [ "Greek yogurt 0%", 250 ],
    [ "Banana", 100 ],
    [ "Almonds", 20 ]
  ]
)

upsert_meal(user: user, plan: active, position: 4, name: "Dinner", time: "19:30",
  kcal: 530, protein: 40, carbs: 30, fat: 24,
  items: [
    [ "Salmon, baked", 140 ],
    [ "Sweet potato, roasted", 130 ],
    [ "Broccoli", 150 ],
    [ "Asparagus", 100 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Walnuts", 15 ],
    [ "Avocado", 30 ]
  ]
)

upsert_meal(user: user, plan: active, position: 5, name: "Pre-sleep", time: "22:30",
  kcal: 225, protein: 35, carbs: 10, fat: 6,
  items: [
    [ "Cottage cheese 2%", 200 ],
    [ "Micellar casein", 15 ]
  ]
)

# --- Rest day meals ---
upsert_meal(user: user, plan: rest, position: 1, name: "Breakfast", time: "07:30",
  kcal: 440, protein: 40, carbs: 35, fat: 16,
  items: [
    [ "Whole eggs", 150 ],
    [ "Egg whites", 100 ],
    [ "Raw oats", 30 ],
    [ "Greek yogurt 0%", 200 ],
    [ "Mixed berries", 60 ],
    [ "Almonds", 18 ]
  ]
)

upsert_meal(user: user, plan: rest, position: 2, name: "Lunch", time: "12:30",
  kcal: 510, protein: 45, carbs: 50, fat: 17,
  items: [
    [ "Turkey breast, cooked", 170 ],
    [ "Quinoa, cooked", 135 ],
    [ "Avocado", 60 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Kimchi", 30 ]
  ]
)

upsert_meal(user: user, plan: rest, position: 3, name: "Snack", time: "16:00",
  kcal: 340, protein: 30, carbs: 30, fat: 12,
  items: [
    [ "Greek yogurt 0%", 250 ],
    [ "Apple", 150 ],
    [ "Almonds", 20 ]
  ]
)

upsert_meal(user: user, plan: rest, position: 4, name: "Dinner", time: "19:30",
  kcal: 540, protein: 40, carbs: 35, fat: 25,
  items: [
    [ "Salmon, baked", 140 ],
    [ "Potato, boiled", 150 ],
    [ "Broccoli", 150 ],
    [ "Asparagus", 100 ],
    [ "Extra-virgin olive oil", 11 ],
    [ "Walnuts", 15 ],
    [ "Avocado", 30 ]
  ]
)

upsert_meal(user: user, plan: rest, position: 5, name: "Pre-sleep", time: "22:30",
  kcal: 220, protein: 35, carbs: 10, fat: 6,
  items: [
    [ "Cottage cheese 2%", 200 ],
    [ "Micellar casein", 15 ]
  ]
)

puts "  #{Plan.count} plans, #{Meal.count} meals, #{MealItem.count} meal items"

# Remove any seeded foods (created_by_user_id = nil) that are no longer in the
# canonical list (e.g. old Spanish names). User-created foods (created_by_user_id
# present) are never pruned. Meal items have already been replaced above, so
# stale seeded foods are orphans. Note: foods are seeded above (lines 76-87)
# before Current.set, so canonical foods have created_by_user_id = nil.
allowed_food_keys = FOODS.map { |f| [ f[:name], Food.categories[f[:category]] ] }
Food.seeded.find_each do |food|
  food.destroy unless allowed_food_keys.include?([ food.name, food.category_before_type_cast ])
end
puts "  pruned stale foods, now #{Food.count} total"

# -----------------------------------------------------------------------------
# Supplements + schedule
# -----------------------------------------------------------------------------

puts "Seeding supplements…"

SUPPLEMENTS = [
  { name: "Vitamin D3",                dose: "3,000 IU",          notes: "with fat",                               critical: false, slot: :morning,   position: 1 },
  { name: "Vitamin K2 MK-7",           dose: "180 µg",            notes: "with fat",                               critical: false, slot: :morning,   position: 2 },
  { name: "Omega-3 rTG (AM)",          dose: "1g EPA+DHA",        notes: "with breakfast",                         critical: false, slot: :morning,   position: 3 },
  { name: "Curcumin Meriva (AM)",      dose: "500 mg",            notes: "anti-inflammatory",                      critical: false, slot: :morning,   position: 4 },
  { name: "Mind Lab Pro",              dose: "2 capsules",        notes: "Lion's Mane + L-Theanine",               critical: false, slot: :morning,   position: 5 },

  { name: "Psyllium",                  dose: "10 g in 300 ml water", notes: "15 min before lunch",                 critical: false, slot: :pre_lunch, position: 1 },

  { name: "Fibrotina (Fenofibrate)",   dose: "per Rx",            notes: "with fatty dinner — critical",
    critical: true, slot: :dinner, position: 1,
    contraindications: "No red yeast rice · No high-dose niacin · No berberine" },
  { name: "Omega-3 rTG (PM)",          dose: "1g EPA+DHA",        notes: "with dinner (daily total 2g)",           critical: false, slot: :dinner,    position: 2 },
  { name: "CoQ10 Ubiquinol",           dose: "200 mg",            notes: "with fat",                               critical: false, slot: :dinner,    position: 3 },
  { name: "Curcumin Meriva (PM)",      dose: "500 mg",            notes: "daily total 1g",                         critical: false, slot: :dinner,    position: 4 },
  { name: "Creatine monohydrate",      dose: "5 g",               notes: "in water",                               critical: false, slot: :dinner,    position: 5 },

  { name: "Magnesium glycinate",       dose: "400 mg",            notes: "improves sleep",                         critical: false, slot: :pre_sleep, position: 1 },
  { name: "L-Theanine",                dose: "200 mg",            notes: "skip if already in Mind Lab Pro",        critical: false, slot: :pre_sleep, position: 2 }
].freeze

# Remove any supplements left over from a previous Spanish seed. Scoped to
# kept (non-archived) records so user-archived custom supplements aren't
# obliterated on re-seed — their completion history would go with them.
allowed_names = SUPPLEMENTS.map { |s| s[:name] }
Supplement.for_user(user).kept.where.not(name: allowed_names).destroy_all

SUPPLEMENTS.each do |attrs|
  supplement = Supplement.find_or_initialize_by(name: attrs[:name], user: user)
  supplement.assign_attributes(
    dose: attrs[:dose],
    notes: attrs[:notes],
    critical: attrs[:critical],
    contraindications: attrs[:contraindications]
  )
  supplement.save!

  schedule = supplement.supplement_schedules.first_or_initialize(user: user)
  schedule.time_slot = attrs[:slot]
  schedule.position  = attrs[:position]
  schedule.save!
end

puts "  #{Supplement.count} supplements, #{SupplementSchedule.count} schedule entries"

# -----------------------------------------------------------------------------
# Checklist templates
# -----------------------------------------------------------------------------

puts "Seeding checklist templates…"

CHECKLIST = [
  { label: "Drank 3L of water",                     description: "Daily hydration",                         icon: "💧" },
  { label: "Took Fibrotina with dinner",            description: "Critical — with fat at 7:30 PM",          icon: "💊" },
  { label: "180g of protein consumed",              description: "5 meals × 30-45g",                        icon: "🥩" },
  { label: "At least 500g of vegetables",           description: "Fiber and micronutrients",                icon: "🥦" },
  { label: "Kefir + 1 fermented food",              description: "Gut health",                              icon: "🥛" },
  { label: "Morning supplements complete",          description: "D3, K2, Omega-3, Curcumin, MLP",         icon: "☀️" },
  { label: "Evening supplements complete",          description: "Omega-3, CoQ10, Creatine, Curcumin",     icon: "🌙" },
  { label: "Pre-sleep casein",                      description: "Overnight anabolic window",               icon: "🛌" },
  { label: "7-8 hours of sleep (previous night)",   description: "Critical to lower CRP",                   icon: "😴" },
  { label: "30+ min of physical activity",          description: "CrossFit or walk",                        icon: "💪" },
  { label: "2-3 tbsp EVOO",                         description: "MUFA — HDL and anti-inflammatory",        icon: "🫒" },
  { label: "Psyllium 10g",                          description: "Soluble fiber — 15 min pre-lunch",        icon: "🌾" }
].freeze

# Remove stale Spanish-labeled templates if present. Scoped to kept rows so
# user-archived custom habits aren't obliterated on re-seed (their completion
# history would go with them).
ChecklistTemplate.for_user(user).kept.where.not(label: CHECKLIST.map { |c| c[:label] }).destroy_all

CHECKLIST.each_with_index do |attrs, idx|
  template = ChecklistTemplate.find_or_initialize_by(label: attrs[:label], user: user)
  template.description = attrs[:description]
  template.icon        = attrs[:icon]
  template.position    = idx + 1
  template.save!
end

puts "  #{ChecklistTemplate.count} checklist templates"

# -----------------------------------------------------------------------------
# Goals (6 biomarkers)
# -----------------------------------------------------------------------------

puts "Seeding goals…"

GOALS = [
  { metric: :weight_kg,      display_name: "Weight",            starting_value: 93.84, target_value: 87,   unit: "kg",    direction: :down     },
  { metric: :body_fat_pct,   display_name: "Body fat",          starting_value: 26.1,  target_value: 19,   unit: "%",     direction: :down     },
  { metric: :hdl,            display_name: "HDL",               starting_value: 39,    target_value: 45,   unit: "mg/dL", direction: :up       },
  { metric: :hs_crp,         display_name: "hs-CRP",            starting_value: 5.2,   target_value: 3,    unit: "mg/L",  direction: :down     },
  { metric: :visceral_fat,   display_name: "Visceral fat",      starting_value: 12,    target_value: 9,    unit: "level", direction: :down     },
  { metric: :muscle_mass_kg, display_name: "Muscle mass",       starting_value: 67,    target_value: 67,   unit: "kg",    direction: :preserve }
].freeze

GOALS.each do |attrs|
  goal = Goal.find_or_initialize_by(metric: attrs[:metric], user: user)
  goal.assign_attributes(attrs)
  goal.save!
end

puts "  #{Goal.count} goals"
end # Current.set(user: user)

puts "Done."
