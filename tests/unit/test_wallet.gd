extends GutTest

func test_starts_broke() -> void:
	assert_eq(Wallet.new().savings, 0)


func test_credit_adds() -> void:
	var w := Wallet.new()
	w.credit(60)
	w.credit(90)
	assert_eq(w.savings, 150)


func test_credit_ignores_negative() -> void:
	var w := Wallet.new()
	w.credit(-50)
	assert_eq(w.savings, 0)


func test_spend_within_savings() -> void:
	var w := Wallet.new()
	w.credit(20)
	assert_true(w.spend(5))
	assert_eq(w.savings, 15)


func test_spend_refuses_overdraft() -> void:
	var w := Wallet.new()
	w.credit(4)
	assert_false(w.spend(5))
	assert_eq(w.savings, 4)


func test_spend_exact_balance_allowed() -> void:
	var w := Wallet.new()
	w.credit(5)
	assert_true(w.spend(5))
	assert_eq(w.savings, 0)


func test_spend_refuses_negative_cost() -> void:
	var w := Wallet.new()
	w.credit(10)
	assert_false(w.spend(-3))
	assert_eq(w.savings, 10)


func test_can_retire_at_exact_target() -> void:
	var w := Wallet.new()
	w.credit(4000)
	assert_true(w.can_retire(4000))


func test_cannot_retire_below_target() -> void:
	var w := Wallet.new()
	w.credit(3999)
	assert_false(w.can_retire(4000))


func test_drain_takes_the_exact_cost() -> void:
	var w := Wallet.new()
	w.credit(100)
	var taken := w.drain(45)
	assert_eq(taken, 45)
	assert_eq(w.savings, 55)


func test_drain_past_zero_clamps_and_returns_the_partial_amount() -> void:
	var w := Wallet.new()
	w.credit(20)
	var taken := w.drain(45)
	assert_eq(taken, 20, "only what was actually there gets taken")
	assert_eq(w.savings, 0, "money never goes negative")


func test_drain_refuses_negative_cost() -> void:
	var w := Wallet.new()
	w.credit(10)
	var taken := w.drain(-5)
	assert_eq(taken, 0)
	assert_eq(w.savings, 10)
