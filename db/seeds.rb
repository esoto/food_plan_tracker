# =============================================================================
# Food Plan Tracker — Seed Data
# Source of truth for the nutritional plan. Idempotent (safe to re-run).
# =============================================================================

puts "Seeding foods…"

FOODS = [
  # --- Proteins (1 serving = 25g protein) ---
  { name: "Pechuga de pollo cocida",   category: :protein,   serving_grams: 80,  kcal: 132, protein_g: 25, carbs_g: 0,   fat_g: 3,   notes: "110g crudo" },
  { name: "Pechuga de pavo cocida",    category: :protein,   serving_grams: 85,  kcal: 125, protein_g: 25, carbs_g: 0,   fat_g: 2,   notes: nil },
  { name: "Carne res 90/10",           category: :protein,   serving_grams: 95,  kcal: 194, protein_g: 25, carbs_g: 0,   fat_g: 10,  notes: "cocida" },
  { name: "Salmón al horno",           category: :protein,   serving_grams: 100, kcal: 206, protein_g: 25, carbs_g: 0,   fat_g: 12,  notes: nil },
  { name: "Atún enlatado en agua",     category: :protein,   serving_grams: 100, kcal: 116, protein_g: 25, carbs_g: 0,   fat_g: 1,   notes: nil },
  { name: "Tilapia / Corvina",         category: :protein,   serving_grams: 110, kcal: 140, protein_g: 25, carbs_g: 0,   fat_g: 3,   notes: "cocido" },
  { name: "Camarones cocidos",         category: :protein,   serving_grams: 120, kcal: 125, protein_g: 25, carbs_g: 0,   fat_g: 1,   notes: nil },
  { name: "Huevos enteros",            category: :protein,   serving_grams: 200, kcal: 310, protein_g: 25, carbs_g: 2,   fat_g: 22,  notes: "4 unidades grandes" },
  { name: "Claras de huevo",           category: :protein,   serving_grams: 230, kcal: 120, protein_g: 25, carbs_g: 2,   fat_g: 0,   notes: "7 unidades" },
  { name: "Yogur griego 0%",           category: :protein,   serving_grams: 250, kcal: 148, protein_g: 25, carbs_g: 9,   fat_g: 0,   notes: nil },
  { name: "Kefir de leche entera",     category: :protein,   serving_grams: 700, kcal: 420, protein_g: 25, carbs_g: 35,  fat_g: 22,  notes: "consumo diario" },
  { name: "Cottage cheese 2%",         category: :protein,   serving_grams: 200, kcal: 170, protein_g: 25, carbs_g: 7,   fat_g: 4,   notes: "casein pre-sueño" },
  { name: "Whey isolate",              category: :protein,   serving_grams: 28,  kcal: 110, protein_g: 25, carbs_g: 2,   fat_g: 0,   notes: "1 scoop" },
  { name: "Caseína micelar",           category: :protein,   serving_grams: 30,  kcal: 115, protein_g: 25, carbs_g: 3,   fat_g: 0,   notes: "slow-release" },
  { name: "Lentejas cocidas",          category: :protein,   serving_grams: 280, kcal: 325, protein_g: 25, carbs_g: 56,  fat_g: 1,   notes: nil },
  { name: "Tofu firme",                category: :protein,   serving_grams: 180, kcal: 260, protein_g: 25, carbs_g: 6,   fat_g: 15,  notes: nil },

  # --- Carbs (1 serving = 30g carbs) ---
  { name: "Avena cruda",                category: :carb, serving_grams: 45,  kcal: 170, protein_g: 6,  carbs_g: 30, fat_g: 3,  notes: nil },
  { name: "Arroz integral cocido",      category: :carb, serving_grams: 120, kcal: 140, protein_g: 3,  carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Quinoa cocida",              category: :carb, serving_grams: 135, kcal: 160, protein_g: 6,  carbs_g: 30, fat_g: 2,  notes: nil },
  { name: "Pasta integral cocida",      category: :carb, serving_grams: 115, kcal: 150, protein_g: 6,  carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Batata asada",               category: :carb, serving_grams: 150, kcal: 130, protein_g: 2,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Papa hervida",               category: :carb, serving_grams: 175, kcal: 135, protein_g: 3,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Plátano verde cocido",       category: :carb, serving_grams: 135, kcal: 155, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Tortilla de maíz",           category: :carb, serving_grams: 60,  kcal: 140, protein_g: 4,  carbs_g: 30, fat_g: 2,  notes: "2 unidades" },
  { name: "Pan integral germinado",     category: :carb, serving_grams: 80,  kcal: 150, protein_g: 6,  carbs_g: 30, fat_g: 2,  notes: "2 rebanadas" },
  { name: "Banano",                     category: :carb, serving_grams: 135, kcal: 120, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: "1 grande" },
  { name: "Manzana",                    category: :carb, serving_grams: 230, kcal: 125, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: "1 grande" },
  { name: "Frutos rojos",               category: :carb, serving_grams: 220, kcal: 115, protein_g: 2,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Mango",                      category: :carb, serving_grams: 180, kcal: 108, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Papaya",                     category: :carb, serving_grams: 250, kcal: 108, protein_g: 1,  carbs_g: 30, fat_g: 0,  notes: nil },
  { name: "Frijoles negros cocidos",    category: :carb, serving_grams: 140, kcal: 190, protein_g: 10, carbs_g: 30, fat_g: 1,  notes: nil },
  { name: "Garbanzos cocidos",          category: :carb, serving_grams: 115, kcal: 190, protein_g: 9,  carbs_g: 30, fat_g: 3,  notes: nil },

  # --- Fats (1 serving = 10g fat) ---
  { name: "AOVE (aceite de oliva virgen extra)", category: :fat, serving_grams: 11, kcal: 100, protein_g: 0, carbs_g: 0,  fat_g: 10, notes: "1 cda" },
  { name: "Aguacate",                             category: :fat, serving_grams: 60, kcal: 95,  protein_g: 1, carbs_g: 5,  fat_g: 10, notes: nil },
  { name: "Almendras",                            category: :fat, serving_grams: 18, kcal: 110, protein_g: 4, carbs_g: 4,  fat_g: 10, notes: nil },
  { name: "Nueces",                               category: :fat, serving_grams: 15, kcal: 100, protein_g: 2, carbs_g: 2,  fat_g: 10, notes: "7 mitades" },
  { name: "Pistachos",                            category: :fat, serving_grams: 20, kcal: 115, protein_g: 4, carbs_g: 5,  fat_g: 10, notes: nil },
  { name: "Maní natural",                         category: :fat, serving_grams: 20, kcal: 115, protein_g: 5, carbs_g: 4,  fat_g: 10, notes: nil },
  { name: "Chía",                                 category: :fat, serving_grams: 20, kcal: 95,  protein_g: 3, carbs_g: 8,  fat_g: 10, notes: "1.5 cdas" },
  { name: "Linaza molida",                        category: :fat, serving_grams: 25, kcal: 135, protein_g: 5, carbs_g: 7,  fat_g: 10, notes: nil },
  { name: "Semillas de calabaza",                 category: :fat, serving_grams: 20, kcal: 125, protein_g: 6, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Mantequilla de almendra",              category: :fat, serving_grams: 15, kcal: 100, protein_g: 3, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Mantequilla de maní",                  category: :fat, serving_grams: 15, kcal: 100, protein_g: 4, carbs_g: 3,  fat_g: 10, notes: nil },
  { name: "Aceitunas",                            category: :fat, serving_grams: 45, kcal: 55,  protein_g: 0, carbs_g: 2,  fat_g: 10, notes: "10 unidades" },
  { name: "Coco rallado",                         category: :fat, serving_grams: 15, kcal: 100, protein_g: 1, carbs_g: 4,  fat_g: 10, notes: nil },

  # --- Vegetables (free consumption, reference portions per 100g) ---
  { name: "Espinaca",           category: :vegetable, serving_grams: 100, kcal: 23,  protein_g: 3, carbs_g: 4,  fat_g: 0, notes: "libre" },
  { name: "Kale",               category: :vegetable, serving_grams: 100, kcal: 35,  protein_g: 3, carbs_g: 7,  fat_g: 1, notes: "libre" },
  { name: "Brócoli",            category: :vegetable, serving_grams: 100, kcal: 34,  protein_g: 3, carbs_g: 7,  fat_g: 0, notes: "libre" },
  { name: "Coliflor",           category: :vegetable, serving_grams: 100, kcal: 25,  protein_g: 2, carbs_g: 5,  fat_g: 0, notes: "libre" },
  { name: "Espárragos",         category: :vegetable, serving_grams: 100, kcal: 20,  protein_g: 2, carbs_g: 4,  fat_g: 0, notes: "libre" },
  { name: "Tomate",             category: :vegetable, serving_grams: 100, kcal: 18,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "libre" },
  { name: "Pepino",             category: :vegetable, serving_grams: 100, kcal: 16,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "libre" },
  { name: "Pimiento",           category: :vegetable, serving_grams: 100, kcal: 31,  protein_g: 1, carbs_g: 6,  fat_g: 0, notes: "libre" },
  { name: "Zanahoria",          category: :vegetable, serving_grams: 100, kcal: 41,  protein_g: 1, carbs_g: 10, fat_g: 0, notes: "libre" },
  { name: "Cebolla",            category: :vegetable, serving_grams: 100, kcal: 40,  protein_g: 1, carbs_g: 9,  fat_g: 0, notes: "libre" },
  { name: "Calabacín",          category: :vegetable, serving_grams: 100, kcal: 17,  protein_g: 1, carbs_g: 3,  fat_g: 0, notes: "libre" },
  { name: "Kimchi",             category: :vegetable, serving_grams: 100, kcal: 15,  protein_g: 1, carbs_g: 2,  fat_g: 0, notes: "fermentado" },
  { name: "Chucrut natural",    category: :vegetable, serving_grams: 100, kcal: 19,  protein_g: 1, carbs_g: 4,  fat_g: 0, notes: "fermentado" }
].freeze

FOODS.each do |attrs|
  Food.find_or_create_by!(name: attrs[:name], category: attrs[:category]) do |food|
    food.serving_grams = attrs[:serving_grams]
    food.kcal          = attrs[:kcal]
    food.protein_g     = attrs[:protein_g]
    food.carbs_g       = attrs[:carbs_g]
    food.fat_g         = attrs[:fat_g]
    food.notes         = attrs[:notes]
  end
end

puts "  #{Food.count} foods (#{Food.protein.count} protein, #{Food.carb.count} carb, #{Food.fat.count} fat, #{Food.vegetable.count} vegetable)"

# -----------------------------------------------------------------------------
# Plans + Meals + MealItems
# -----------------------------------------------------------------------------

puts "Seeding plans and meals…"

crossfit = Plan.find_or_initialize_by(slug: Plan::CROSSFIT_SLUG)
crossfit.assign_attributes(
  name: "Día CrossFit",
  target_kcal: 2100,
  target_protein_g: 180,
  target_carbs_g: 215,
  target_fat_g: 75
)
crossfit.save!

rest = Plan.find_or_initialize_by(slug: Plan::REST_SLUG)
rest.assign_attributes(
  name: "Día Descanso",
  target_kcal: 2050,
  target_protein_g: 180,
  target_carbs_g: 160,
  target_fat_g: 85
)
rest.save!

def find_food(name)
  Food.find_by!(name: name)
end

def upsert_meal(plan:, position:, name:, time:, kcal:, protein:, carbs:, fat:, items:)
  meal = plan.meals.find_or_initialize_by(position: position)
  meal.assign_attributes(
    name: name,
    scheduled_time: Time.zone.parse(time),
    target_kcal: kcal,
    target_protein_g: protein,
    target_carbs_g: carbs,
    target_fat_g: fat
  )
  meal.save!

  meal.meal_items.destroy_all
  items.each_with_index do |(food_name, qty), idx|
    meal.meal_items.create!(food: find_food(food_name), quantity_grams: qty, display_order: idx)
  end
  meal
end

# --- CrossFit Day meals ---
upsert_meal(plan: crossfit, position: 1, name: "Desayuno", time: "07:00",
  kcal: 460, protein: 40, carbs: 50, fat: 14,
  items: [
    ["Huevos enteros", 150],
    ["Claras de huevo", 100],
    ["Avena cruda", 40],
    ["Yogur griego 0%", 200],
    ["Frutos rojos", 80],
    ["Linaza molida", 12]
  ]
)

upsert_meal(plan: crossfit, position: 2, name: "Almuerzo", time: "12:00",
  kcal: 525, protein: 45, carbs: 65, fat: 15,
  items: [
    ["Pechuga de pollo cocida", 150],
    ["Arroz integral cocido", 180],
    ["Frijoles negros cocidos", 100],
    ["Aguacate", 60],
    ["AOVE (aceite de oliva virgen extra)", 11],
    ["Kimchi", 30]
  ]
)

upsert_meal(plan: crossfit, position: 3, name: "Pre-WOD", time: "15:30",
  kcal: 380, protein: 30, carbs: 55, fat: 6,
  items: [
    ["Whey isolate", 30],
    ["Banano", 135],
    ["Yogur griego 0%", 150],
    ["Almendras", 15]
  ]
)

upsert_meal(plan: crossfit, position: 4, name: "Cena Post-WOD", time: "19:30",
  kcal: 525, protein: 40, carbs: 50, fat: 18,
  items: [
    ["Salmón al horno", 150],
    ["Batata asada", 200],
    ["Brócoli", 150],
    ["Espárragos", 100],
    ["AOVE (aceite de oliva virgen extra)", 11],
    ["Nueces", 15],
    ["Chucrut natural", 30]
  ]
)

upsert_meal(plan: crossfit, position: 5, name: "Pre-sueño", time: "22:30",
  kcal: 210, protein: 35, carbs: 8, fat: 5,
  items: [
    ["Cottage cheese 2%", 200],
    ["Caseína micelar", 15]
  ]
)

# --- Rest Day meals ---
upsert_meal(plan: rest, position: 1, name: "Desayuno", time: "07:30",
  kcal: 440, protein: 40, carbs: 35, fat: 16,
  items: [
    ["Huevos enteros", 150],
    ["Claras de huevo", 100],
    ["Avena cruda", 30],
    ["Yogur griego 0%", 200],
    ["Frutos rojos", 60],
    ["Almendras", 18]
  ]
)

upsert_meal(plan: rest, position: 2, name: "Almuerzo", time: "12:30",
  kcal: 510, protein: 45, carbs: 50, fat: 17,
  items: [
    ["Pechuga de pavo cocida", 170],
    ["Quinoa cocida", 135],
    ["Aguacate", 60],
    ["AOVE (aceite de oliva virgen extra)", 11],
    ["Kimchi", 30]
  ]
)

upsert_meal(plan: rest, position: 3, name: "Merienda", time: "16:00",
  kcal: 340, protein: 30, carbs: 30, fat: 12,
  items: [
    ["Yogur griego 0%", 250],
    ["Manzana", 150],
    ["Almendras", 20]
  ]
)

upsert_meal(plan: rest, position: 4, name: "Cena", time: "19:30",
  kcal: 540, protein: 40, carbs: 35, fat: 25,
  items: [
    ["Salmón al horno", 140],
    ["Papa hervida", 150],
    ["Brócoli", 150],
    ["Espárragos", 100],
    ["AOVE (aceite de oliva virgen extra)", 11],
    ["Nueces", 15],
    ["Aguacate", 30]
  ]
)

upsert_meal(plan: rest, position: 5, name: "Pre-sueño", time: "22:30",
  kcal: 220, protein: 35, carbs: 10, fat: 6,
  items: [
    ["Cottage cheese 2%", 200],
    ["Caseína micelar", 15]
  ]
)

puts "  #{Plan.count} plans, #{Meal.count} meals, #{MealItem.count} meal items"

# -----------------------------------------------------------------------------
# Supplements + schedule
# -----------------------------------------------------------------------------

puts "Seeding supplements…"

SUPPLEMENTS = [
  { name: "Vitamina D3",            dose: "3,000 UI",         notes: "con grasa",                              critical: false, slot: :morning,   position: 1 },
  { name: "Vitamina K2 MK-7",       dose: "180 µg",           notes: "con grasa",                              critical: false, slot: :morning,   position: 2 },
  { name: "Omega-3 rTG (AM)",       dose: "1g EPA+DHA",       notes: "con desayuno",                           critical: false, slot: :morning,   position: 3 },
  { name: "Curcumina Meriva (AM)",  dose: "500 mg",           notes: "anti-inflamatorio",                      critical: false, slot: :morning,   position: 4 },
  { name: "Mind Lab Pro",           dose: "2 cápsulas",       notes: "Lion's Mane + L-Theanine",               critical: false, slot: :morning,   position: 5 },

  { name: "Psyllium",               dose: "10 g en 300ml agua", notes: "15 min antes del almuerzo",            critical: false, slot: :pre_lunch, position: 1 },

  { name: "Fibrotina (Fenofibrato)", dose: "según Rx",         notes: "con cena grasa — crítico",
    critical: true, slot: :dinner, position: 1,
    contraindications: "NO con arroz de levadura roja · NO con niacina en dosis alta · NO con berberina" },
  { name: "Omega-3 rTG (PM)",       dose: "1g EPA+DHA",       notes: "con cena (total diario 2g)",             critical: false, slot: :dinner,    position: 2 },
  { name: "CoQ10 Ubiquinol",        dose: "200 mg",           notes: "con grasa",                              critical: false, slot: :dinner,    position: 3 },
  { name: "Curcumina Meriva (PM)",  dose: "500 mg",           notes: "total 1g/día",                           critical: false, slot: :dinner,    position: 4 },
  { name: "Creatina monohidratada", dose: "5 g",              notes: "en agua",                                critical: false, slot: :dinner,    position: 5 },

  { name: "Magnesio glicinato",     dose: "400 mg",           notes: "mejora sueño",                           critical: false, slot: :pre_sleep, position: 1 },
  { name: "L-Theanine",             dose: "200 mg",           notes: "si no está en Mind Lab Pro",             critical: false, slot: :pre_sleep, position: 2 }
].freeze

SUPPLEMENTS.each do |attrs|
  supplement = Supplement.find_or_initialize_by(name: attrs[:name])
  supplement.assign_attributes(
    dose: attrs[:dose],
    notes: attrs[:notes],
    critical: attrs[:critical],
    contraindications: attrs[:contraindications]
  )
  supplement.save!

  schedule = supplement.supplement_schedules.first_or_initialize
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
  { label: "Bebí 3L de agua",                     description: "Hidratación diaria",                  icon: "💧" },
  { label: "Tomé Fibrotina con cena",             description: "Crítico — con grasa a las 7:30 PM",   icon: "💊" },
  { label: "180g de proteína consumida",          description: "5 comidas × 30-45g",                  icon: "🥩" },
  { label: "Al menos 500g de vegetales",          description: "Fibra y micronutrientes",             icon: "🥦" },
  { label: "Kefir + 1 fermentado",                description: "Salud intestinal",                    icon: "🥛" },
  { label: "Suplementos mañana completos",        description: "Vit D3, K2, Omega-3, Curcumina, MLP", icon: "☀️" },
  { label: "Suplementos noche completos",         description: "Omega-3, CoQ10, Creatina, Curcumina", icon: "🌙" },
  { label: "Caseína pre-sueño",                   description: "Ventana anabólica nocturna",          icon: "🛌" },
  { label: "7-8 horas de sueño (noche anterior)", description: "Crítico para reducir PCR",            icon: "😴" },
  { label: "30+ min actividad física",            description: "CrossFit o caminata",                 icon: "💪" },
  { label: "2-3 cdas AOVE",                       description: "MUFA — HDL y antiinflamatorio",       icon: "🫒" },
  { label: "Psyllium 10g",                        description: "Fibra soluble — 15 min pre-almuerzo", icon: "🌾" }
].freeze

CHECKLIST.each_with_index do |attrs, idx|
  template = ChecklistTemplate.find_or_initialize_by(label: attrs[:label])
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
  { metric: :weight_kg,      display_name: "Peso",              starting_value: 93.84, target_value: 87,   unit: "kg",    direction: :down     },
  { metric: :body_fat_pct,   display_name: "Grasa corporal",    starting_value: 26.1,  target_value: 19,   unit: "%",     direction: :down     },
  { metric: :hdl,            display_name: "HDL",               starting_value: 39,    target_value: 45,   unit: "mg/dL", direction: :up       },
  { metric: :hs_crp,         display_name: "PCR ultrasensible", starting_value: 5.2,   target_value: 3,    unit: "mg/L",  direction: :down     },
  { metric: :visceral_fat,   display_name: "Grasa visceral",    starting_value: 12,    target_value: 9,    unit: "nivel", direction: :down     },
  { metric: :muscle_mass_kg, display_name: "Masa muscular",     starting_value: 67,    target_value: 67,   unit: "kg",    direction: :preserve }
].freeze

GOALS.each do |attrs|
  goal = Goal.find_or_initialize_by(metric: attrs[:metric])
  goal.assign_attributes(attrs)
  goal.save!
end

puts "  #{Goal.count} goals"

# -----------------------------------------------------------------------------
# Default user (Esteban)
# -----------------------------------------------------------------------------

puts "Seeding user…"

email    = ENV.fetch("ESTEBAN_EMAIL", "esoto074@gmail.com")
password = ENV.fetch("ESTEBAN_PASSWORD", "changeme-now-please")

user = User.find_or_initialize_by(email_address: email)
user.password = password if user.new_record?
user.save!

puts "  user: #{user.email_address}"
puts "Done."
