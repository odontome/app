# frozen_string_literal: true

# Cloudflare R2 rejects uploads when the AWS SDK sends both Content-MD5 and
# one of the newer "flexible checksum" headers (CRC32, SHA256, etc).
# Rails 8/Active Storage plus aws-sdk-s3 >= 1.199 enable those checksums by
# default, so force the SDK to only calculate them when an API operation
# explicitly requires it. This keeps uploads compatible with R2.
Aws.config.update(request_checksum_calculation: 'when_required') if defined?(Aws)
