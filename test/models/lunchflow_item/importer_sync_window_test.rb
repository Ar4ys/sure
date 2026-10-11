require "test_helper"

class LunchflowItem::ImporterSyncWindowTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @item = LunchflowItem.create!(
      family: @family,
      name: "Sync window test",
      api_key: "test_key_123",
      status: :good
    )
    @lunchflow_account = @item.lunchflow_accounts.create!(
      account_id: "acct-window",
      name: "Linked checking",
      currency: "EUR"
    )
    @account = @family.accounts.create!(
      name: "Linked checking",
      balance: 10,
      currency: "EUR",
      accountable: Depository.new(subtype: "checking")
    )
    AccountProvider.create!(account: @account, provider: @lunchflow_account)

    @provider = mock("lunchflow_provider")
    @provider.stubs(:get_accounts).returns(
      accounts: [
        {
          id: @lunchflow_account.account_id,
          name: "Linked checking",
          currency: "EUR",
          status: "ACTIVE"
        }
      ]
    )
    @provider.stubs(:get_account_balance).returns(balance: { amount: "10", currency: "EUR" })
    @importer = LunchflowItem::Importer.new(@item, lunchflow_provider: @provider)
  end

  test "first sync of a lunchflow.app account starts a week before the account was added" do
    @provider.expects(:get_account_transactions)
      .with(@lunchflow_account.account_id, has_entries(include_pending: false, start_date: @lunchflow_account.created_at - 7.days))
      .returns(transactions: [])

    @importer.import
  end

  test "first sync with a custom base url fetches the whole history" do
    @item.update!(base_url: "http://bank-scraper:8585/api/lunchflow")

    @provider.expects(:get_account_transactions)
      .with(@lunchflow_account.account_id, has_entries(start_date: Time.at(0).utc))
      .returns(transactions: [])

    @importer.import
  end

  test "later syncs with a custom base url still fetch the whole history" do
    @item.update!(base_url: "http://bank-scraper:8585/api/lunchflow")
    @item.stubs(:last_synced_at).returns(1.hour.ago)
    @lunchflow_account.update!(raw_transactions_payload: [ { id: "tx-1", amount: -5, currency: "EUR", date: Date.current.to_s } ])

    @provider.expects(:get_account_transactions)
      .with(@lunchflow_account.account_id, has_entries(start_date: Time.at(0).utc))
      .returns(transactions: [])

    @importer.import
  end
end
