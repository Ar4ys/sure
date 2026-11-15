require "test_helper"

class LunchflowEntry::ProcessorNotesTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)

    @lunchflow_item = LunchflowItem.create!(name: "Notes test", api_key: "test_key", family: @family)
    @lunchflow_account = LunchflowAccount.create!(
      lunchflow_item: @lunchflow_item,
      name: "Test Account",
      currency: "PLN",
      account_id: "lf_acc_notes"
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

  test "sets the notes that bank-scraper sends" do
    entry = process(notes: "To: JAN KOWALSKI\nAccount: 12 3456")

    assert_equal "To: JAN KOWALSKI\nAccount: 12 3456", entry.notes
  end

  test "replaces the notes on a later sync" do
    process(notes: "To: JAN KOWALSKI")
    entry = process(notes: "To: JAN KOWALSKI\nTitle: Rent")

    assert_equal "To: JAN KOWALSKI\nTitle: Rent", entry.notes
  end

  test "leaves the notes alone without notes" do
    process(notes: "To: JAN KOWALSKI")
    entry = process(notes: nil)

    assert_equal "To: JAN KOWALSKI", entry.notes
  end

  test "keeps notes that were locked by an edit" do
    entry = process(notes: "To: JAN KOWALSKI")
    entry.update!(notes: "My own note")
    entry.lock_attr!(:notes)

    entry = process(notes: "To: JAN KOWALSKI")

    assert_equal "My own note", entry.notes
  end

  test "keeps upstream's notes for an unidentified hold" do
    entry = LunchflowEntry::Processor.new(
      {
        id: "",
        accountId: 456,
        amount: -14.97,
        currency: "PLN",
        date: "2026-10-20",
        merchant: "474836xxxxxx6879 003015315475",
        description: "474836xxxxxx6879 003015315475",
        isPending: true,
        notes: "To: JAN KOWALSKI"
      },
      lunchflow_account: @lunchflow_account
    ).process

    assert_equal "474836xxxxxx6879 003015315475", entry.notes
  end

  private
    def process(notes:)
      LunchflowEntry::Processor.new(
        {
          id: "lf_txn_notes",
          accountId: 456,
          amount: -25.00,
          currency: "PLN",
          date: "2026-10-20",
          merchant: "",
          description: "Rent",
          isPending: false,
          notes: notes
        }.compact,
        lunchflow_account: @lunchflow_account
      ).process.reload
    end
end
