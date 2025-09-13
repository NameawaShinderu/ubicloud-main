# frozen_string_literal: true

require_relative "../model"

class HostProvider < Sequel::Model
  many_to_one :vm_host, key: :id

  HETZNER_PROVIDER_NAME = "hetzner"
  LEASEWEB_PROVIDER_NAME = "leaseweb"
  ONPREM_PROVIDER_NAME = "onprem"

  PROVIDER_METHODS = %w[connection_string user password].freeze

  PROVIDER_METHODS.each do |method_name|
    define_method(method_name) do
      # For on-premises, these methods return nil or custom values
      case provider_name
      when ONPREM_PROVIDER_NAME
        case method_name
        when "connection_string"
          "ssh://#{vm_host.sshable.host}"
        when "user"
          "root"
        when "password"
          nil  # Using SSH keys
        end
      else
        Config.send(:"#{provider_name}_#{method_name}")
      end
    end
  end

  def api
    api_class = case provider_name
                when HETZNER_PROVIDER_NAME
                  "Hosting::HetznerApis"
                when ONPREM_PROVIDER_NAME
                  "Hosting::OnpremApis"
                else
                  "Hosting::#{provider_name.capitalize}Apis"
                end
    
    @api ||= Object.const_get(api_class).new(self)
  end

  def supports_api_operations?
    case provider_name
    when ONPREM_PROVIDER_NAME
      false  # Limited API operations for on-premises
    else
      true
    end
  end

  def display_name
    case provider_name
    when ONPREM_PROVIDER_NAME
      "On-Premises (#{server_identifier})"
    when HETZNER_PROVIDER_NAME
      "Hetzner (#{server_identifier})"
    else
      "#{provider_name.capitalize} (#{server_identifier})"
    end
  end
end

# Table: host_provider
# Primary Key: (server_identifier, provider_name)
# Columns:
#  id                | uuid |
#  server_identifier | text |
#  provider_name     | text |
# Indexes:
#  host_provider_pkey | PRIMARY KEY btree (provider_name, server_identifier)
# Foreign key constraints:
#  host_provider_id_fkey | (id) REFERENCES vm_host(id)
