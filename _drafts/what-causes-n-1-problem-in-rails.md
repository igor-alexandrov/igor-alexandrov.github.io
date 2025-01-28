Intro will be here

<!--more-->

1. Associations

2. Scopes

3.

В объекте resource_tour_request происходит работа с ledger_records. ledger_records загружается, но не внутри resource_tour_request.

    authorize resource_tour_request, :show?

    load_exchange_rates

    ledger_records = resource_tour_request
      .ledger_records
      .preload({ target: :account }, :payment)

    render turbo_stream: [
      turbo_stream.after(
        dom_id(resource_tour_request),
        partial: "acc/tour_requests/ledger_records/list", locals: {
          tour_request: resource_tour_request,
          ledger_records: ledger_records
        }
      )
    ]


Решение:
    ActiveRecord::Associations::Preloader.new(
      records: [resource_tour_request],
      associations: [ledger_records: [{ target: :account }, :payment]]
    ).call

https://bhserna.com/fix-n+1-queries-on-rails
