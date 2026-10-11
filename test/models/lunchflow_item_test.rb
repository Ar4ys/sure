require "test_helper"

class LunchflowItemTest < ActiveSupport::TestCase
  def setup
    @lunchflow_item = lunchflow_items(:one)
  end

  test "effective_base_url returns default when base_url blank" do
    @lunchflow_item.base_url = nil

    assert_equal LunchflowItem::DEFAULT_BASE_URL, @lunchflow_item.effective_base_url
  end

  test "effective_base_url returns a custom https url" do
    @lunchflow_item.base_url = "https://lunchflow.example.com/api/v1"

    assert_equal "https://lunchflow.example.com/api/v1", @lunchflow_item.effective_base_url
  end

  test "effective_base_url returns a custom http url with a port" do
    @lunchflow_item.base_url = "http://bank-scraper:8585/api/lunchflow"

    assert_equal "http://bank-scraper:8585/api/lunchflow", @lunchflow_item.effective_base_url
  end

  test "effective_base_url strips surrounding whitespace and the trailing slash" do
    @lunchflow_item.base_url = " https://lunchflow.app/api/v1/ "

    assert_equal "https://lunchflow.app/api/v1", @lunchflow_item.effective_base_url
  end

  test "effective_base_url returns default for non-http scheme" do
    @lunchflow_item.base_url = "ftp://lunchflow.app/api/v1"

    assert_equal LunchflowItem::DEFAULT_BASE_URL, @lunchflow_item.effective_base_url
  end

  test "effective_base_url returns default for a url without a host" do
    @lunchflow_item.base_url = "lunchflow.app/api/v1"

    assert_equal LunchflowItem::DEFAULT_BASE_URL, @lunchflow_item.effective_base_url
  end

  test "effective_base_url returns default for an unparsable url" do
    @lunchflow_item.base_url = "http://bank scraper:8585"

    assert_equal LunchflowItem::DEFAULT_BASE_URL, @lunchflow_item.effective_base_url
  end

  test "custom_base_url? is true only for a url other than the default" do
    @lunchflow_item.base_url = "http://bank-scraper:8585/api/lunchflow"
    assert @lunchflow_item.custom_base_url?

    @lunchflow_item.base_url = "https://lunchflow.app/api/v1/"
    assert_not @lunchflow_item.custom_base_url?

    @lunchflow_item.base_url = nil
    assert_not @lunchflow_item.custom_base_url?
  end

  test "sync status summary covers every German count branch" do
    assert_sync_status(:de, total: 0, linked: 0, unlinked: 0, expected: "Keine Konten gefunden")
    assert_sync_status(:de, total: 1, linked: 1, unlinked: 0, expected: "1 Konto synchronisiert")
    assert_sync_status(:de, total: 2, linked: 2, unlinked: 0, expected: "2 Konten synchronisiert")
    assert_sync_status(:de, total: 2, linked: 1, unlinked: 1, expected: "1 synchronisiert, 1 muss eingerichtet werden")
    assert_sync_status(:de, total: 3, linked: 1, unlinked: 2, expected: "1 synchronisiert, 2 müssen eingerichtet werden")
  end

  test "sync status summary covers every English count branch" do
    assert_sync_status(:en, total: 0, linked: 0, unlinked: 0, expected: "No accounts found")
    assert_sync_status(:en, total: 1, linked: 1, unlinked: 0, expected: "1 account synced")
    assert_sync_status(:en, total: 2, linked: 2, unlinked: 0, expected: "2 accounts synced")
    assert_sync_status(:en, total: 2, linked: 1, unlinked: 1, expected: "1 synced, 1 needs setup")
    assert_sync_status(:en, total: 3, linked: 1, unlinked: 2, expected: "1 synced, 2 need setup")
  end

  private
    def assert_sync_status(locale, total:, linked:, unlinked:, expected:)
      @lunchflow_item.stubs(:total_accounts_count).returns(total)
      @lunchflow_item.stubs(:linked_accounts_count).returns(linked)
      @lunchflow_item.stubs(:unlinked_accounts_count).returns(unlinked)

      I18n.with_locale(locale) do
        assert_equal expected, @lunchflow_item.sync_status_summary
      end
    end
end
