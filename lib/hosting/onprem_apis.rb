# frozen_string_literal: true

require "ostruct"

class Hosting::OnpremApis
  def initialize(host_provider)
    @host_provider = host_provider
  end

  def pull_ips
    # For on-premises, we return the SSH host as the main IP
    host_ip = @host_provider.vm_host.sshable.host
    
    [
      OpenStruct.new(
        ip_address: host_ip,
        source_host_ip: host_ip,
        is_failover: false
      )
    ]
  end

  def reimage(server_identifier)
    # On-premises servers can't be reimaged via API
    # This would require manual intervention or IPMI integration
    raise "Reimage operation not supported for on-premises servers. " \
          "Please reimage manually or implement IPMI integration."
  end

  def reset(server_identifier)
    # Hardware reset not supported via API for on-premises
    # Could be implemented with IPMI/BMC integration in the future
    raise "Hardware reset not supported via API for on-premises servers. " \
          "Please reset manually via IPMI/BMC or physical power cycle."
  end

  def pull_dc(server_identifier)
    # Return configured data center name or default
    Config.onprem_data_center_name || "onprem-dc-#{server_identifier}"
  end

  def set_server_name(server_identifier, name)
    # On-premises servers manage their own hostnames
    # Could implement hostname setting via SSH if needed
    Clog.emit("Server name setting requested for on-premises server") do
      {
        server_identifier: server_identifier,
        requested_name: name,
        message: "On-premises servers manage hostnames independently"
      }
    end
  end

  # Additional method for on-premises specific operations
  def check_connectivity
    begin
      # Test SSH connectivity to the host
      @host_provider.vm_host.sshable.cmd("echo 'connectivity_check_ok'", timeout: 10)
      true
    rescue => e
      Clog.emit("On-premises connectivity check failed") do
        {
          server_identifier: @host_provider.server_identifier,
          error: e.message
        }
      end
      false
    end
  end

  def get_system_info
    # Gather system information for monitoring/debugging
    ssh = @host_provider.vm_host.sshable
    
    {
      hostname: ssh.cmd("hostname").strip,
      uptime: ssh.cmd("uptime").strip,
      kernel_version: ssh.cmd("uname -r").strip,
      cpu_info: ssh.cmd("lscpu | grep 'Model name' | cut -d: -f2 | xargs").strip,
      memory_info: ssh.cmd("free -h | grep Mem").strip,
      disk_usage: ssh.cmd("df -h | grep -E '^/dev'").strip
    }
  rescue => e
    Clog.emit("Failed to gather system info for on-premises server") { {error: e.message} }
    {}
  end
end
