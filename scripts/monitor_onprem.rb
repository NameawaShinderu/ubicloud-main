#!/usr/bin/env ruby
# frozen_string_literal: true

# On-premises server monitoring script
REPL = true
require_relative "../loader"

def check_onprem_hosts
  hosts = VmHost.where(id: HostProvider.where(provider_name: "onprem").select(:id))
  
  puts "🏥 On-Premises Server Health Check"
  puts "=" * 50
  
  if hosts.empty?
    puts "No on-premises servers found."
    puts "Run 'ruby demo/cloudify_onprem_server' to add your first server."
    return
  end
  
  hosts.each do |host|
    puts "\n🖥️  Server: #{host.sshable.host} (#{host.ubid})"
    puts "   Location: #{host.location.display_name}"
    puts "   State: #{host.allocation_state}"
    
    begin
      # Check SSH connectivity
      host.sshable.cmd("echo 'ping'", timeout: 10)
      puts "   ✅ SSH: Connected"
      
      # Check SPDK services
      spdk_status = host.sshable.cmd("systemctl is-active spdk-* | sort | uniq -c")
      puts "   🔧 SPDK Services:"
      spdk_status.split("\n").each { |line| puts "      #{line.strip}" }
      
      # Check VM count
      vm_count = host.vms.count
      puts "   💻 VMs: #{vm_count} running"
      
      # Check resource usage
      memory_usage = host.sshable.cmd("free | grep Mem | awk '{printf \"%.1f%%\", $3/$2 * 100.0}'")
      disk_usage = host.sshable.cmd("df -h / | tail -1 | awk '{print $5}'")
      puts "   📊 Memory: #{memory_usage}, Disk: #{disk_usage}"
      
      # Check hugepages
      hugepages = host.sshable.cmd("cat /proc/meminfo | grep 'HugePages_Total\\|HugePages_Free' | awk '{print $1, $2}' | tr '\n' ' '")
      puts "   🧠 Hugepages: #{hugepages.strip}"
      
      # Check IPv6 connectivity
      ipv6_test = host.sshable.cmd("ping6 -c 1 google.com > /dev/null 2>&1 && echo 'OK' || echo 'FAIL'")
      puts "   🌐 IPv6: #{ipv6_test.strip}"
      
    rescue => e
      puts "   ❌ Error: #{e.message}"
    end
  end
  
  puts "\n✅ Health check completed"
end

def show_vm_status
  vms = Vm.where(vm_host_id: VmHost.where(id: HostProvider.where(provider_name: "onprem").select(:id)).select(:id))
  
  puts "\n💻 On-Premises VM Status"
  puts "=" * 30
  
  if vms.empty?
    puts "No VMs found on on-premises servers"
    puts "Create VMs through the UbiCloud dashboard: http://localhost:3000"
    return
  end
  
  vms.each do |vm|
    puts "\n🔹 #{vm.name} (#{vm.ubid})"
    puts "   Host: #{vm.vm_host.sshable.host}"
    puts "   State: #{vm.display_state}"
    puts "   Size: #{vm.display_size}"
    puts "   IPv4: #{vm.ip4 || 'N/A'}"
    puts "   IPv6: #{vm.ip6 || 'N/A'}"
    
    # Check if VM is actually running
    if vm.display_state == "running"
      begin
        vm_status = vm.vm_host.sshable.cmd("systemctl is-active #{vm.inhost_name}")
        puts "   🔄 Service: #{vm_status.strip}"
      rescue
        puts "   🔄 Service: unknown"
      end
    end
  end
end

def show_summary
  hosts = VmHost.where(id: HostProvider.where(provider_name: "onprem").select(:id))
  vms = Vm.where(vm_host_id: hosts.select(:id))
  
  puts "\n📊 On-Premises Infrastructure Summary"
  puts "=" * 40
  puts "Servers: #{hosts.count}"
  puts "VMs: #{vms.count}"
  puts "Running VMs: #{vms.where(display_state: 'running').count}"
  
  if hosts.any?
    total_memory = hosts.sum(:total_mem_gib)
    total_cpus = hosts.sum(:total_cpus)
    puts "Total Memory: #{total_memory} GB"
    puts "Total CPUs: #{total_cpus}"
    
    # Calculate usage
    used_memory = vms.sum(:memory_gib)
    used_cpus = vms.sum(:vcpus)
    
    puts "Used Memory: #{used_memory} GB (#{((used_memory.to_f / total_memory) * 100).round(1)}%)"
    puts "Used CPUs: #{used_cpus} (#{((used_cpus.to_f / total_cpus) * 100).round(1)}%)"
  end
end

def list_locations
  locations = Location.where(provider: "onprem")
  
  puts "\n📍 On-Premises Locations"
  puts "=" * 30
  
  if locations.empty?
    puts "No on-premises locations configured."
    puts "Run 'ruby demo/cloudify_onprem_server' to add your first server."
    return
  end
  
  locations.each do |location|
    host_count = VmHost.where(location_id: location.id).count
    puts "🏢 #{location.display_name} (#{location.name})"
    puts "   Provider: #{location.provider}"
    puts "   Servers: #{host_count}"
    puts "   Visible: #{location.visible}"
  end
end

# Main execution
case ARGV[0]
when "health"
  check_onprem_hosts
when "vms"
  show_vm_status
when "summary"
  show_summary
when "locations"
  list_locations
when "all", nil
  show_summary
  list_locations
  check_onprem_hosts
  show_vm_status
else
  puts "UbiCloud On-Premises Monitoring Tool"
  puts "====================================="
  puts ""
  puts "Usage: ruby scripts/monitor_onprem.rb [command]"
  puts ""
  puts "Commands:"
  puts "  health     - Check health of on-premises servers"
  puts "  vms        - Show status of VMs on on-premises servers"
  puts "  summary    - Show infrastructure summary"
  puts "  locations  - List on-premises locations"
  puts "  all        - Run all checks (default)"
  puts ""
  puts "Examples:"
  puts "  ruby scripts/monitor_onprem.rb health"
  puts "  ruby scripts/monitor_onprem.rb vms"
  puts "  ruby scripts/monitor_onprem.rb"
end
