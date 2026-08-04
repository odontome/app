require 'test_helper'

class BugsnagConfigurationTest < ActiveSupport::TestCase
  test 'discards invalid MIME type errors from bot probes' do
    exception = ActionDispatch::Http::MimeNegotiation::InvalidType.new(
      '"../../../etc/services{{" is not a valid MIME type'
    )
    report = Bugsnag::Report.new(exception, Bugsnag.configuration)

    Bugsnag.configuration.internal_middleware.run(report)

    assert report.ignore?, 'expected Bugsnag to discard MimeNegotiation::InvalidType reports'
  end
end
