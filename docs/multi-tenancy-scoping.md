# Multi-Tenancy Scoping Conventions

This document defines the architectural standards for data isolation and multi-tenancy within the Food Plan Tracker. All features must adhere to these conventions to prevent cross-tenant data leaks.

## Core Rule: Fail-Closed Isolation

Multi-tenancy is implemented via the `Tenantable` concern. The primary mechanism for isolation is the `for_user` scope.

```ruby
scope :for_user, ->(user) { user ? where(user: user) : none }
```

**Crucial:** If `user` is `nil`, the scope returns `none` (an empty relation). This ensures that an unset `Current.user` results in zero records being returned rather than all records being returned.

## The Four Conventions

To ensure consistency and prevent "leakage" in complex query chains, the following conventions are mandatory:

### 1. `for_user` Comes First
Always chain `for_user` at the beginning of a relation chain. This establishes the tenant boundary before any other filters (like `kept` or `where`) are applied.

- **Correct:** `Plan.for_user(user).kept.find_by(...)`
- **Incorrect:** `Plan.kept.for_user(user).find_by(...)`

### 2. Default to `Current.user`
Class methods and PORO entry points must default the `user:` argument to `Current.user`. This allows the app to operate safely in controllers without explicit passing, while remaining testable.

```ruby
def self.some_operation(user: Current.user)
  # ...
end
```

### 3. `Discardable#kept_on` is Not User-Scoped
The `kept_on(date)` scope in the `Discardable` concern is a purely temporal filter. It does **not** check ownership. Callers MUST chain it after `for_user`.

- **Correct:** `ChecklistTemplate.for_user(user).kept_on(date)`
- **Incorrect:** `ChecklistTemplate.kept_on(date).for_user(user)` (Violates Convention 1)
- **Critical Error:** `ChecklistTemplate.kept_on(date)` (Returns records for ALL users)

### 4. PORO User Threading
POROs (Plain Old Ruby Objects) that perform data access must accept a `user` in their constructor and thread that instance variable (`@user`) into all subsequent model queries.

```ruby
def initialize(range, user: Current.user)
  @user = user
end

def some_metric
  DailyLog.for_user(@user).where(...)
end
```

## Intentionally Global Components

The following components are designed to be shared across all users and should **not** be scoped by `for_user`:

- `Food`: The global food library.
- `ApiToken.authenticate`: The authentication entry point must be global to find the token before identifying the user.
- `Discardable#kept_on` (the logic inside the scope itself).

## Spec Pattern: Isolation Testing

Every scoped model/PORO must be verified using a "negative control" test. The test must:
1. Create data for `user_a`.
2. Attempt to access that data using `user_b`.
3. Assert that the result is empty or `nil`.

```ruby
it "does not leak data to other users" do
  item_a = create(:plan, user: user_a)
  expect(Plan.for_user(user_b).find_by(id: item_a.id)).to be_nil
end
```

## Scoping Audit Table

| Component | Type | Scoping Status | Mechanism | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `User` | Model | N/A | Internal | Tenant Owner |
| `Plan` | Model | Scoped | `Tenantable` | |
| `Goal` | Model | Scoped | `Tenantable` | |
| `Supplement` | Model | Scoped | `Tenantable` | |
| `ChecklistTemplate` | Model | Scoped | `Tenantable` | |
| `ReminderPreference` | Model | Scoped | `Tenantable` | |
| `DailyLog` | Model | Scoped | `Tenantable` | |
| `Meal` | Model | Scoped | `Tenantable` | |
| `MealItem` | Model | Scoped | `Tenantable` | |
| `LoggedFood` | Model | Scoped | `Tenantable` | |
| `MealCompletion` | Model | Scoped | `Tenantable` | |
| `SupplementCompletion` | Model | Scoped | `Tenantable` | |
| `ChecklistCompletion` | Model | Scoped | `Tenantable` | |
| `PushSubscription` | Model | Scoped | `Tenantable` | |
| `NotificationDelivery` | Model | Scoped | `Tenantable` | |
| `WeeklySummary` | PORO | Scoped | `@user` threading | Verified PER-569 |
| `Food` | Model | **Global** | N/A | Shared library |
| `ApiToken` | Model | Scoped | `Tenantable` | `authenticate` remains global digest lookup |
| `User`, `Session`, `Current`, `ApplicationRecord` | N/A | N/A | N/A | no tenant queries |
