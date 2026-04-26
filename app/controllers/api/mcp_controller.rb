module Api
  # Streamable HTTP transport for the Model Context Protocol. Claude (web,
  # desktop, mobile) speaks JSON-RPC 2.0 over POST. We implement just the
  # three methods a tools-only server needs (initialize, tools/list,
  # tools/call) and return 405 on other HTTP verbs since we run stateless
  # — every request stands on its own access token, no session continuity.
  #
  # Tool handlers reuse the same model code that backs /api/v1/* by way of
  # the DaySerializer concern, so the wire shape Claude sees is byte-for-
  # byte identical to the JSON the existing API returns. That keeps the
  # cognitive load on Claude minimal.
  class McpController < ActionController::API
    include Api::Concerns::DaySerializer

    # Tool-input failures (bad date, missing food, missing required arg)
    # bubble up to the user as `isError: true` with their message intact.
    # Anything else is a bug — log with backtrace and return a generic
    # "internal error" so we don't leak DB column names, file paths, or
    # SQL fragments back to the client.
    class ToolArgumentError < StandardError; end
    USER_ERRORS = [ ToolArgumentError, ActiveRecord::RecordInvalid,
                   ActiveRecord::RecordNotFound, ArgumentError, KeyError, Date::Error ].freeze

    PROTOCOL_VERSION = "2025-06-18".freeze
    SERVER_INFO      = { name: "food-tracker", version: "0.2.0" }.freeze

    rate_limit to: 120, within: 1.minute, by: -> { request.remote_ip },
               with: -> { render json: rpc_error(nil, -32000, "rate_limited"), status: :too_many_requests }

    before_action :reject_unsupported_methods
    before_action :doorkeeper_authorize!, only: :handle

    rescue_from StandardError do |error|
      Rails.logger.error("[mcp] #{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
      Rails.error.report(error, context: { rpc_id: @rpc_id, method: @parsed_message&.dig("method") })
      render json: rpc_error(@rpc_id, -32603, "internal_error"), status: :ok
    end

    def handle
      msg = parse_message
      @rpc_id = msg["id"]
      method  = msg["method"]
      params  = msg["params"] || {}

      # Notifications (no id) get an empty 202 — they don't expect a body.
      if @rpc_id.nil?
        return head(:accepted)
      end

      result = case method
      when "initialize"   then initialize_result(params)
      when "tools/list"   then { tools: tool_descriptors }
      when "tools/call"   then call_tool(params)
      else
                 return render(json: rpc_error(@rpc_id, -32601, "method not found: #{method}"))
      end

      render json: { jsonrpc: "2.0", id: @rpc_id, result: result }
    end

    private

    def reject_unsupported_methods
      head(:method_not_allowed) unless request.post?
    end

    def parse_message
      @parsed_message ||= JSON.parse(request.raw_post.presence || "{}")
    rescue JSON::ParserError
      @parsed_message = {}
    end

    def initialize_result(_params)
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities:    { tools: { listChanged: false } },
        serverInfo:      SERVER_INFO
      }
    end

    def call_tool(params)
      name      = params["name"]
      arguments = params["arguments"] || {}
      tool      = TOOLS.find { |t| t[:name] == name }

      return tool_error("unknown tool: #{name}") unless tool

      payload = send(tool[:handler], arguments)
      { content: [ { type: "text", text: JSON.pretty_generate(payload) } ] }
    rescue *USER_ERRORS => e
      tool_error(e.message)
    end

    def tool_error(message)
      { content: [ { type: "text", text: "Error: #{message}" } ], isError: true }
    end

    def tool_descriptors
      TOOLS.map { |t| t.slice(:name, :description, :inputSchema) }
    end

    def rpc_error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end

    # ----- Tool handler shared helpers.

    # Parse the optional "date" arg as YYYY-MM-DD, defaulting to today.
    # Tolerates `nil` and the literal string "null" (which Date.parse
    # would otherwise raise on).
    def date_arg(args, key = "date", default: -> { Date.current })
      raw = args[key]
      raw.present? ? Date.parse(raw.to_s) : default.call
    end

    def log_for(args)
      DailyLog.for(date_arg(args))
    end

    def plan_for(args)
      args["plan_slug"].present? ? Plan.find_by!(slug: args["plan_slug"]) : log_for(args).plan
    end

    # ----- Tool handlers.

    def handle_get_today_status(_args)
      serialize_day(DailyLog.today)
    end

    def handle_get_day_status(args)
      serialize_day(DailyLog.for(date_arg(args, default: -> { raise ToolArgumentError, "date is required" })))
    end

    def handle_log_weight(args)
      goal  = Goal.find_by!(metric: Goal.metrics[:weight_kg])
      date  = date_arg(args)
      entry = goal.biomarker_entries.create!(value: args.fetch("value"), recorded_on: date)
      log   = DailyLog.for(date)
      log.update!(weight_kg: entry.value) if log.date == entry.recorded_on
      { ok: true,
        entry: { id: entry.id, value: entry.value.to_f, recorded_on: entry.recorded_on.iso8601 },
        day:   serialize_day(log.reload) }
    end

    def handle_complete_meal(args)
      meal = resolve_meal(args)
      log  = log_for(args)
      log.meal_completions.find_or_create_by!(meal: meal) { |mc| mc.completed_at = Time.current }
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_uncomplete_meal(args)
      meal = resolve_meal(args)
      log  = log_for(args)
      log.meal_completions.find_by!(meal: meal).destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_log_food(args)
      food = resolve_food(args.fetch("name"))
      log  = log_for(args)
      qty  = args["quantity_grams"].presence&.to_d || food.serving_grams
      log.logged_foods.create!(food: food, quantity_grams: qty, logged_at: Time.current)
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_delete_logged_food(args)
      entry = LoggedFood.find(args.fetch("id"))
      log   = entry.daily_log
      entry.destroy!
      { ok: true, day: serialize_day(log.reload) }
    end

    def handle_set_plan_for_day(args)
      log  = log_for(args)
      plan = Plan.find_by!(slug: args.fetch("slug"))
      log.update!(plan: plan)
      serialize_day(log.reload)
    end

    def handle_list_goals(_args)
      { goals: Goal.all.map { |g| serialize_goal(g) } }
    end

    def handle_search_foods(args)
      q = args.fetch("q").to_s.downcase
      foods = Food.alphabetical.where("LOWER(name) LIKE ?", "%#{q}%").limit(20)
      { foods: foods.map { |f| serialize_food(f) } }
    end

    def handle_create_food(args)
      food = Food.create!(args.slice("name", "category", "serving_grams", "kcal",
                                     "protein_g", "carbs_g", "fat_g", "notes"))
      { food: serialize_food(food) }
    end

    def handle_active_meals(args)
      plan  = plan_for(args)
      meals = plan.meals.includes(meal_items: :food).ordered
      { plan: serialize_plan(plan), meals: meals.map { |m| serialize_meal(m) } }
    end

    def handle_get_weekly_summary(_args)
      summary = WeeklySummary.rolling_7_days
      {
        window_days: 7,
        start_date:  summary.start_date.iso8601,
        end_date:    summary.end_date.iso8601,
        adherence_pct:             summary.adherence_pct,
        weight_delta_kg:           summary.weight_delta_kg,
        meal_completion_pct:       summary.meal_completion_pct,
        supplement_completion_pct: summary.supplement_completion_pct
      }
    end

    def handle_list_supplements(args)
      scope = args["archived"] ? Supplement.discarded : Supplement.kept
      scope = scope.includes(:supplement_schedules).order(critical: :desc, name: :asc)
      { supplements: scope.map { |s| serialize_supplement(s) } }
    end

    def handle_create_supplement(args)
      attrs = args.slice("name", "dose", "critical", "notes", "contraindications")
      supplement = Supplement.create!(attrs)
      sync_supplement_schedules(supplement, args["time_slots"])
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_update_supplement(args)
      supplement = Supplement.find(args.fetch("id"))
      attrs = args.slice("name", "dose", "critical", "notes", "contraindications").compact
      supplement.update!(attrs) if attrs.any?
      sync_supplement_schedules(supplement, args["time_slots"]) if args.key?("time_slots")
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_archive_supplement(args)
      supplement = Supplement.find(args.fetch("id"))
      supplement.discard!
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_restore_supplement(args)
      supplement = Supplement.find(args.fetch("id"))
      supplement.restore!
      { supplement: serialize_supplement(supplement.reload) }
    end

    def handle_list_habits(args)
      scope = args["archived"] ? ChecklistTemplate.discarded.order(:label) : ChecklistTemplate.kept.ordered
      { habits: scope.map { |t| serialize_habit(t) } }
    end

    def handle_create_habit(args)
      attrs = args.slice("label", "description", "icon")
      template = ChecklistTemplate.new(attrs)
      template.position = (ChecklistTemplate.kept.maximum(:position) || -1) + 1
      template.save!
      { habit: serialize_habit(template) }
    end

    def handle_update_habit(args)
      template = ChecklistTemplate.find(args.fetch("id"))
      attrs = args.slice("label", "description", "icon", "position").compact
      template.update!(attrs) if attrs.any?
      { habit: serialize_habit(template.reload) }
    end

    def handle_archive_habit(args)
      template = ChecklistTemplate.find(args.fetch("id"))
      template.discard!
      { habit: serialize_habit(template.reload) }
    end

    def handle_restore_habit(args)
      template = ChecklistTemplate.find(args.fetch("id"))
      next_position = (ChecklistTemplate.kept.maximum(:position) || -1) + 1
      template.update!(discarded_at: nil, position: next_position)
      { habit: serialize_habit(template.reload) }
    end

    def sync_supplement_schedules(supplement, requested)
      requested = Array(requested).map(&:to_s).to_set & SupplementSchedule::TIME_SLOTS.keys.map(&:to_s)
      existing  = supplement.supplement_schedules.index_by(&:time_slot)

      (requested - existing.keys).each do |slot|
        next_position = (SupplementSchedule.where(time_slot: slot).maximum(:position) || -1) + 1
        supplement.supplement_schedules.create!(time_slot: slot, position: next_position)
      end
      (existing.keys - requested.to_a).each do |slot|
        existing[slot].destroy!
      end
    end

    def handle_copy_yesterday_meals(args)
      target_date = date_arg(args)
      yesterday = DailyLog.find_by(date: target_date - 1)

      raise ToolArgumentError, "no_yesterday_log: no log from yesterday — nothing to copy" if yesterday.nil?

      existing_today = DailyLog.find_by(date: target_date)
      if existing_today && !existing_today.can_copy_from?(yesterday)
        raise ToolArgumentError, "plan_mismatch: yesterday's plan (#{yesterday.plan.slug}) doesn't match today's (#{existing_today.plan.slug})"
      end

      today = existing_today || DailyLog.for(target_date, default_plan: yesterday.plan)
      copied = today.copy_completions_from(yesterday)
      { ok: true, copied: copied, day: serialize_day(today.reload) }
    end

    def resolve_food(query)
      Food.where("LOWER(name) LIKE ?", "%#{query.downcase}%").first ||
        raise(ToolArgumentError, "no food matches \"#{query}\" — call search_foods to find the canonical name")
    end

    def resolve_meal(args)
      plan = plan_for(args)
      plan.meals.find { |m| m.name.casecmp?(args.fetch("name")) } ||
        raise(ToolArgumentError, "no meal \"#{args['name']}\" on plan \"#{plan.slug}\"")
    end

    # ----- Tool registry. Schemas mirror the Zod definitions in the
    # ----- existing Node MCP server (mcp/index.js); see that file for
    # ----- prose descriptions of each parameter's intent.

    ISO_DATE_PATTERN = '^\\d{4}-\\d{2}-\\d{2}$'.freeze
    PLAN_SLUGS       = %w[exercise active rest].freeze
    DATE_PROP        = { type: "string", pattern: ISO_DATE_PATTERN, description: "YYYY-MM-DD; defaults to today when omitted" }.freeze

    TOOLS = [
      {
        name:        "get_today_status",
        description: "Today's plan, macro targets, consumed macros, weight, completed meals, now_meal, and logged foods.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_get_today_status
      },
      {
        name:        "get_day_status",
        description: "Same shape as get_today_status, for a specific date (YYYY-MM-DD).",
        inputSchema: { type: "object", properties: { "date" => DATE_PROP }, required: %w[date] },
        handler:     :handle_get_day_status
      },
      {
        name:        "get_weekly_summary",
        description: "Rolling 7-day recap: avg habits adherence %, weight delta in kg (negative = weight loss), meal completion %, supplement adherence %. Any metric may be null when there's no data to compute it.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_get_weekly_summary
      },
      {
        name:        "log_weight",
        description: "Record a body-weight measurement in kg. Defaults to today; pass `date` to backfill.",
        inputSchema: {
          type: "object",
          properties: {
            "value" => { type: "number", exclusiveMinimum: 0, description: "weight in kilograms" },
            "date"  => DATE_PROP
          },
          required: %w[value]
        },
        handler: :handle_log_weight
      },
      {
        name:        "complete_meal",
        description: "Look up a meal by name (e.g. 'Breakfast') on the active plan and mark it complete.",
        inputSchema: {
          type: "object",
          properties: {
            "name"      => { type: "string", description: "meal name, e.g. 'Breakfast', 'Lunch', 'Dinner'" },
            "plan_slug" => { type: "string", enum: PLAN_SLUGS, description: "if omitted, uses the day's currently selected plan" },
            "date"      => DATE_PROP
          },
          required: %w[name]
        },
        handler: :handle_complete_meal
      },
      {
        name:        "uncomplete_meal",
        description: "Remove a meal completion. Same lookup as complete_meal.",
        inputSchema: {
          type: "object",
          properties: {
            "name"      => { type: "string" },
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "date"      => DATE_PROP
          },
          required: %w[name]
        },
        handler: :handle_uncomplete_meal
      },
      {
        name:        "copy_yesterday_meals",
        description: "Marks the target day's meals as complete using the day before's completions, when both share a plan. Idempotent — already-completed meals are preserved. Pass `date` to copy onto a past day; defaults to today.",
        inputSchema: {
          type: "object",
          properties: { "date" => DATE_PROP }
        },
        handler: :handle_copy_yesterday_meals
      },
      {
        name:        "log_food",
        description: "Resolve a food by name (case-insensitive partial match) and log a serving. Defaults to the food's serving_grams.",
        inputSchema: {
          type: "object",
          properties: {
            "name"           => { type: "string", description: "food name, e.g. 'Chicken breast'" },
            "quantity_grams" => { type: "number", exclusiveMinimum: 0 },
            "date"           => DATE_PROP
          },
          required: %w[name]
        },
        handler: :handle_log_food
      },
      {
        name:        "delete_logged_food",
        description: "Remove a previously logged food by its id (find ids via get_today_status or get_day_status).",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_delete_logged_food
      },
      {
        name:        "set_plan_for_day",
        description: "Switch the day's plan (exercise/active/rest). Defaults to today.",
        inputSchema: {
          type: "object",
          properties: {
            "slug" => { type: "string", enum: PLAN_SLUGS },
            "date" => DATE_PROP
          },
          required: %w[slug]
        },
        handler: :handle_set_plan_for_day
      },
      {
        name:        "list_goals",
        description: "All tracked goals (weight, body fat, HDL, etc.) with current value, target, and progress percent.",
        inputSchema: { type: "object", properties: {} },
        handler:     :handle_list_goals
      },
      {
        name:        "search_foods",
        description: "Find the canonical name of a food before logging it. Case-insensitive partial match, top 20.",
        inputSchema: {
          type: "object",
          properties: { "q" => { type: "string" } },
          required: %w[q]
        },
        handler: :handle_search_foods
      },
      {
        name:        "create_food",
        description: "Add a new food to the library. All macro values are per a single serving (serving_grams). Notes optional (brand, prep, source).",
        inputSchema: {
          type: "object",
          properties: {
            "name"          => { type: "string" },
            "category"      => { type: "string", enum: %w[protein carb fat vegetable] },
            "serving_grams" => { type: "number", exclusiveMinimum: 0 },
            "kcal"          => { type: "integer", minimum: 0 },
            "protein_g"     => { type: "number", minimum: 0 },
            "carbs_g"       => { type: "number", minimum: 0 },
            "fat_g"         => { type: "number", minimum: 0 },
            "notes"         => { type: "string" }
          },
          required: %w[name category serving_grams kcal protein_g carbs_g fat_g]
        },
        handler: :handle_create_food
      },
      {
        name:        "list_meals",
        description: "List the 5 meals on a plan (defaults to the active plan for today) with per-item macros and per-meal totals — useful for previewing what to eat.",
        inputSchema: {
          type: "object",
          properties: {
            "plan_slug" => { type: "string", enum: PLAN_SLUGS },
            "date"      => DATE_PROP
          }
        },
        handler: :handle_active_meals
      },

      # ----- Supplements (templates, not completions) -----
      {
        name:        "list_supplements",
        description: "List supplements. Default returns active (non-archived) sorted by critical first then name. Pass archived=true for the archived list.",
        inputSchema: {
          type: "object",
          properties: { "archived" => { type: "boolean", default: false } }
        },
        handler: :handle_list_supplements
      },
      {
        name:        "create_supplement",
        description: "Add a supplement. time_slots is an optional list of slot keys (morning, pre_lunch, dinner, pre_sleep) — each becomes a row on /supplements at that time.",
        inputSchema: {
          type: "object",
          properties: {
            "name"              => { type: "string" },
            "dose"              => { type: "string", description: "e.g. '1 capsule' or '5 g'" },
            "critical"          => { type: "boolean", default: false },
            "notes"             => { type: "string" },
            "contraindications" => { type: "string" },
            "time_slots"        => { type: "array", items: { type: "string", enum: %w[morning pre_lunch dinner pre_sleep] } }
          },
          required: %w[name dose]
        },
        handler: :handle_create_supplement
      },
      {
        name:        "update_supplement",
        description: "Edit a supplement by id. Any provided field is updated; omitted fields are unchanged. Pass time_slots to fully replace the slot assignments (omit to leave them alone).",
        inputSchema: {
          type: "object",
          properties: {
            "id"                => { type: "integer", exclusiveMinimum: 0 },
            "name"              => { type: "string" },
            "dose"              => { type: "string" },
            "critical"          => { type: "boolean" },
            "notes"             => { type: "string" },
            "contraindications" => { type: "string" },
            "time_slots"        => { type: "array", items: { type: "string", enum: %w[morning pre_lunch dinner pre_sleep] } }
          },
          required: %w[id]
        },
        handler: :handle_update_supplement
      },
      {
        name:        "archive_supplement",
        description: "Soft-delete a supplement: it disappears from /supplements and the rolling adherence calc, but past completion records remain.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_archive_supplement
      },
      {
        name:        "restore_supplement",
        description: "Un-archive a supplement (clears discarded_at).",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_restore_supplement
      },

      # ----- Habits (ChecklistTemplate) -----
      {
        name:        "list_habits",
        description: "List habit templates. Default returns active (non-archived) in display order. Pass archived=true for the archived list.",
        inputSchema: {
          type: "object",
          properties: { "archived" => { type: "boolean", default: false } }
        },
        handler: :handle_list_habits
      },
      {
        name:        "create_habit",
        description: "Add a habit. New habits get appended at the bottom of the order.",
        inputSchema: {
          type: "object",
          properties: {
            "label"       => { type: "string" },
            "description" => { type: "string" },
            "icon"        => { type: "string", description: "single emoji, optional" }
          },
          required: %w[label]
        },
        handler: :handle_create_habit
      },
      {
        name:        "update_habit",
        description: "Edit a habit by id. Pass an integer position to reorder (lower = earlier on /checklist).",
        inputSchema: {
          type: "object",
          properties: {
            "id"          => { type: "integer", exclusiveMinimum: 0 },
            "label"       => { type: "string" },
            "description" => { type: "string" },
            "icon"        => { type: "string" },
            "position"    => { type: "integer", minimum: 0 }
          },
          required: %w[id]
        },
        handler: :handle_update_habit
      },
      {
        name:        "archive_habit",
        description: "Soft-delete a habit: it disappears from /checklist and the adherence calc, but past completion records remain.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_archive_habit
      },
      {
        name:        "restore_habit",
        description: "Un-archive a habit; it's appended at the bottom of the order.",
        inputSchema: {
          type: "object",
          properties: { "id" => { type: "integer", exclusiveMinimum: 0 } },
          required: %w[id]
        },
        handler: :handle_restore_habit
      }
    ].freeze
  end
end
