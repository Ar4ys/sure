require "test_helper"

class LunchflowEntry::ProcessorDomainTest < ActiveSupport::TestCase
  setup do
    Setting.stubs(:brand_fetch_client_id).returns("test-client")

    @family = families(:empty)
    @lunchflow_item = LunchflowItem.create!(name: "Domain test", api_key: "test_key", family: @family)
    @lunchflow_account = LunchflowAccount.create!(
      lunchflow_item: @lunchflow_item,
      name: "Test Account",
      currency: "PLN",
      account_id: "lf_acc_domain"
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

  test "gives a new merchant the website and logo of merchantDomain" do
    merchant = process(merchantDomain: "bakery.example").entryable.merchant

    assert_equal "https://bakery.example", merchant.website_url
    assert_includes merchant.logo_url, "cdn.brandfetch.io/bakery.example/"
  end

  test "replaces a website the merchant had, and the logo generated from it" do
    process(merchantDomain: "old-bakery.example")
    merchant = process(merchantDomain: "bakery.example").entryable.merchant

    assert_equal "https://bakery.example", merchant.website_url
    assert_includes merchant.logo_url, "cdn.brandfetch.io/bakery.example/"
  end

  test "keeps a logo the provider supplied" do
    merchant = process(merchantDomain: nil).entryable.merchant
    merchant.update!(logo_url: "https://logos.example/bakery.png")

    merchant = process(merchantDomain: "bakery.example").entryable.merchant

    assert_equal "https://bakery.example", merchant.website_url
    assert_equal "https://logos.example/bakery.png", merchant.logo_url
  end

  test "leaves the website alone without merchantDomain" do
    process(merchantDomain: "bakery.example")
    merchant = process(merchantDomain: nil).entryable.merchant

    assert_equal "https://bakery.example", merchant.website_url
  end

  private
    def process(merchantDomain:)
      LunchflowEntry::Processor.new(
        {
          id: "lf_txn_domain",
          accountId: 456,
          amount: -25.00,
          currency: "PLN",
          date: "2026-10-20",
          merchant: "Bakery",
          description: "Bread",
          isPending: false,
          merchantDomain: merchantDomain
        }.compact,
        lunchflow_account: @lunchflow_account
      ).process.reload
    end
end
