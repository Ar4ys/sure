require "test_helper"

class Transactions::LinkedEntryDateTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @entry = entries(:transaction)
    @entry.update!(external_id: "lunchflow_salary-1", source: "lunchflow")
  end

  test "the date of a synced transaction can be edited, its amount cannot" do
    get transaction_url(@entry)

    assert_response :success
    assert_select "input[name='entry[date]']:not([disabled])"
    assert_select "input[name='entry[amount]'][disabled]"
  end

  test "an edited date survives the next sync of the transaction" do
    bank_date = @entry.date
    edited_date = bank_date - 3.days

    patch transaction_url(@entry), params: { entry: { date: edited_date } }

    assert_equal edited_date, @entry.reload.date
    assert @entry.user_modified?

    Account::ProviderImportAdapter.new(@entry.account).import_transaction(
      external_id: @entry.external_id,
      source: @entry.source,
      amount: @entry.amount,
      currency: @entry.currency,
      date: bank_date,
      name: @entry.name
    )

    assert_equal edited_date, @entry.reload.date
  end
end
