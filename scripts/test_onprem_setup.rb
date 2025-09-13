#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for on-premises UbiCloud setup
REPL = true
require_relative "../loader"

def test_provider_creation
  puts "🧪 Testing on-premises provider creation..."
  
  # Test HostProvider constant
  unless HostProvider.const_defined?(:ONPREM_PROVIDER_NAME)
    puts "❌ ONPREM_PROVIDER_NAME constant not defined"
    return false
  end
  
  puts "✅ ONPREM_PROVIDER_NAME constant defined: #{HostProvider::ONPREM_PROVIDER_NAME}"
  true
end

def test_location_creation
  puts "🧪 Testing location creation..."
  
  begin
    location = Location.find_or_create(provider: "onprem", name: "test-onprem") do |loc|
      loc.display_name = "Test On-Premises"
      loc.visible = true
    end
    
    if location
      puts "✅ Location created successfully: ID #{location.id}"
      location.destroy  # Clean up test location
      true
    else
      puts "❌ Failed to create location"
      false
    end
  rescue => e
    puts "❌ Error creating location: #{e.message}"
    false
  end
end

def test_api_classes
  puts "🧪 Testing API class loading..."
  
  begin
    require_relative "../lib/hosting/onprem_apis"
    puts "✅ OnpremApis class loaded successfully"
    
    # Test class instantiation with mock provider
    require 'ostruct'
    dummy_sshable = OpenStruct.new(host: "test.local")
    dummy_vm_host = OpenStruct.new(sshable: dummy_sshable)
    dummy_provider = OpenStruct.new(vm_host: dummy_vm_host, server_identifier: "test-01")
    
    api = Hosting::OnpremApis.new(dummy_provider)
    puts "✅ OnpremApis instance created successfully"
    
    # Test basic API methods
    ips = api.pull_ips
    puts "✅ pull_ips method works: #{ips.length} IP(s) returned"
    
    dc = api.pull_dc("test-server")
    puts "✅ pull_dc method works: #{dc}"
    
    true
  rescue => e
    puts "❌ Error loading OnpremApis: #{e.message}"
    false
  end
end

def test_configuration
  puts "🧪 Testing configuration..."
  
  config_tests = [
    :onprem_default_ipv6_prefix,
    :onprem_data_center_name,
    :onprem_health_check_interval
  ]
  
  config_tests.each do |config_key|
    begin
      value = Config.send(config_key)
      puts "✅ Config #{config_key}: #{value}"
    rescue => e
      puts "❌ Config #{config_key} failed: #{e.message}"
      return false
    end
  end
  
  true
end

def test_host_provider_methods
  puts "🧪 Testing HostProvider methods..."
  
  begin
    # Test that the constant exists
    onprem_const = HostProvider::ONPREM_PROVIDER_NAME
    puts "✅ ONPREM_PROVIDER_NAME constant: #{onprem_const}"
    
    # Test provider method handling (without creating actual records)
    provider_class = HostProvider
    puts "✅ HostProvider class accessible"
    
    # Test that the api method can handle OnpremApis
    if provider_class.instance_methods.include?(:api)
      puts "✅ HostProvider#api method exists"
    else
      puts "❌ HostProvider#api method missing"
      return false
    end
    
    true
  rescue => e
    puts "❌ Error testing HostProvider: #{e.message}"
    false
  end
end

def test_hosting_apis_integration
  puts "🧪 Testing Hosting::Apis integration..."
  
  begin
    # Test that Hosting::Apis can handle method calls
    apis_class = Hosting::Apis
    
    # Check if methods exist
    required_methods = [:pull_ips, :reimage_server, :hardware_reset_server, :pull_data_center, :set_server_name]
    
    required_methods.each do |method|
      if apis_class.methods.include?(method)
        puts "✅ Hosting::Apis.#{method} method exists"
      else
        puts "❌ Hosting::Apis.#{method} method missing"
        return false
      end
    end
    
    # Check if new on-premises methods exist
    onprem_methods = [:check_provider_connectivity, :get_system_info]
    
    onprem_methods.each do |method|
      if apis_class.methods.include?(method)
        puts "✅ Hosting::Apis.#{method} method exists"
      else
        puts "❌ Hosting::Apis.#{method} method missing"
        return false
      end
    end
    
    true
  rescue => e
    puts "❌ Error testing Hosting::Apis: #{e.message}"
    false
  end
end

def test_file_existence
  puts "🧪 Testing file existence..."
  
  required_files = [
    "lib/hosting/onprem_apis.rb",
    "demo/cloudify_onprem_server",
    "demo/docker-compose.dev.yml",
    "demo/add_onprem_config",
    "scripts/monitor_onprem.rb",
    "scripts/migrate_onprem_location.rb"
  ]
  
  all_exist = true
  
  required_files.each do |file|
    if File.exist?(file)
      puts "✅ File exists: #{file}"
    else
      puts "❌ File missing: #{file}"
      all_exist = false
    end
  end
  
  all_exist
end

def run_comprehensive_test
  puts "🧪 Running comprehensive on-premises integration test..."
  
  begin
    # This test creates temporary records to test the full integration
    puts "Creating test location..."
    location = Location.create(
      provider: "onprem",
      name: "integration-test",
      display_name: "Integration Test Location",
      visible: false
    )
    
    puts "Creating test host provider record..."
    id = VmHost.generate_uuid
    Sshable.create_with_id(id, host: "192.168.1.100")
    
    vm_host = VmHost.create_with_id(id,
      location_id: location.id,
      family: "standard",
      net6: "fd00:test::/64",
      ndp_needed: false
    )
    
    host_provider = HostProvider.create(
      id: id,
      provider_name: HostProvider::ONPREM_PROVIDER_NAME,
      server_identifier: "integration-test-01"
    )
    
    puts "Testing provider API integration..."
    api = host_provider.api
    puts "✅ API instance created: #{api.class.name}"
    
    ips = api.pull_ips
    puts "✅ pull_ips works: #{ips.first.ip_address}"
    
    dc = api.pull_dc("test")
    puts "✅ pull_dc works: #{dc}"
    
    puts "Testing Hosting::Apis integration..."
    test_ips = Hosting::Apis.pull_ips(vm_host)
    puts "✅ Hosting::Apis.pull_ips works"
    
    connectivity = Hosting::Apis.check_provider_connectivity(vm_host)
    puts "✅ Hosting::Apis.check_provider_connectivity works: #{connectivity}"
    
    # Clean up test records
    puts "Cleaning up test records..."
    host_provider.destroy
    vm_host.destroy
    Sshable[id].destroy
    location.destroy
    
    puts "✅ Comprehensive integration test passed!"
    true
    
  rescue => e
    puts "❌ Integration test failed: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    
    # Attempt cleanup
    begin
      HostProvider.where(server_identifier: "integration-test-01").destroy
      VmHost.where(family: "standard").where(net6: "fd00:test::/64").destroy
      Sshable.where(host: "192.168.1.100").destroy
      Location.where(name: "integration-test").destroy
    rescue
      # Ignore cleanup errors
    end
    
    false
  end
end

# Run tests
puts "🚀 Running On-Premises UbiCloud Tests"
puts "=" * 50

tests = [
  ["File Existence", method(:test_file_existence)],
  ["Provider Creation", method(:test_provider_creation)],
  ["Location Creation", method(:test_location_creation)],
  ["API Classes", method(:test_api_classes)],
  ["Configuration", method(:test_configuration)],
  ["HostProvider Methods", method(:test_host_provider_methods)],
  ["Hosting::Apis Integration", method(:test_hosting_apis_integration)],
  ["Comprehensive Integration", method(:run_comprehensive_test)]
]

passed = 0
total = tests.length

tests.each do |test_name, test_method|
  puts "\n🔬 Running: #{test_name}"
  puts "-" * 20
  
  if test_method.call
    passed += 1
    puts "✅ #{test_name}: PASSED"
  else
    puts "❌ #{test_name}: FAILED"
  end
end

puts "\n" + "=" * 50
puts "📊 Test Results: #{passed}/#{total} tests passed"

if passed == total
  puts "🎉 ALL TESTS PASSED! Your on-premises setup is ready."
  puts ""
  puts "🚀 Next Steps:"
  puts "1. Run: ./demo/add_onprem_config  (to configure environment)"
  puts "2. Start: docker-compose -f demo/docker-compose.dev.yml up -d"
  puts "3. Migrate: ruby scripts/migrate_onprem_location.rb add"
  puts "4. Cloudify: ruby demo/cloudify_onprem_server"
else
  puts "❌ Some tests failed. Please review the errors above."
  puts ""
  puts "Common issues:"
  puts "• Missing files - ensure all code changes were applied"
  puts "• Syntax errors - check Ruby syntax in modified files"
  puts "• Missing constants - verify HostProvider modifications"
  exit 1
end
