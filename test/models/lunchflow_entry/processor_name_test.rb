require "test_helper"

class LunchflowEntry::ProcessorNameTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @lunchflow_item = LunchflowItem.create!(name: "Name test", api_key: "test_key", family: @family)
    @lunchflow_account = LunchflowAccount.create!(
      lunchflow_item: @lunchflow_item,
      name: "Test Account",
      currency: "PLN",
      account_id: "lf_acc_name"
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

  test "names the transaction after its description and keeps the merchant apart" do
    entry = process(merchant: "Bolt", description: "Ride to the airport")

    assert_equal "Ride to the airport", entry.name
    assert_equal "Bolt", entry.entryable.merchant.name
    assert_nil entry.notes
  end

  test "names a transaction without a merchant after its description" do
    entry = process(merchant: nil, description: "ATM, Marszałkowska 1, Warszawa, PL")

    assert_equal "ATM, Marszałkowska 1, Warszawa, PL", entry.name
    assert_nil entry.entryable.merchant
    assert_nil entry.notes
  end

  test "does not fall back to the merchant when the description is blank" do
    entry = process(merchant: "Bolt", description: "  ")

    assert_equal "Unknown transaction", entry.name
    assert_equal "Bolt", entry.entryable.merchant.name
    assert_nil entry.notes
  end

  test "renames an entry that was synced under its merchant" do
    entry = process(merchant: "Bolt", description: "Ride to the airport")
    entry.update!(name: "Bolt", notes: "Ride to the airport")

    entry = process(merchant: "Bolt", description: "Ride to the airport")

    assert_equal "Ride to the airport", entry.name
    assert_equal "Ride to the airport", entry.notes, "Notes of an existing entry are left as they are"
  end

  private
    def process(merchant:, description:)
      LunchflowEntry::Processor.new(
        {
          id: "lf_txn_name",
          accountId: 456,
          amount: -25.00,
          currency: "PLN",
          date: "2026-10-20",
          merchant: merchant,
          description: description,
          isPending: false
        },
        lunchflow_account: @lunchflow_account
      ).process
    end
end
