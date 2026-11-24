# frozen_string_literal: true

require "base64"

require "active_record"
# The binary attribute types subclass an OID type, and the adapter that defines it
# is otherwise not loaded until the first database connection is made.
require "active_record/connection_adapters/postgresql_adapter"

require_relative "../database"
require_relative "../../database/sha256_attribute"
require_relative "../../database/sha_attribute"
require_relative "../../database/type/json_pg_safe"
require_relative "../../database/type/jsonb_boolean"
require_relative "../../database/type/jsonb_float"
require_relative "../../database/type/jsonb_integer"
require_relative "../../database/type/tag_list_type"
require_relative "../../database/x509_serial_number_attribute"
