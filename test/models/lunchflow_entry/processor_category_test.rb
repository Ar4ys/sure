require "test_helper"

class LunchflowEntry::ProcessorCategoryTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @groceries = @family.categories.create!(name: "Groceries")
    @transport = @family.categories.create!(name: "Transport")

    @lunchflow_item = LunchflowItem.create!(name: "Category test", api_key: "test_key", family: @family)
    @lunchflow_account = LunchflowAccount.create!(
      lunchflow_item: @lunchflow_item,
      name: "Test Account",
      currency: "PLN",
      account_id: "lf_acc_category"
    )
    @account = Account.create!(
      family: @family,
      name: "Test Checking",
      accountable: Depository.new(subtype: "checking"),
      balance: 1000,
      currency: "PLN"
    )
    AccountProvider.create!(account: @account, provider: @lunchflow_account)
    @lunchflow_account.reload
  end

  test "sets the family's category that categoryId names" do
    entry = process(categoryId: @groceries.id)

    assert_equal @groceries, entry.entryable.category
  end

  test "moves the entry to a new category on a later sync" do
    process(categoryId: @groceries.id)
    entry = process(categoryId: @transport.id)

    assert_equal @transport, entry.entryable.category
  end

  test "ignores the category of another family" do
    entry = process(categoryId: categories(:food_and_drink).id)

    assert_nil entry.entryable.category
  end

  test "ignores an unknown id and one that is not a UUID" do
    assert_nil process(categoryId: SecureRandom.uuid).entryable.category
    assert_nil process(categoryId: "groceries").entryable.category
  end

  test "leaves the category alone without categoryId" do
    process(categoryId: @groceries.id)
    entry = process(categoryId: nil)

    assert_equal @groceries, entry.entryable.category
  end

  test "keeps a category that was locked by an edit" do
    entry = process(categoryId: @groceries.id)
    entry.entryable.update!(category: @transport)
    entry.entryable.lock_attr!(:category_id)

    entry = process(categoryId: @groceries.id)

    assert_equal @transport, entry.entryable.category
  end

  private
    def process(categoryId:)
      LunchflowEntry::Processor.new(
        {
          id: "lf_txn_category",
          accountId: 456,
          amount: -25.00,
          currency: "PLN",
          date: "2026-10-20",
          merchant: "Bakery",
          description: "Bread",
          isPending: false,
          categoryId: categoryId
        }.compact,
        lunchflow_account: @lunchflow_account
      ).process.reload
    end
end
